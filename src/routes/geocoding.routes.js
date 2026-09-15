const express = require('express');

const geocoding = require('../controllers/geocoding.controller');
const { authenticate } = require('../middlware/auth.middleware');

const router = express.Router();

router.get('/search', authenticate, geocoding.search);
router.get('/reverse', authenticate, geocoding.reverse);

module.exports = router;
