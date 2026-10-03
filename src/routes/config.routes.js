const express = require('express');
const configController = require('../controllers/config.controller');
const geoIpMiddleware = require('../middlware/geoip.middleware');

const router = express.Router();

router.get('/config/currency', geoIpMiddleware, configController.getConfig);

module.exports = router;
