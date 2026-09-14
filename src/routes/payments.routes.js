const express = require('express');

const { payments } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.post('/promo-codes/validate', payments.promoCode.validate);
router.patch('/transactions/:id/status', authenticate, validate(validators.id), payments.transaction.updateStatus);
router.use('/payment-methods', createResourceRouter(payments.paymentMethod, { readMiddlewares: [authenticate] }));
router.use('/transactions', createResourceRouter(payments.transaction, { readMiddlewares: [authenticate] }));
router.use('/promo-codes', createResourceRouter(payments.promoCode));

module.exports = router;
