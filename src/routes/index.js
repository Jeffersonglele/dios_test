const express = require('express');

const addresses = require('./addresses.routes');
const auth = require('./auth.routes');
const catalog = require('./catalog.routes');
const communication = require('./communication.routes');
const delivery = require('./delivery.routes');
const geocoding = require('./geocoding.routes');
const operations = require('./operations.routes');
const orders = require('./orders.routes');
const payments = require('./payments.routes');
const users = require('./users.routes');
const uploads = require('./uploads.routes');
const verification = require('./verification.routes');
const wallet = require('./wallet.routes');

const router = express.Router();

router.use('/auth', auth);
router.use('/users', users);
router.use('/', uploads);
router.use('/', catalog);
router.use('/addresses', addresses);
router.use('/orders', orders.router);
router.use('/order-lines', orders.orderLinesRouter);
router.use('/', payments);
router.use('/', delivery);
router.use('/geocoding', geocoding);
router.use('/', verification);
router.use('/', communication);
router.use('/', operations);
router.use('/', wallet);

module.exports = router;
