const express = require('express');

const { payments } = require('../controllers');
const cinetpay = require('../controllers/cinetpay.controller');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

// This endpoint is intentionally public: CinetPay calls it asynchronously.
// Its HMAC and the transaction status are verified in the controller.
router.post('/payments/cinetpay/webhook', cinetpay.webhook);
router.get('/payments/cinetpay/return', cinetpay.paymentReturn);
router.post('/payments/cinetpay/initialize', authenticate, cinetpay.initialize);
router.post('/payments/cinetpay/tips/initialize', authenticate, cinetpay.initializeTip);
router.get('/payments/cinetpay/:transactionId', authenticate, cinetpay.getPayment);
router.post('/payments/cinetpay/mock/:transactionId/confirm', authenticate, cinetpay.mockConfirm);
router.post('/orders/:id/cash-collection', authenticate, authorize('LIVREUR'), validate(validators.id), payments.confirmCashCollection);

router.post('/promo-codes/validate', payments.promoCode.validate);
router.patch('/transactions/:id/status', authenticate, validate(validators.id), payments.transaction.updateStatus);
router.use('/payment-methods', createResourceRouter(payments.paymentMethod, { readMiddlewares: [authenticate] }));
router.use('/transactions', createResourceRouter(payments.transaction, { readMiddlewares: [authenticate] }));
router.use('/promo-codes', createResourceRouter(payments.promoCode));

module.exports = router;
