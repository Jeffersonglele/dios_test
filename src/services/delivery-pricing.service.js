const prisma = require('../config/prisma');
const { badRequest, notFound } = require('../controllers/controller.utils');
const { resolveCoveredCity } = require('./geolocation.service');

const DEFAULT_CONFIG_CDF = Object.freeze({
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

const DEFAULT_CONFIG_XOF = Object.freeze({
  baseFee: 700,
  perKmRate: 500,
  includedDistanceKm: 2.5,
  maxDistanceKm: 10,
  fuelSurcharge: 0,
  demandMultiplier: 1,
  weatherMultiplier: 1,
  roundingIncrement: 50,
  currency: 'XOF',
});

const DEFAULT_CONFIG = DEFAULT_CONFIG_CDF;

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

async function configurationForCity(cityId, hintCountry = null) {
  let cityInfo = null;
  if (cityId) {
    try {
      cityInfo = await prisma.city.findFirst({ where: { cityId, deletedAt: null } });
    } catch (_) {}
  }
  const isBeninOrXof = hintCountry === 'BJ' || hintCountry === 'BENIN' || hintCountry === 'XOF'
    || cityInfo?.countryCode === 'BJ'
    || String(cityInfo?.country || '').toUpperCase().includes('BENIN')
    || String(cityInfo?.country || '').toUpperCase().includes('BÉNIN');

  const defaultConfig = isBeninOrXof ? DEFAULT_CONFIG_XOF : DEFAULT_CONFIG_CDF;

  const cityConfig = cityId ? await prisma.deliveryConfig.findFirst({
    where: { cityId, active: true }, orderBy: { updatedAt: 'desc' },
  }) : null;
  const fallbackConfig = cityConfig || await prisma.deliveryConfig.findFirst({
    where: { cityId: null, active: true }, orderBy: { updatedAt: 'desc' },
  });
  const source = fallbackConfig ? 'CITY_CONFIGURATION' : 'DEFAULT_CONFIGURATION';
  return {
    source,
    ...defaultConfig,
    ...(fallbackConfig ? {
      baseFee: toNumber(fallbackConfig.baseFee, defaultConfig.baseFee),
      perKmRate: toNumber(fallbackConfig.perKmRate, defaultConfig.perKmRate),
      includedDistanceKm: toNumber(fallbackConfig.includedDistanceKm, defaultConfig.includedDistanceKm),
      maxDistanceKm: toNumber(fallbackConfig.maxDistanceKm, defaultConfig.maxDistanceKm),
      fuelSurcharge: toNumber(fallbackConfig.fuelSurcharge, defaultConfig.fuelSurcharge),
      demandMultiplier: toNumber(fallbackConfig.demandMultiplier, defaultConfig.demandMultiplier),
      weatherMultiplier: toNumber(fallbackConfig.weatherMultiplier, defaultConfig.weatherMultiplier),
      roundingIncrement: toNumber(fallbackConfig.roundingIncrement, defaultConfig.roundingIncrement),
      currency: fallbackConfig.currency || defaultConfig.currency,
    } : {}),
  };
}

function unavailable(reason, message, details = {}) {
  return { available: false, reason, message, currency: 'CDF', ...details };
}

async function resolveRestaurantLocation(restaurant) {
  if (!restaurant) return { latitude: null, longitude: null, source: null };
  const lat = toNumber(restaurant.latitude, null);
  const lng = toNumber(restaurant.longitude, null);
  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    return { latitude: lat, longitude: lng, source: 'RESTAURANT_COLUMNS' };
  }
  let geo = null;
  try {
    const numericRestoId = Number.isInteger(restaurant.restaurantId)
      ? restaurant.restaurantId
      : Number.parseInt(String(restaurant.restaurantId ?? ''), 10);
    if (Number.isInteger(numericRestoId)) {
      const rows = await prisma.$queryRawUnsafe(`
        SELECT
          CASE WHEN location IS NOT NULL THEN ST_Y(location::geometry) END AS latitude,
          CASE WHEN location IS NOT NULL THEN ST_X(location::geometry) END AS longitude
        FROM "restaurants"
        WHERE "restaurantId" = $1 AND "deletedAt" IS NULL
        LIMIT 1
      `, numericRestoId);
      if (Array.isArray(rows) && rows[0]) {
        const r = rows[0];
        const pgLat = toNumber(r && typeof r === 'object' ? r.latitude : null, null);
        const pgLng = toNumber(r && typeof r === 'object' ? r.longitude : null, null);
        if (Number.isFinite(pgLat) && Number.isFinite(pgLng)) {
          geo = { latitude: pgLat, longitude: pgLng, source: 'RESTAURANT_POSTGIS' };
        }
      }
    }
  } catch (_) {}
  if (geo) return geo;
  try {
    const numRestaurantId = Number.parseInt(String(restaurant.restaurantId ?? ''), 10);
    const numId = Number.parseInt(String(restaurant.id ?? ''), 10);
    const orClauses = [];
    if (Number.isInteger(numRestaurantId)) {
      orClauses.push({ objectType: 'RESTAURANT', objectId: numRestaurantId });
    }
    if (Number.isInteger(numId) && numId !== numRestaurantId) {
      orClauses.push({ objectType: 'RESTAURANT', objectId: numId });
    }
    let address = null;
    if (orClauses.length > 0) {
      address = await prisma.address.findFirst({
        where: { OR: orClauses, deletedAt: null },
        orderBy: { updatedAt: 'desc' },
      });
    }
    const aLat = toNumber(address?.latitude, null);
    const aLng = toNumber(address?.longitude, null);
    if (Number.isFinite(aLat) && Number.isFinite(aLng)) {
      return { latitude: aLat, longitude: aLng, source: 'RESTAURANT_ADDRESS' };
    }
  } catch (_) {}
  return { latitude: null, longitude: null, source: null };
}

async function quoteDelivery({ restaurantId, addressId, userId }) {
  const numericRestaurantId = Number.parseInt(restaurantId, 10);
  const numericAddressId = Number.parseInt(addressId, 10);
  if (!Number.isInteger(numericRestaurantId) || !Number.isInteger(numericAddressId)) {
    throw badRequest('restaurantId et addressId sont obligatoires.');
  }

  const numericUserId = Number.isInteger(userId) ? userId : Number.parseInt(String(userId ?? ''), 10);
  const [restaurant, address] = await Promise.all([
    prisma.restaurant.findFirst({ where: { restaurantId: numericRestaurantId, deletedAt: null } }),
    prisma.address.findFirst({
      where: {
        addressId: numericAddressId,
        ...(Number.isInteger(numericUserId) ? { objectId: numericUserId } : {}),
        deletedAt: null,
      },
    }),
  ]);
  if (!restaurant) throw notFound('Restaurant');
  if (!address) throw notFound('Adresse de livraison');

  const resLoc = await resolveRestaurantLocation(restaurant);
  const lat = Number.isFinite(resLoc.latitude) ? resLoc.latitude : toNumber(restaurant.latitude, null);
  const lng = Number.isFinite(resLoc.longitude) ? resLoc.longitude : toNumber(restaurant.longitude, null);
  const addressLat = toNumber(address.latitude, null);
  const addressLng = toNumber(address.longitude, null);

  const restaurantDeliveryFee = toNumber(restaurant.deliveryFee, 0);
  const countryHint = restaurant.country || restaurant.currency || address.country;
  const fallbackCityConfig = (address.cityId != null)
    ? await configurationForCity(address.cityId, countryHint)
    : await configurationForCity(restaurant.cityId || null, countryHint);
  const fallbackFee = restaurantDeliveryFee > 0
    ? { fee: restaurantDeliveryFee, currency: restaurant.currency || fallbackCityConfig.currency, source: 'RESTAURANT_FIXED_FEE' }
    : { fee: fallbackCityConfig.baseFee, currency: fallbackCityConfig.currency, source: fallbackCityConfig.source };

  const hasFullGps = [lat, lng, addressLat, addressLng].every(Number.isFinite);
  if (!hasFullGps) {
    const missingRestaurant = !(Number.isFinite(lat) && Number.isFinite(lng));
    const missingCustomer = !(Number.isFinite(addressLat) && Number.isFinite(addressLng));
    return {
      available: true,
      reason: null,
      currency: fallbackFee.currency,
      deliveryFee: fallbackFee.fee,
      estimatedDistanceKm: null,
      distanceKind: 'NO_GPS_FALLBACK',
      cityId: address.cityId || restaurant.cityId || null,
      city: address.city || null,
      noGpsFallback: true,
      missingRestaurantLocation: missingRestaurant,
      missingCustomerLocation: missingCustomer,
      pricing: {
        source: `NO_GPS_${fallbackFee.source}`,
        baseFee: fallbackFee.fee,
        includedDistanceKm: 0,
        perKmRate: 0,
        maxDistanceKm: fallbackCityConfig.maxDistanceKm,
        fuelSurcharge: 0,
        demandMultiplier: 1,
        weatherMultiplier: 1,
      },
      warning: missingRestaurant
        ? "Position du restaurant non définie — utilisation d'un tarif de livraison forfaitaire. Veuillez définir les coordonnées du restaurant."
        : missingCustomer
            ? "Position de livraison non définie — utilisation d'un tarif forfaitaire."
            : "Utilisation d'un tarif de livraison forfaitaire.",
    };
  }

  const [restaurantCity, customerCity] = await Promise.all([
    resolveCoveredCity(lat, lng),
    resolveCoveredCity(addressLat, addressLng),
  ]);
  if (!restaurantCity || !customerCity) {
    return {
      available: true,
      currency: fallbackFee.currency,
      deliveryFee: fallbackFee.fee,
      estimatedDistanceKm: null,
      distanceKind: 'OUTSIDE_CITY_FALLBACK',
      cityId: customerCity?.cityId || address.cityId || restaurant.cityId || null,
      city: customerCity?.name || address.city || null,
      noGpsFallback: true,
      pricing: {
        source: `OUTSIDE_CITY_${fallbackFee.source}`,
        baseFee: fallbackFee.fee,
        includedDistanceKm: 0,
        perKmRate: 0,
        maxDistanceKm: fallbackCityConfig.maxDistanceKm,
        fuelSurcharge: 0,
        demandMultiplier: 1,
        weatherMultiplier: 1,
      },
      warning: 'Hors ville couverte — utilisation du tarif forfaitaire.',
    };
  }
  if (restaurantCity.cityId !== customerCity.cityId) {
    return unavailable('DIFFERENT_CITY', 'Marchand hors de votre zone de livraison.', {
      restaurantCity: restaurantCity.name,
      customerCity: customerCity.name,
    });
  }

  let config;
  let pricingSource;
  if (restaurantDeliveryFee > 0) {
    config = {
      ...DEFAULT_CONFIG,
      baseFee: restaurantDeliveryFee,
      perKmRate: 0,
      includedDistanceKm: Infinity,
      currency: restaurant.currency || DEFAULT_CONFIG.currency,
    };
    pricingSource = 'RESTAURANT_FEE';
  } else {
    config = await configurationForCity(customerCity.cityId);
    pricingSource = config.source;
  }

  const straightLineDistanceKm = haversineKm(lat, lng, addressLat, addressLng);
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
      source: pricingSource,
      baseFee: config.baseFee,
      includedDistanceKm: config.includedDistanceKm,
      perKmRate: config.perKmRate,
      maxDistanceKm: config.maxDistanceKm,
      fuelSurcharge: config.fuelSurcharge,
      demandMultiplier: config.demandMultiplier,
      weatherMultiplier: config.weatherMultiplier,
    },
    resolvedRestaurantLocation: Number.isFinite(resLoc.latitude)
      ? { latitude: resLoc.latitude, longitude: resLoc.longitude, source: resLoc.source }
      : undefined,
  };
}

module.exports = { configurationForCity, haversineKm, quoteDelivery, resolveRestaurantLocation, roundedCdf };
