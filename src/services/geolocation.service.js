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
  const p = prisma ?? client;
  const exactMatches = await p.$queryRaw(Prisma.sql`
    SELECT "cityId", "name", "country", "country_code" AS "countryCode"
    FROM "cities"
    WHERE "deletedAt" IS NULL
      AND "active" = true
      AND "delivery_enabled" = true
      AND "boundary" IS NOT NULL
      AND ST_Covers("boundary", ${point})
    ORDER BY "updatedAt" DESC
    LIMIT 5
  `);
  if (exactMatches && exactMatches.length > 0) return exactMatches[0];

  const closest = await p.$queryRaw(Prisma.sql`
    SELECT "cityId", "name", "country", "country_code" AS "countryCode",
           ST_Distance("boundary"::geography, ${point}::geography) AS "distanceM"
    FROM "cities"
    WHERE "deletedAt" IS NULL
      AND "active" = true
      AND "delivery_enabled" = true
      AND "boundary" IS NOT NULL
    ORDER BY "distanceM" ASC
    LIMIT 1
  `);
  if (closest && closest.length > 0) {
    const candidate = closest[0];
    return {
      cityId: candidate.cityId,
      name: candidate.name,
      country: candidate.country,
      countryCode: candidate.countryCode,
    };
  }

  const defaultCity = await p.city.findFirst({
    where: { deletedAt: null, active: true },
    orderBy: { cityId: 'asc' },
  });
  if (defaultCity) {
    return {
      cityId: defaultCity.cityId,
      name: defaultCity.name,
      country: defaultCity.country,
      countryCode: defaultCity.countryCode,
    };
  }
  return null;
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

async function updateCustomerAddressLocation({ addressId, userId, latitude, longitude, fullAddress, nominatimPlaceId, country }) {
  const point = coordinates(latitude, longitude);
  const numericAddressId = Number.parseInt(addressId, 10);
  if (!Number.isInteger(numericAddressId)) throw badRequest('addressId est obligatoire.');
  const numericUserId = Number.isInteger(userId) ? userId : Number.parseInt(String(userId ?? ''), 10);

  const address = await prisma.address.findFirst({
    where: {
      addressId: numericAddressId,
      ...(Number.isInteger(numericUserId) ? { objectId: numericUserId } : {}),
      deletedAt: null,
    },
  });
  if (!address) throw notFound('Adresse cliente');

  const city = await resolveCoveredCity(point.latitude, point.longitude);
  if (!city) throw badRequest('Cette position ne se trouve dans aucune ville couverte.');

  const rawCountry = country ? String(country).trim() : null;
  const resolvedCountry = city.country
    || address.country
    || (rawCountry && rawCountry.length > 0 ? rawCountry : null)
    || 'RDC';

  await prisma.$transaction(async (tx) => {
    await tx.address.update({
      where: { id: address.id },
      data: {
        latitude: point.latitude,
        longitude: point.longitude,
        cityId: city.cityId,
        country: resolvedCountry,
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
  if (!city) throw badRequest('Le point de vente doit être situé dans une ville couverte.');

  await prisma.$transaction(async (tx) => {
    await tx.restaurant.update({
      where: { id: restaurant.id },
      data: {
        latitude: point.latitude,
        longitude: point.longitude,
        cityId: city.cityId,
        country: city.country || restaurant.country || address?.country || 'RDC',
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
  const raw = String(status ?? '').trim();
  const asBool = raw.toLowerCase();
  let normalizedStatus;
  if (raw === '' || asBool === 'false' || asBool === '0' ||
      raw.toUpperCase() === 'OFFLINE' || raw.toUpperCase() === 'INACTIVE' ||
      raw.toUpperCase() === 'UNAVAILABLE') {
    normalizedStatus = 'INACTIVE';
  } else if (asBool === 'true' || asBool === '1' ||
             raw.toUpperCase() === 'ONLINE' || raw.toUpperCase() === 'ACTIVE' ||
             raw.toUpperCase() === 'AVAILABLE') {
    normalizedStatus = 'ACTIVE';
  } else {
    throw badRequest('Le statut livreur doit être ACTIVE/INACTIVE, AVAILABLE/OFFLINE ou un booléen.');
  }
  const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
  if (!user) throw notFound('Livreur');
  if (normalizedStatus === 'ACTIVE' && !user.locationUpdatedAt) {
    // On rend ce warning non bloquant en prod pour que l'app ne plante pas,
    // mais on journalise la préoccupation.
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
