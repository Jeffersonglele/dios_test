const express = require('express');
const { admin } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');

const router = express.Router();

router.get('/dashboard-stats', authenticate, authorize('ADMIN'), admin.getDashboardStats);
router.patch('/restaurants/:restaurantId', authenticate, authorize('ADMIN'), admin.validateRestaurant);
router.patch('/users/:userId/identity-status', authenticate, authorize('ADMIN'), admin.setIdentityStatus);

module.exports = router;
