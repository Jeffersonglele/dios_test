const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');
const dispatch = require('../services/delivery-dispatch.service');
const geolocation = require('../services/geolocation.service');
const { quoteDelivery } = require('../services/delivery-pricing.service');

const CITY_FIELDS = ['cityId', 'name', 'country', 'countryCode', 'deliveryEnabled', 'active'];
const ZONE_FIELDS = [
  'zoneId', 'cityId', 'name', 'polygon', 'deliveryTimeMin', 'deliveryTimeMax',
  'deliveryFeeLevel', 'priority', 'active',
];
const CONFIG_FIELDS = [
  'configId', 'cityId', 'baseFee', 'perKmRate', 'includedDistanceKm', 'maxDistanceKm',
  'fuelPricePerLitre', 'fuelSurcharge', 'demandMultiplier', 'weatherMultiplier', 'roundingIncrement',
  'currency', 'minFee', 'updatedBy', 'active',
  'commissionRate', 'exchangeRate', 'delivererBasePay', 'delivererPerKm', 'subscriptionsEnabled',
];

const city = createCrudController({
  delegate: 'city', resource: 'Ville', fields: CITY_FIELDS, filterFields: ['country', 'active'],
});
const zone = createCrudController({
  delegate: 'deliveryZone', resource: 'Zone de livraison', fields: ZONE_FIELDS,
  filterFields: ['cityId', 'active', 'deliveryFeeLevel'],
});
const config = createCrudController({
  delegate: 'deliveryConfig', resource: 'Configuration de livraison', fields: CONFIG_FIELDS,
  hasSoftDelete: false, filterFields: ['active'],
});

function pointIsInsidePolygon(latitude, longitude, polygon) {
  // Polygon format: [[latitude, longitude], ...]. The API validates it before use.
  let isInside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [latI, lngI] = polygon[i];
    const [latJ, lngJ] = polygon[j];
    const intersects = ((lngI > longitude) !== (lngJ > longitude))
      && (latitude < ((latJ - latI) * (longitude - lngI)) / (lngJ - lngI) + latI);
    if (intersects) isInside = !isInside;
  }
  return isInside;
}

async function resolveZone(req, res, next) {
  try {
    const cityId = Number.parseInt(req.body.cityId, 10);
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    if (!Number.isInteger(cityId) || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw badRequest('cityId, latitude et longitude sont obligatoires.');
    }

    const postgisMatches = await prisma.$queryRaw`
      SELECT "id"
      FROM "delivery_zones"
      WHERE "cityId" = ${cityId}
        AND "active" = true
        AND "deletedAt" IS NULL
        AND "boundary" IS NOT NULL
        AND ST_Covers("boundary", ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326))
      ORDER BY "priority" DESC NULLS LAST
      LIMIT 1
    `;
    if (postgisMatches[0]) {
      const zoneMatch = await prisma.deliveryZone.findUnique({ where: { id: postgisMatches[0].id } });
      return res.status(200).json({ data: zoneMatch, meta: { resolution: 'POSTGIS' } });
    }

    const zones = await prisma.deliveryZone.findMany({
      where: { cityId, active: true, deletedAt: null },
      orderBy: { priority: 'desc' },
    });
    const zoneMatch = zones.find((zone) => {
      try {
        const polygon = JSON.parse(zone.polygon);
        return Array.isArray(polygon) && polygon.length >= 3 && pointIsInsidePolygon(latitude, longitude, polygon);
      } catch (_) {
        return false;
      }
    });
    if (!zoneMatch) throw notFound('Zone de livraison');
    return res.status(200).json({ data: zoneMatch, meta: { resolution: 'LEGACY_POLYGON' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function activeConfig(req, res, next) {
  try {
    const cityId = req.query.cityId === undefined ? null : Number.parseInt(req.query.cityId, 10);
    if (req.query.cityId !== undefined && !Number.isInteger(cityId)) throw badRequest('cityId est invalide.');
    const record = await prisma.deliveryConfig.findFirst({
      where: { active: true, ...(cityId === null ? {} : { cityId }) },
      orderBy: { updatedAt: 'desc' },
    });
    if (!record) throw notFound('Configuration de livraison');
    return res.status(200).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function quote(req, res, next) {
  try {
    const data = await quoteDelivery({
      restaurantId: req.body.restaurantId,
      addressId: req.body.addressId,
      userId: req.auth.userId,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateAddressLocation(req, res, next) {
  try {
    const data = await geolocation.updateCustomerAddressLocation({
      addressId: req.params.addressId,
      userId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      fullAddress: req.body.fullAddress,
      nominatimPlaceId: req.body.nominatimPlaceId,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateRestaurantLocation(req, res, next) {
  try {
    const data = await geolocation.updateRestaurantLocation({
      restaurantId: req.params.restaurantId,
      ownerId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      address: req.body.address,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCityBoundary(req, res, next) {
  try {
    const data = await geolocation.setCityBoundary(req.params.cityId, req.body.geoJson || req.body);
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCourierAvailability(req, res, next) {
  try {
    const data = await geolocation.setCourierAvailability({ userId: req.auth.userId, status: req.body.status });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCourierLocation(req, res, next) {
  try {
    const data = await geolocation.recordCourierLocation({
      userId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      accuracyM: req.body.accuracyM,
    });
    return res.status(201).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listCourierOffers(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.courierOffers(req.auth.userId) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listCourierDeliveries(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.courierDeliveries(req.auth.userId) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function acceptDeliveryOffer(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.acceptOffer({ offerId: req.params.id, delivererId: req.auth.userId }) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function rejectDeliveryOffer(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.rejectOffer({ offerId: req.params.id, delivererId: req.auth.userId }) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateDeliveryStatus(req, res, next) {
  try {
    const data = await dispatch.advanceDelivery({
      deliveryId: req.params.id,
      delivererId: req.auth.userId,
      status: req.body.status,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  city,
  zone: { ...zone, resolve: resolveZone },
  config: { ...config, active: activeConfig },
  quote,
  updateAddressLocation,
  updateRestaurantLocation,
  updateCityBoundary,
  updateCourierAvailability,
  updateCourierLocation,
  listCourierOffers,
  listCourierDeliveries,
  acceptDeliveryOffer,
  rejectDeliveryOffer,
  updateDeliveryStatus,
  pointIsInsidePolygon,
};
