const express = require('express');

const { promotions } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const adminOnly = [authenticate, authorize('ADMIN')];

// POST /promo-codes/validate est servi par payments.routes (monté avant).
router.post('/promo-codes/referral/create', authenticate, promotions.promoCode.createReferral);
router.post('/promo-codes/referral/apply', authenticate, promotions.promoCode.applyReferral);

// CRUD routes for promo codes (Admin only)
router.use('/promo-codes', createResourceRouter(promotions.promoCode, {
  readMiddlewares: adminOnly,
  writeMiddlewares: adminOnly,
  removeMiddlewares: adminOnly,
}));

module.exports = router;
