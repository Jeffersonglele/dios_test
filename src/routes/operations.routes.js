const express = require('express');

const { operations, roles } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const adminOnly = [authenticate, authorize('ADMIN')];
const options = { readMiddlewares: adminOnly, writeMiddlewares: adminOnly, removeMiddlewares: adminOnly };

router.use('/roles', createResourceRouter(roles, options));
router.use('/invoices', createResourceRouter(operations.invoice, options));
router.use('/restaurant-payouts', createResourceRouter(operations.restaurantPayout, options));
router.use('/deliverer-payouts', createResourceRouter(operations.delivererPayout, options));
router.use('/subscriptions', createResourceRouter(operations.subscription, options));
router.use('/audit-logs', createResourceRouter(operations.auditLog, options));
router.use('/user-logins', createResourceRouter(operations.userLogin, options));

module.exports = router;
