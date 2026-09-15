const prisma = require('../config/prisma');
const { badRequest, notFound } = require('../controllers/controller.utils');
const { resolveCoveredCity } = require('./geolocation.service');

const DEFAULT_CONFIG = Object.freeze({
  baseFee: 2000,
  perKmRate: 500,
  includedDistanceKm: 2.5,
  maxDistanceKm: 10,
  fuelSurcharge: 0,
  demandMultiplier: 1,
  weatherMultiplier: 1,
  roundingIncrement: 50,
  currency: 'CDF',
});

function toNumber(value, fallback) {
  if (value === null || value === undefined) return fallback;
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function haversineKm(latitudeA, longitudeA, latitudeB, longitudeB) {
  const toRadians = (value) => value * (Math.PI / 180);
  const earthRadiusKm = 6371.0088;
  const dLatitude = toRadians(latitudeB - latitudeA);
  const dLongitude = toRadians(longitudeB - longitudeA);
  const a = Math.sin(dLatitude / 2) ** 2
    + Math.cos(toRadians(latitudeA)) * Math.cos(toRadians(latitudeB)) * Math.sin(dLongitude / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function roundedCdf(amount, increment) {
  return Math.ceil(amount / increment) * increment;
}

async function configurationForCity(cityId) {
  const cityConfig = await prisma.deliveryConfig.findFirst({
    where: { cityId, active: true }, orderBy: { updatedAt: 'desc' },
  });
  const fallbackConfig = cityConfig || await prisma.deliveryConfig.findFirst({
    where: { cityId: null, active: true }, orderBy: { updatedAt: 'desc' },
  });
  const source = fallbackConfig ? 'CITY_CONFIGURATION' : 'DEFAULT_CONFIGURATION';
  return {
    source,
    ...DEFAULT_CONFIG,
    ...(fallbackConfig ? {
      baseFee: toNumber(fallbackConfig.baseFee, DEFAULT_CONFIG.baseFee),
      perKmRate: toNumber(fallbackConfig.perKmRate, DEFAULT_CONFIG.perKmRate),
      includedDistanceKm: toNumber(fallbackConfig.includedDistanceKm, DEFAULT_CONFIG.includedDistanceKm),
      maxDistanceKm: toNumber(fallbackConfig.maxDistanceKm, DEFAULT_CONFIG.maxDistanceKm),
      fuelSurcharge: toNumber(fallbackConfig.fuelSurcharge, DEFAULT_CONFIG.fuelSurcharge),
      demandMultiplier: toNumber(fallbackConfig.demandMultiplier, DEFAULT_CONFIG.demandMultiplier),
      weatherMultiplier: toNumber(fallbackConfig.weatherMultiplier, DEFAULT_CONFIG.weatherMultiplier),
      roundingIncrement: toNumber(fallbackConfig.roundingIncrement, DEFAULT_CONFIG.roundingIncrement),
      currency: fallbackConfig.currency || DEFAULT_CONFIG.currency,
    } : {}),
  };
}

function unavailable(reason, message, details = {}) {
  return { available: false, reason, message, currency: 'CDF', ...details };
}

async function quoteDelivery({ restaurantId, addressId, userId }) {
  const numericRestaurantId = Number.parseInt(restaurantId, 10);
  const numericAddressId = Number.parseInt(addressId, 10);
  if (!Number.isInteger(numericRestaurantId) || !Number.isInteger(numericAddressId)) {
    throw badRequest('restaurantId et addressId sont obligatoires.');
  }

  const [restaurant, address] = await Promise.all([
    prisma.restaurant.findFirst({ where: { restaurantId: numericRestaurantId, deletedAt: null } }),
    prisma.address.findFirst({ where: { addressId: numericAddressId, objectId: userId, deletedAt: null } }),
  ]);
  if (!restaurant) throw notFound('Restaurant');
  if (!address) throw notFound('Adresse de livraison');
  if (![restaurant.latitude, restaurant.longitude, address.latitude, address.longitude].every(Number.isFinite)) {
    return unavailable('MISSING_LOCATION', 'La position du marchand ou de livraison doit être définie.');
  }

  const [restaurantCity, customerCity] = await Promise.all([
    resolveCoveredCity(restaurant.latitude, restaurant.longitude),
    resolveCoveredCity(address.latitude, address.longitude),
  ]);
  if (!restaurantCity || !customerCity) {
    return unavailable('OUTSIDE_COVERED_CITY', 'Le marchand ou votre adresse est hors des villes couvertes.');
  }
  if (restaurantCity.cityId !== customerCity.cityId) {
    return unavailable('DIFFERENT_CITY', 'Marchand hors de votre zone de livraison.', {
      restaurantCity: restaurantCity.name,
      customerCity: customerCity.name,
    });
  }

  const config = await configurationForCity(customerCity.cityId);
  const straightLineDistanceKm = haversineKm(
    restaurant.latitude,
    restaurant.longitude,
    address.latitude,
    address.longitude,
  );
  const routeFactor = Math.max(1, Number(process.env.ROUTE_DISTANCE_FACTOR) || 1.25);
  const estimatedDistanceKm = straightLineDistanceKm * routeFactor;
  if (estimatedDistanceKm > config.maxDistanceKm) {
    return unavailable('OUT_OF_RADIUS', 'Marchand hors de votre zone de livraison.', {
      city: customerCity.name,
      estimatedDistanceKm: Number(estimatedDistanceKm.toFixed(2)),
      maxDistanceKm: config.maxDistanceKm,
    });
  }

  const extraDistance = Math.max(0, estimatedDistanceKm - config.includedDistanceKm);
  const rawFee = (config.baseFee + (extraDistance * config.perKmRate) + config.fuelSurcharge)
    * config.demandMultiplier * config.weatherMultiplier;
  const fee = roundedCdf(rawFee, Math.max(1, config.roundingIncrement));
  return {
    available: true,
    cityId: customerCity.cityId,
    city: customerCity.name,
    currency: config.currency,
    deliveryFee: fee,
    estimatedDistanceKm: Number(estimatedDistanceKm.toFixed(2)),
    distanceKind: 'ESTIMATED_ROAD_DISTANCE',
    pricing: {
      source: config.source,
      baseFee: config.baseFee,
      includedDistanceKm: config.includedDistanceKm,
      perKmRate: config.perKmRate,
      maxDistanceKm: config.maxDistanceKm,
      fuelSurcharge: config.fuelSurcharge,
      demandMultiplier: config.demandMultiplier,
      weatherMultiplier: config.weatherMultiplier,
    },
  };
}

module.exports = { configurationForCity, haversineKm, quoteDelivery };
