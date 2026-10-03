const express = require('express');

const { catalog } = require('../controllers');
const { authenticate, optionalAuthenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');
const deliveryPricing = require('../services/delivery-pricing.service');

const router = express.Router();
const restaurants = express.Router();

restaurants.get('/:restaurantId/menu', optionalAuthenticate, catalog.restaurant.getMenu);
restaurants.get('/legacy/:restaurantId', optionalAuthenticate, catalog.restaurant.getByLegacy);
restaurants.post('/legacy', authenticate, catalog.restaurant.manageLegacy);
restaurants.patch('/legacy/:restaurantId', authenticate, catalog.restaurant.manageLegacy);
restaurants.delete('/legacy/:restaurantId', authenticate, catalog.restaurant.deleteByLegacy);
restaurants.patch('/:id/availability', authenticate, validate(validators.id), catalog.restaurant.setAvailability);
restaurants.use('/', createResourceRouter(catalog.restaurant, { readMiddlewares: [optionalAuthenticate] }));

// Route pour calculer les frais de livraison par coordonnées GPS
router.post('/cart/calculate-shipping', optionalAuthenticate, async (req, res, next) => {
  try {
    const { restaurantId, deliveryLat, deliveryLng } = req.body;
    if (!restaurantId || !Number.isFinite(deliveryLat) || !Number.isFinite(deliveryLng)) {
      return res.status(400).json({
        success: false,
        error: 'restaurantId, deliveryLat et deliveryLng sont obligatoires'
      });
    }

    const restaurant = await require('../config/prisma').restaurant.findFirst({
      where: { restaurantId: Number.parseInt(restaurantId, 10), deletedAt: null }
    });

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        error: 'Restaurant non trouvé'
      });
    }

    if (![restaurant.latitude, restaurant.longitude].every(Number.isFinite)) {
      return res.status(400).json({
        success: false,
        error: 'Les coordonnées GPS du restaurant ne sont pas définies'
      });
    }

    const straightLineDistanceKm = deliveryPricing.haversineKm(
      restaurant.latitude,
      restaurant.longitude,
      deliveryLat,
      deliveryLng
    );

    // Priorité: restaurant deliveryFee > deliveryConfig > fallback
    const restaurantDeliveryFee = Number(restaurant.deliveryFee) || 0;
    let config;
    let pricingSource;

    if (restaurantDeliveryFee > 0) {
      config = {
        baseFee: restaurantDeliveryFee,
        perKmRate: 0,
        includedDistanceKm: Infinity,
        currency: restaurant.currency || 'CDF',
      };
      pricingSource = 'RESTAURANT_FEE';
    } else {
      config = await deliveryPricing.configurationForCity(restaurant.cityId || 1);
      pricingSource = config.source;
    }

    const routeFactor = Math.max(1, Number(process.env.ROUTE_DISTANCE_FACTOR) || 1.25);
    const estimatedDistanceKm = straightLineDistanceKm * routeFactor;

    if (estimatedDistanceKm > config.maxDistanceKm) {
      return res.status(400).json({
        success: false,
        error: 'Hors zone de livraison',
        data: {
          estimatedDistanceKm: Number(estimatedDistanceKm.toFixed(2)),
          maxDistanceKm: config.maxDistanceKm
        }
      });
    }

    const extraDistance = Math.max(0, estimatedDistanceKm - config.includedDistanceKm);
    const rawFee = (config.baseFee + (extraDistance * config.perKmRate) + config.fuelSurcharge)
      * config.demandMultiplier * config.weatherMultiplier;
    const fee = deliveryPricing.roundedCdf ? 
      deliveryPricing.roundedCdf(rawFee, Math.max(1, config.roundingIncrement)) :
      Math.ceil(rawFee / Math.max(1, config.roundingIncrement)) * Math.max(1, config.roundingIncrement);

    res.json({
      success: true,
      data: {
        distanceKm: Number(estimatedDistanceKm.toFixed(2)),
        shippingFee: fee,
        currency: config.currency,
        pricing: {
          source: pricingSource,
          baseFee: config.baseFee,
          includedDistanceKm: config.includedDistanceKm,
          perKmRate: config.perKmRate
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

router.use('/restaurants', restaurants);
router.use('/dishes', createResourceRouter(catalog.dish));
router.use('/categories', createResourceRouter(catalog.category));
router.use('/gallery', createResourceRouter(catalog.gallery));

module.exports = router;
