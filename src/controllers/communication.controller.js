const { createCrudController } = require('./crud.controller');

const message = createCrudController({
  delegate: 'message', resource: 'Message',
  fields: ['fromUserId', 'toUserId', 'text', 'orderId', 'read'],
  filterFields: ['fromUserId', 'toUserId', 'orderId', 'read'],
});

const comment = createCrudController({
  delegate: 'comment', resource: 'Commentaire',
  fields: ['commentId', 'userId', 'target', 'targetId', 'description'],
  filterFields: ['userId', 'target', 'targetId'],
});

const report = createCrudController({
  delegate: 'report', resource: 'Signalement',
  fields: ['reporterUserId', 'targetType', 'targetId', 'reason', 'details', 'status'],
  filterFields: ['targetType', 'status'],
});

module.exports = { comment, message, report };
