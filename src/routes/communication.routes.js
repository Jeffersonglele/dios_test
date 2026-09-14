const express = require('express');

const { communication } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const authenticated = { readMiddlewares: [authenticate], writeMiddlewares: [authenticate] };

router.use('/messages', createResourceRouter(communication.message, authenticated));
router.use('/comments', createResourceRouter(communication.comment, authenticated));
router.use('/reports', createResourceRouter(communication.report, authenticated));

module.exports = router;
