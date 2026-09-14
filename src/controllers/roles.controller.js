const { createCrudController } = require('./crud.controller');

const fields = ['roleId', 'name', 'nbUsers', 'nbWaiting'];

module.exports = createCrudController({
  delegate: 'role', resource: 'Rôle', fields, filterFields: ['name'],
});
