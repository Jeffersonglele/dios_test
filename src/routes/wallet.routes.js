const express = require('express');

const wallet = require('../controllers/wallet.controller');
const nyole = require('../controllers/nyole.controller');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');

const router = express.Router();

router.get('/wallet', authenticate, wallet.walletSummary);
router.get('/wallet/me', authenticate, wallet.walletSummary);
router.get('/wallet/me/ledger', authenticate, validate(validators.pagination), wallet.walletLedger);
// Ancienne recharge sans paiement : désactivée (voir wallet.controller).
router.post('/wallet/top-up', authenticate, wallet.topUpWallet);
// Recharge réelle : session Nyole, crédit à la confirmation du paiement.
router.post('/wallet/top-ups', authenticate, nyole.initializeWalletTopUp);
router.get('/mobile-money-accounts', authenticate, wallet.listMobileMoneyAccounts);
router.post('/mobile-money-accounts', authenticate, wallet.createMobileMoneyAccount);
router.patch('/mobile-money-accounts/:id/default', authenticate, validate(validators.id), wallet.setDefaultMobileMoneyAccount);
router.delete('/mobile-money-accounts/:id', authenticate, validate(validators.id), wallet.removeMobileMoneyAccount);

module.exports = router;
