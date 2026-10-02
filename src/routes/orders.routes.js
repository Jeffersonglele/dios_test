const express = require('express');

const { orders } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.get('/:id/details', authenticate, validate(validators.id), orders.order.getDetails);
router.patch('/:id/status', authenticate, validate(validators.id), orders.order.updateStatus);

// Custom list route with includeLines support
router.get('/', authenticate, validate(validators.pagination), orders.listOrders);

// Individual order routes (getById, update, remove)
router.get('/:id', authenticate, validate(validators.id), orders.order.getById);
router.patch('/:id', authenticate, validate(validators.id), orders.order.update);
router.delete('/:id', authenticate, validate(validators.id), orders.order.remove);

// Create order
router.post('/', authenticate, validate(validators.createOrder), orders.order.create);

const orderLinesRouter = createResourceRouter(orders.orderLine, { readMiddlewares: [authenticate] });

module.exports = { orderLinesRouter, router };
