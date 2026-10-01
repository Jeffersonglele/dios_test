const express = require('express');

const adminController = require('../controllers/admin.controller');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');

const router = express.Router();

// Only ADMIN can access these routes
router.use(authenticate, authorize('ADMIN'));

router.get('/dashboard-stats', adminController.getDashboardStats);
router.post('/send-email', adminController.sendEmail);
router.delete('/users/:userId/force', adminController.forceDeleteUser);

router.get('/pro-documents', adminController.getProDocuments);
router.patch('/pro-documents/validate', adminController.validateProDocuments);

router.get('/delivery-documents', adminController.getDeliveryDocuments);
router.patch('/delivery-documents/validate', adminController.validateDeliveryDocuments);

router.get('/scheduled-deletions', adminController.getScheduledDeletions);

router.get('/referral-stats', adminController.getReferralStats);

router.get('/countries', adminController.getAvailableCountries);

router.patch('/restaurants/:restaurantId', adminController.validateRestaurant);
router.patch('/users/:userId/identity-status', adminController.setIdentityStatus);
router.get('/users/:userId/details', adminController.getUserDetailsByLegacyId);
router.patch('/users/:userId/profile', adminController.updateUserProfileByLegacyId);

module.exports = router;
