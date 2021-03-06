import Ember from 'ember';
import DS from 'ember-data';

export default DS.Model.extend({
  i18n: Ember.inject.service(),

  location: DS.belongsTo('location'),
  nameSv: DS.attr('string'),
  nameEn: DS.attr('string'),
  isOpenLoc: DS.attr('boolean'),
  isOpenPickupLoc: DS.attr('boolean'),
  isPagingLoc: DS.attr('boolean'),

  name: Ember.computed('i18n.locale', function() {
    switch (this.get('i18n.locale')) {
      case 'en':
        return this.get("nameEn");
      default:
        return this.get("nameSv");
    }
  })

});