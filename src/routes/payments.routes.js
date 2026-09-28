const express = require('express');

const { payments } = require('../controllers');
const nyole = require('../controllers/nyole.controller');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

// This endpoint is intentionally public: Nyole calls it asynchronously.
// Its HMAC and the transaction status are verified in the controller.
router.post('/payments/nyole/webhook', nyole.webhook);
router.get('/payments/nyole/return', nyole.paymentReturn);
router.post('/payments/nyole/initialize', authenticate, nyole.initialize);
router.post('/payments/nyole/tips/initialize', authenticate, nyole.initializeTip);
router.get('/payments/nyole/:transactionId', authenticate, nyole.getPayment);
router.post('/payments/nyole/test/:transactionId/confirm', authenticate, nyole.sandboxConfirm);
router.post('/orders/:id/cash-collection', authenticate, authorize('LIVREUR'), validate(validators.id), payments.confirmCashCollection);

router.post('/promo-codes/validate', payments.promoCode.validate);
router.patch('/transactions/:id/status', authenticate, validate(validators.id), payments.transaction.updateStatus);
router.use('/payment-methods', createResourceRouter(payments.paymentMethod, { readMiddlewares: [authenticate] }));
router.use('/transactions', createResourceRouter(payments.transaction, { readMiddlewares: [authenticate] }));
router.use('/promo-codes', createResourceRouter(payments.promoCode));

module.exports = router;
