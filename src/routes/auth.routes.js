const express = require('express');

const { auth } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');

const router = express.Router();

router.post('/register', validate(validators.register), auth.register);
router.post('/login', validate(validators.login), auth.login);
router.get('/me', authenticate, auth.me);
router.post('/password/reset-request', validate(validators.resetRequest), auth.requestPasswordReset);
router.post('/password/reset', validate(validators.resetPassword), auth.resetPassword);

module.exports = router;
