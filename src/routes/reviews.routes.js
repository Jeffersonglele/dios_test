const express = require('express');

const reviews = require('../controllers/reviews.controller');
const { authenticate } = require('../middlware/auth.middleware');

const router = express.Router();

// Lecture publique (fiche restaurant / plat), écriture réservée au client
// connecté ayant une commande livrée.
router.get('/summary', reviews.reviewSummary);
router.get('/', reviews.listReviews);
router.post('/', authenticate, reviews.createReview);

module.exports = router;
