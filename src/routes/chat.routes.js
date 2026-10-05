const express = require('express');
const { authenticate } = require('../middlware/auth.middleware');
const chatController = require('../controllers/chat.controller');

const router = express.Router();

router.get('/orders/:orderId/messages', authenticate, chatController.getOrderMessages);

module.exports = router;
