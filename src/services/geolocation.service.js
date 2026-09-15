const { Prisma } = require('@prisma/client');

const prisma = require('../config/prisma');
const { badRequest, notFound } = require('../controllers/controller.utils');

function coordinates(latitude, longitude) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw badRequest('Les coordonnées GPS sont invalides.');
  }
  return { latitude: lat, longitude: lng };
}

function pointSql(latitude, longitude) {
  return Prisma.sql`ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)`;
}

async function resolveCoveredCity(latitude, longitude, client = prisma) {
  const point = pointSql(latitude, longitude);
  const cities = await client.$queryRaw(Prisma.sql`
    SELECT "cityId", "name", "country", "country_code" AS "countryCode"
    FROM "cities"
    WHERE "deletedAt" IS NULL
      AND "active" = true
      AND "delivery_enabled" = true
      AND "country_code" = 'CD'
      AND "boundary" IS NOT NULL
      AND ST_Covers("boundary", ${point})
    ORDER BY "updatedAt" DESC
    LIMIT 1
  `);
  return cities[0] || null;
}

function normalizeGeoJson(geoJson) {
  const geometry = geoJson?.type === 'Feature' ? geoJson.geometry : geoJson;
  if (!geometry || !['Polygon', 'MultiPolygon'].includes(geometry.type) || !Array.isArray(geometry.coordinates)) {
    throw badRequest('La limite doit être un GeoJSON Polygon ou MultiPolygon.');
  }
  return geometry.type === 'Polygon'
    ? { type: 'MultiPolygon', coordinates: [geometry.coordinates] }
    : geometry;
}

async function setCityBoundary(cityId, geoJson) {
  const numericCityId = Number.parseInt(cityId, 10);
  if (!Number.isInteger(numericCityId)) throw badRequest('cityId est obligatoire.');
  const geometry = normalizeGeoJson(geoJson);
  const city = await prisma.city.findFirst({ where: { cityId: numericCityId, deletedAt: null } });
  if (!city) throw notFound('Ville');

  await prisma.$executeRaw(Prisma.sql`
    UPDATE "cities"
    SET "boundary" = ST_SetSRID(ST_GeomFromGeoJSON(${JSON.stringify(geometry)}), 4326),
        "updatedAt" = NOW()
    WHERE "id" = ${city.id}::uuid
  `);
  return prisma.city.findUnique({ where: { id: city.id } });
}

async function updateCustomerAddressLocation({ addressId, userId, latitude, longitude, fullAddress, nominatimPlaceId }) {
  const point = coordinates(latitude, longitude);
  const numericAddressId = Number.parseInt(addressId, 10);
  if (!Number.isInteger(numericAddressId)) throw badRequest('addressId est obligatoire.');

  const address = await prisma.address.findFirst({
    where: { addressId: numericAddressId, objectId: userId, deletedAt: null },
  });
  if (!address) throw notFound('Adresse cliente');

  const city = await resolveCoveredCity(point.latitude, point.longitude);
  if (!city) throw badRequest('Cette position ne se trouve dans aucune ville couverte en RDC.');

  await prisma.$transaction(async (tx) => {
    await tx.address.update({
      where: { id: address.id },
      data: {
        latitude: point.latitude,
        longitude: point.longitude,
        cityId: city.cityId,
        country: city.country || 'RDC',
        ...(fullAddress ? { fullAddress: String(fullAddress).trim() } : {}),
        ...(nominatimPlaceId ? { nominatimPlaceId: String(nominatimPlaceId) } : {}),
        locationSource: 'DEVICE_GPS',
        locationUpdatedAt: new Date(),
      },
    });
    await tx.$executeRaw(Prisma.sql`
      UPDATE "addresses"
      SET "location" = ${pointSql(point.latitude, point.longitude)}::geography
      WHERE "id" = ${address.id}::uuid
    `);
  });
  return prisma.address.findUnique({ where: { id: address.id } });
}

async function updateRestaurantLocation({ restaurantId, ownerId, latitude, longitude, address }) {
  const point = coordinates(latitude, longitude);
  const numericRestaurantId = Number.parseInt(restaurantId, 10);
  if (!Number.isInteger(numericRestaurantId)) throw badRequest('restaurantId est obligatoire.');
  const restaurant = await prisma.restaurant.findFirst({
    where: { restaurantId: numericRestaurantId, userId: ownerId, deletedAt: null },
  });
  if (!restaurant) throw notFound('Restaurant');
  const city = await resolveCoveredCity(point.latitude, point.longitude);
  if (!city) throw badRequest('Le point de vente doit être situé dans une ville couverte en RDC.');

  await prisma.$transaction(async (tx) => {
    await tx.restaurant.update({
      where: { id: restaurant.id },
      data: {
        latitude: point.latitude,
        longitude: point.longitude,
        cityId: city.cityId,
        country: city.country || 'RDC',
        ...(address ? { address: String(address).trim() } : {}),
        locationUpdatedAt: new Date(),
      },
    });
    await tx.$executeRaw(Prisma.sql`
      UPDATE "restaurants"
      SET "location" = ${pointSql(point.latitude, point.longitude)}::geography
      WHERE "id" = ${restaurant.id}::uuid
    `);
  });
  return prisma.restaurant.findUnique({ where: { id: restaurant.id } });
}

async function setCourierAvailability({ userId, status }) {
  const normalizedStatus = String(status || '').toUpperCase();
  if (!['ACTIVE', 'INACTIVE'].includes(normalizedStatus)) {
    throw badRequest('Le statut livreur doit être ACTIVE ou INACTIVE.');
  }
  const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
  if (!user) throw notFound('Livreur');
  if (normalizedStatus === 'ACTIVE' && !user.locationUpdatedAt) {
    throw badRequest('Partagez votre position avant de devenir disponible.');
  }
  return prisma.user.update({ where: { id: user.id }, data: { courierStatus: normalizedStatus } });
}

async function recordCourierLocation({ userId, latitude, longitude, accuracyM }) {
  const point = coordinates(latitude, longitude);
  const accuracy = accuracyM === undefined ? null : Number(accuracyM);
  if (accuracy !== null && (!Number.isFinite(accuracy) || accuracy < 0 || accuracy > 10000)) {
    throw badRequest('La précision GPS est invalide.');
  }
  const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
  if (!user) throw notFound('Livreur');
  const city = await resolveCoveredCity(point.latitude, point.longitude);
  if (!city) throw badRequest('La position du livreur est hors des villes couvertes.');

  const location = await prisma.$transaction(async (tx) => {
    const created = await tx.courierLocation.create({
      data: {
        delivererId: userId,
        cityId: city.cityId,
        latitude: point.latitude,
        longitude: point.longitude,
        accuracyM: accuracy,
      },
    });
    await tx.$executeRaw(Prisma.sql`
      UPDATE "courier_locations"
      SET "location" = ${pointSql(point.latitude, point.longitude)}::geography
      WHERE "id" = ${created.id}::uuid
    `);
    await tx.$executeRaw(Prisma.sql`
      UPDATE "users"
      SET "location" = ${pointSql(point.latitude, point.longitude)}::geography,
          "cityId" = ${city.cityId},
          "location_updated_at" = NOW(),
          "updatedAt" = NOW()
      WHERE "id" = ${user.id}::uuid
    `);
    return created;
  });
  return { location, city };
}

module.exports = {
  coordinates,
  normalizeGeoJson,
  recordCourierLocation,
  resolveCoveredCity,
  setCityBoundary,
  setCourierAvailability,
  updateCustomerAddressLocation,
  updateRestaurantLocation,
};
