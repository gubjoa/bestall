class User
  attr_accessor :id, :username, :first_name, :last_name, :denied, :fines_amount, :reserves, :loans
  attr_reader :banned, :card_lost, :fines, :debarred, :no_address, :user_category

  include ActiveModel::Model
  include ActiveModel::Serialization
  include ActiveModel::Validations

  def as_json options = {}
    result = super(except: ['xml', 'banned', 'fines', 'debarred', 'no_address', 'card_lost'])
    if @denied
      result[:denied_reasons] = {banned: @banned, fines: @fines, debarred: @debarred, no_address: @no_address, card_lost: @card_lost}
    else
      result[:denied_reasons] = nil
    end
    return result
  end

  def initialize username, xml=nil
    @username = username
    @xml = xml
    parse_xml if @xml
  end

  def self.find id
    # not implemented
    return nil
  end

  def self.find_by_username username
    base_url = APP_CONFIG['koha']['base_url']
    user =  APP_CONFIG['koha']['user']
    password =  APP_CONFIG['koha']['password']

    url = "#{base_url}/members/get?borrower=#{username}&userid=#{user}&password=#{password}"
    response = RestClient.get url
    item = self.new username, response.body
    return item
  rescue => error
    return nil
  end

  def has_borrowed_item? biblio_id
    return !@loans.select{|loan| loan[:biblionumber].eql? biblio_id}.empty?
  end

  def has_reserved_item? biblio_id
    return !@reserves.select{|reserve| reserve[:biblionumber].eql? biblio_id}.empty?
  end

  def parse_xml
    xml = Nokogiri::XML(@xml).remove_namespaces!

    if xml.search('//response/borrower/categorycode').text.present?
      @user_category = xml.search('//response/borrower/categorycode').text
    end
    if xml.search('//response/borrower/borrowernumber').text.present?
      @id = xml.search('//response/borrower/borrowernumber').text.to_i
    end
    if xml.search('//response/borrower/surname').text.present?
      @last_name = xml.search('//response/borrower/surname').text
    end
    if xml.search('//response/borrower/firstname').text.present?
      @first_name = xml.search('//response/borrower/firstname').text
    end

    @denied = false # spärrad

    @fines_amount = nil # bötesbelopp

    @banned = false # avstängd (AV)
    @fines = false # böter mer än 69 kr
    @debarred = false # utgånget lånekort
    @no_address = false # saknar adress
    @card_lost = false # förlorat lånekort

    if xml.search('//response/borrower/categorycode').text.present? && xml.search('//response/borrower/categorycode').text == 'AV'
      @banned = true
      @denied = true
    end

    xml.xpath('//response/flags').each do |flag|
      if flag.xpath('name').text == 'CHARGES'
        if flag.xpath('amount').text.to_i > 69
          @fines = true
          @denied = true
        end
        @fines_amount = flag.xpath('amount').text
      end
      if flag.xpath('name').text == 'DBARRED'
        @debarred = true
        @denied = true
      end
      if flag.xpath('name').text == 'GNA'
        @no_address = true
        @denied = true
      end
      if flag.xpath('name').text == 'LOST'
        @card_lost = true
        @denied = true
      end
    end

    @loans = []
    xml.xpath('//response/issues').each do |issue|
      if issue.xpath('returndate').text.blank?
        biblionumber = issue.xpath('biblionumber').text
        itemnumber = issue.xpath('itemnumber').text
        @loans << {biblionumber: biblionumber, itemnumber: itemnumber}
      end
    end

    @reserves = []
    xml.xpath('//response/reserves/anon').each do |reserve|
        biblionumber = reserve.xpath('biblionumber').text
        itemnumber = reserve.xpath('itemnumber').text
        @reserves << {biblionumber: biblionumber, itemnumber: itemnumber}
    end

  end

end
