const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');

const CITY_FIELDS = ['cityId', 'name', 'country', 'active'];
const ZONE_FIELDS = [
  'zoneId', 'cityId', 'name', 'polygon', 'deliveryTimeMin', 'deliveryTimeMax',
  'deliveryFeeLevel', 'priority', 'active',
];
const CONFIG_FIELDS = [
  'configId', 'baseFee', 'perKmRate', 'currency', 'minFee', 'updatedBy', 'active',
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
    return res.status(200).json({ data: zoneMatch });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function activeConfig(req, res, next) {
  try {
    const record = await prisma.deliveryConfig.findFirst({ where: { active: true }, orderBy: { updatedAt: 'desc' } });
    if (!record) throw notFound('Configuration de livraison');
    return res.status(200).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  city,
  zone: { ...zone, resolve: resolveZone },
  config: { ...config, active: activeConfig },
  pointIsInsidePolygon,
};
