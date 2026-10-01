const express = require('express');

const { catalog } = require('../controllers');
const { authenticate, optionalAuthenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const restaurants = express.Router();

restaurants.get('/:restaurantId/menu', optionalAuthenticate, catalog.restaurant.getMenu);
restaurants.get('/legacy/:restaurantId', optionalAuthenticate, catalog.restaurant.getByLegacy);
restaurants.post('/legacy', authenticate, catalog.restaurant.manageLegacy);
restaurants.patch('/legacy/:restaurantId', authenticate, catalog.restaurant.manageLegacy);
restaurants.delete('/legacy/:restaurantId', authenticate, catalog.restaurant.deleteByLegacy);
restaurants.patch('/:id/availability', authenticate, validate(validators.id), catalog.restaurant.setAvailability);
restaurants.use('/', createResourceRouter(catalog.restaurant, { readMiddlewares: [optionalAuthenticate] }));

router.use('/restaurants', restaurants);
router.use('/dishes', createResourceRouter(catalog.dish));
router.use('/categories', createResourceRouter(catalog.category));
router.use('/gallery', createResourceRouter(catalog.gallery));

module.exports = router;
