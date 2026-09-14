const express = require('express');

const { catalog } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const restaurants = express.Router();

restaurants.get('/:restaurantId/menu', catalog.restaurant.getMenu);
restaurants.patch('/:id/availability', authenticate, validate(validators.id), catalog.restaurant.setAvailability);
restaurants.use('/', createResourceRouter(catalog.restaurant));

router.use('/restaurants', restaurants);
router.use('/dishes', createResourceRouter(catalog.dish));
router.use('/categories', createResourceRouter(catalog.category));
router.use('/gallery', createResourceRouter(catalog.gallery));

module.exports = router;
