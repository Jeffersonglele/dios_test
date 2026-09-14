const express = require('express');

const { delivery } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.post('/delivery-zones/resolve', delivery.zone.resolve);
router.get('/delivery-configs/active', delivery.config.active);
router.use('/cities', createResourceRouter(delivery.city));
router.use('/delivery-zones', createResourceRouter(delivery.zone));
router.use('/delivery-configs', createResourceRouter(delivery.config, { readMiddlewares: [authenticate] }));

module.exports = router;
