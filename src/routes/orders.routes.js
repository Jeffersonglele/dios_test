const express = require('express');

const { orders } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.get('/:id/details', authenticate, validate(validators.id), orders.order.getDetails);
router.patch('/:id/status', authenticate, validate(validators.id), orders.order.updateStatus);
router.post('/:id/verify-retrieval', authenticate, validate(validators.verifyRetrieval), orders.order.verifyRetrieval);
router.post('/:orderId/disputes', authenticate, orders.order.submitDispute);
router.post('/:orderId/pay-wallet', authenticate, orders.order.payOrderWithWallet);

// Custom list route with includeLines support
router.get('/', authenticate, validate(validators.pagination), orders.order.list);

// Create order
router.post('/', authenticate, validate(validators.createOrder), orders.order.create);

// Use resource router for getById, update, remove (excluding list and create)
const { createCrudController } = require('../controllers/crud.controller');
const { ORDER_FIELDS } = require('../controllers/orders.controller');
const orderCrudForRoutes = createCrudController({
  delegate: 'order',
  resource: 'Commande',
  fields: ORDER_FIELDS,
  filterFields: ['status', 'country', 'deliveryMode', 'paymentProvider'],
});

router.get('/:id', authenticate, validate(validators.id), orderCrudForRoutes.getById);
router.patch('/:id', authenticate, validate(validators.id), orderCrudForRoutes.update);
router.delete('/:id', authenticate, validate(validators.id), orderCrudForRoutes.remove);

const orderLinesRouter = createResourceRouter(orders.orderLine, { readMiddlewares: [authenticate] });

module.exports = { orderLinesRouter, router };
