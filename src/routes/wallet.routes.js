const express = require('express');

const wallet = require('../controllers/wallet.controller');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');

const router = express.Router();

router.get('/wallet/me', authenticate, wallet.walletSummary);
router.get('/wallet/me/ledger', authenticate, validate(validators.pagination), wallet.walletLedger);
router.post('/wallet/top-ups', authenticate, wallet.requestTopUp);
router.get('/mobile-money-accounts', authenticate, wallet.listMobileMoneyAccounts);
router.post('/mobile-money-accounts', authenticate, wallet.createMobileMoneyAccount);
router.patch('/mobile-money-accounts/:id/default', authenticate, validate(validators.id), wallet.setDefaultMobileMoneyAccount);
router.delete('/mobile-money-accounts/:id', authenticate, validate(validators.id), wallet.removeMobileMoneyAccount);

module.exports = router;
