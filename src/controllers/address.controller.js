const { createCrudController } = require('./crud.controller');

const fields = [
  'addressId', 'objectType', 'objectId', 'streetNumber', 'city', 'state',
  'country', 'fullAddress', 'latitude', 'longitude',
];

module.exports = createCrudController({
  delegate: 'address', resource: 'Adresse', fields, filterFields: ['objectType', 'country', 'city'],
});
