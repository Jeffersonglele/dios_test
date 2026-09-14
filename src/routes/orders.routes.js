const express = require('express');

const { orders } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.get('/:id/details', authenticate, validate(validators.id), orders.order.getDetails);
router.patch('/:id/status', authenticate, validate(validators.id), orders.order.updateStatus);
router.use('/', createResourceRouter(orders.order, {
  readMiddlewares: [authenticate],
  createValidator: validate(validators.createOrder),
}));

const orderLinesRouter = createResourceRouter(orders.orderLine, { readMiddlewares: [authenticate] });

module.exports = { orderLinesRouter, router };
