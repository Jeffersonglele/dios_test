const express = require('express');

const { delivery } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const adminOnly = [authenticate, authorize('ADMIN')];

router.post('/delivery-zones/resolve', delivery.zone.resolve);
router.get('/delivery-configs/active', delivery.config.active);
router.post('/delivery/quote', authenticate, delivery.quote);
router.patch('/addresses/:addressId/location', authenticate, delivery.updateAddressLocation);
router.patch('/restaurants/:restaurantId/location', authenticate, authorize('RESTAURATEUR'), delivery.updateRestaurantLocation);
router.patch('/cities/:cityId/boundary', authenticate, authorize('ADMIN'), delivery.updateCityBoundary);
router.patch('/couriers/me/availability', authenticate, authorize('LIVREUR'), delivery.updateCourierAvailability);
router.post('/couriers/me/location', authenticate, authorize('LIVREUR'), delivery.updateCourierLocation);
router.get('/couriers/me/offers', authenticate, authorize('LIVREUR'), delivery.listCourierOffers);
router.get('/couriers/me/deliveries', authenticate, authorize('LIVREUR'), delivery.listCourierDeliveries);
router.post('/delivery-offers/:id/accept', authenticate, authorize('LIVREUR'), delivery.acceptDeliveryOffer);
router.post('/delivery-offers/:id/reject', authenticate, authorize('LIVREUR'), delivery.rejectDeliveryOffer);
router.patch('/deliveries/:id/status', authenticate, authorize('LIVREUR'), delivery.updateDeliveryStatus);
router.use('/cities', createResourceRouter(delivery.city, { writeMiddlewares: adminOnly, removeMiddlewares: adminOnly }));
router.use('/delivery-zones', createResourceRouter(delivery.zone, { writeMiddlewares: adminOnly, removeMiddlewares: adminOnly }));
router.use('/delivery-configs', createResourceRouter(delivery.config, {
  readMiddlewares: [authenticate], writeMiddlewares: adminOnly, removeMiddlewares: adminOnly,
}));

module.exports = router;
