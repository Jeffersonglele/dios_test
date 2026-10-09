const { Prisma } = require('@prisma/client');
const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, pagination, sendPage, canonicalCountry } = require('./controller.utils');
const { resolveCoveredCity } = require('../services/geolocation.service');

function configuredAdminRoleIds() {
  return String(process.env.ADMIN_ROLE_IDS || '')
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
}

function isAdminUser(req) {
  const roleId = req?.auth?.roleId;
  if (roleId === undefined || roleId === null) return false;
  return configuredAdminRoleIds().includes(Number(roleId));
}

const RESTAURANT_FIELDS = [
  'restaurantId', 'userId', 'categories', 'description', 'address', 'addressId',
  'name', 'rating', 'image', 'dateCreation', 'valid', 'orderCount', 'openingHours',
  'deliveryFee', 'isOpen', 'professionalType', 'trainingCompleted', 'reviewRemark',
  'currency', 'openingDays', 'minOrderAmount', 'deliveryRadius', 'closedDates',
  'recoveryMode', 'country', 'isPro', 'cityId', 'rccm', 'paymentMethod',
  'mobileMoneyPhone', 'iban', 'bankName', 'accountHolder',
  'latitude', 'longitude',
];

/**
 * Si latitude + longitude sont valides, résout la ville couverte (cityId) et
 * met à jour la colonne PostGIS `restaurants.location` via $executeRaw.
 * Retourne les champs enrichis { cityId, country } ou {} si pas de coordonnées.
 */
async function _syncRestaurantLocation(restaurantUuid, lat, lng, currentCountry) {
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return {};

  const city = await resolveCoveredCity(latitude, longitude);
  const extra = {};
  if (city) {
    extra.cityId = city.cityId;
    extra.country = city.country || currentCountry || 'RDC';
  }
  extra.locationUpdatedAt = new Date();

  // Mettre à jour les champs relationnels via Prisma
  await prisma.restaurant.update({
    where: { id: restaurantUuid },
    data: extra,
  });

  // Mettre à jour la colonne PostGIS (Unsupported par Prisma, donc $executeRaw)
  await prisma.$executeRaw(Prisma.sql`
    UPDATE "restaurants"
    SET "location" = ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
    WHERE "id" = ${restaurantUuid}::uuid
  `);

  return extra;
}

const DISH_FIELDS = [
  'dishId', 'userId', 'restaurantId', 'name', 'categories', 'image', 'images',
  'orderCount', 'price', 'description', 'servings', 'status', 'rating', 'option1',
  'option2', 'option3', 'currency', 'country', 'cityId',
];

const CATEGORY_FIELDS = ['categoryId', 'name', 'image'];
const GALLERY_FIELDS = ['fileUrl', 'name'];

const restaurants = createCrudController({
  delegate: 'restaurant', resource: 'Restaurant', fields: RESTAURANT_FIELDS,
  filterFields: ['country', 'professionalType', 'recoveryMode', 'paymentMethod'],
});
const dishes = createCrudController({
  delegate: 'dish', resource: 'Plat', fields: DISH_FIELDS,
  filterFields: ['country', 'currency'],
});
const categories = createCrudController({
  delegate: 'category', resource: 'Catégorie', fields: CATEGORY_FIELDS,
  filterFields: ['name'],
});
const gallery = createCrudController({
  delegate: 'gallery', resource: 'Fichier média', fields: GALLERY_FIELDS,
});

async function getRestaurantMenu(req, res, next) {
  try {
    const restaurantId = Number.parseInt(req.params.restaurantId, 10);
    if (!Number.isInteger(restaurantId)) throw badRequest('restaurantId doit être un entier.');

    const restaurant = await prisma.restaurant.findFirst({
      where: { restaurantId, deletedAt: null },
    });
    if (!restaurant) throw notFound('Restaurant');

    const authUserId = req.auth?.userId !== undefined ? Number(req.auth.userId) : null;
    const isOwner = authUserId !== null
      && restaurant.userId !== undefined
      && restaurant.userId !== null
      && Number(restaurant.userId) === authUserId;
    const isAdmin = isAdminUser(req);

    if (!isOwner && !isAdmin && Number(restaurant.valid) !== 1) throw notFound('Restaurant');

    const pageInfo = pagination(req.query);
    const dishesWhere = { restaurantId, deletedAt: null };
    const [dishesList, total] = await prisma.$transaction([
      prisma.dish.findMany({ where: dishesWhere, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.dish.count({ where: dishesWhere }),
    ]);
    return res.status(200).json({
      data: { restaurant, dishes: dishesList },
      meta: { page: pageInfo.page, pageSize: pageInfo.pageSize, total, totalPages: Math.ceil(total / pageInfo.pageSize) },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listRestaurants(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { deletedAt: null };
    // Par défaut, seuls les restaurants validés par un admin sont affichés.
    // Les admins peuvent passer ?showAll=true pour voir les non-validés.
    if (req.query.showAll !== 'true') {
      where.valid = 1;
    }
    const countryRaw = req.query.country;
    if (countryRaw !== undefined && countryRaw !== '') {
      const country = canonicalCountry(countryRaw);
      if (country) where.country = country;
    }
    if (req.query.cityId) where.cityId = Number.parseInt(req.query.cityId, 10);
    if (req.query.userId) where.userId = Number.parseInt(req.query.userId, 10);
    if (req.query.isOpen !== undefined) where.isOpen = req.query.isOpen === 'true' ? 1 : 0;
    if (req.query.q) where.name = { contains: String(req.query.q), mode: 'insensitive' };

    const [data, total] = await prisma.$transaction([
      prisma.restaurant.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { name: 'asc' } }),
      prisma.restaurant.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listDishes(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { deletedAt: null };
    const countryRaw = req.query.country;
    if (countryRaw !== undefined && countryRaw !== '') {
      const country = canonicalCountry(countryRaw);
      if (country) where.country = country;
    }
    for (const field of ['restaurantId', 'userId', 'cityId', 'status']) {
      if (req.query[field] !== undefined) where[field] = Number.parseInt(req.query[field], 10);
    }
    if (req.query.q) where.name = { contains: String(req.query.q), mode: 'insensitive' };

    const [data, total] = await prisma.$transaction([
      prisma.dish.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.dish.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setRestaurantAvailability(req, res, next) {
  try {
    const isOpen = req.body.isOpen;
    if (![0, 1, true, false].includes(isOpen)) throw badRequest('isOpen doit être un booléen.');
    const restaurant = await prisma.restaurant.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!restaurant) throw notFound('Restaurant');
    const updated = await prisma.restaurant.update({
      where: { id: restaurant.id }, data: { isOpen: isOpen === true ? 1 : isOpen === false ? 0 : isOpen },
    });
    return res.status(200).json({ data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function manageRestaurantLegacy(req, res, next) {
  try {
    const { restaurantID, restaurantId } = req.body;
    const legacyIdRaw = req.params.restaurantId ? Number.parseInt(req.params.restaurantId, 10) : (Number(restaurantID) || Number(restaurantId));
    const raw = req.body;
    const data = {};
    const fieldMap = {
      userID: 'userId', userId: 'userId',
      categories: 'categories', description: 'description',
      adress: 'address', address: 'address', location: 'address',
      name: 'name', note: 'rating', rating: 'rating',
      nb_orders: 'orderCount', orderCount: 'orderCount',
      image: 'image', valid: 'valid', openingHours: 'openingHours',
      deliveryFee: 'deliveryFee', isOpen: 'isOpen',
      professionalType: 'professionalType', trainingCompleted: 'trainingCompleted',
      isPro: 'isPro', currency: 'currency', country: 'country',
      openingDays: 'openingDays', minOrderAmount: 'minOrderAmount',
      deliveryRadius: 'deliveryRadius', closedDates: 'closedDates',
      recoveryMode: 'recoveryMode', cityID: 'cityId', cityId: 'cityId',
      paymentMethod: 'paymentMethod', mobileMoneyPhone: 'mobileMoneyPhone',
      iban: 'iban', bankName: 'bankName', accountHolder: 'accountHolder',
      rccm: 'rccm', addressID: 'addressId', addressId: 'addressId',
      latitude: 'latitude', longitude: 'longitude',
    };
    for (const [k, target] of Object.entries(fieldMap)) {
      if (raw[k] !== undefined) data[target] = raw[k];
    }
    if (raw.date_creation && !data.dateCreation) {
      const dc = raw.date_creation;
      if (typeof dc === 'object' && dc.iso) data.dateCreation = new Date(dc.iso);
      else if (typeof dc === 'string' || typeof dc === 'number') data.dateCreation = new Date(dc);
    }
    if (raw.dateCreation && !data.dateCreation) data.dateCreation = new Date(raw.dateCreation);
    if (raw.country) data.country = canonicalCountry(raw.country);
    let record;
    let mode = 'created';
    const legacyId = Number.isInteger(legacyIdRaw) ? legacyIdRaw : null;

    if (data.latitude != null) data.latitude = Number.parseFloat(String(data.latitude));
    if (data.longitude != null) data.longitude = Number.parseFloat(String(data.longitude));
    if (!Number.isFinite(data.latitude)) data.latitude = null;
    if (!Number.isFinite(data.longitude)) data.longitude = null;

    // Fallback 1 : si une adresse est liée (addressID/addressId) mais pas de coords directes,
    // on charge les coordonnées depuis la table "addresses" (objectType=RESTAURANT).
    if ((data.latitude == null || data.longitude == null) && (data.addressId != null)) {
      try {
        const addrNum = Number.parseInt(String(data.addressId), 10);
        if (Number.isInteger(addrNum)) {
          const linked = await prisma.address.findFirst({
            where: {
              OR: [
                { addressId: addrNum, objectType: 'RESTAURANT' },
                { addressId: addrNum },
              ],
              deletedAt: null,
            },
            orderBy: { updatedAt: 'desc' },
          });
          const linkedLat = linked?.latitude != null ? Number(linked.latitude) : null;
          const linkedLng = linked?.longitude != null ? Number(linked.longitude) : null;
          if (Number.isFinite(linkedLat) && Number.isFinite(linkedLng)) {
            if (data.latitude == null) data.latitude = linkedLat;
            if (data.longitude == null) data.longitude = linkedLng;
            if (data.cityId == null && Number.isInteger(Number(linked.cityId))) {
              data.cityId = Number(linked.cityId);
            }
            if (!data.country && linked.country) data.country = linked.country;
          }
        }
      } catch (_) {}
    }

    // Fallback 2 : Géocodage automatique de l'adresse littérale si les coordonnées GPS sont absentes
    if ((data.latitude == null || data.longitude == null) && data.address && String(data.address).trim().length >= 3) {
      try {
        const { searchAddress } = require('../services/nominatim.service');
        const geoRes = await searchAddress(data.address, { limit: 1 });
        if (geoRes?.results?.length > 0) {
          const first = geoRes.results[0];
          if (Number.isFinite(first.latitude) && Number.isFinite(first.longitude)) {
            data.latitude = first.latitude;
            data.longitude = first.longitude;
          }
        }
      } catch (_) {}
    }

    if (legacyId) {
      const existing = await prisma.restaurant.findFirst({ where: { restaurantId: legacyId, deletedAt: null } });
      if (existing) {
        record = await prisma.restaurant.update({ where: { id: existing.id }, data });
        mode = 'updated';
      } else if (raw.userID || raw.userId) {
          data.restaurantId = legacyId;
          if (!data.dateCreation) data.dateCreation = new Date();
          if (!data.valid) data.valid = 0;
          if (data.isOpen === undefined) data.isOpen = 1;
          record = await prisma.restaurant.create({ data });
      } else {
        throw badRequest('Impossible de créer un restaurant sans userId.');
      }
    } else {
      if (!(raw.userID || raw.userId)) throw badRequest('userId est requis.');
      if (!data.dateCreation) data.dateCreation = new Date();
      if (!data.valid) data.valid = 0;
      if (data.isOpen === undefined) data.isOpen = 1;
      record = await prisma.restaurant.create({ data });
    }

    // Synchroniser la position PostGIS et la ville couverte
    if (data.latitude != null && data.longitude != null) {
      await _syncRestaurantLocation(record.id, data.latitude, data.longitude, data.country);
      record = await prisma.restaurant.findUnique({ where: { id: record.id } });
    }

    return res.status(200).json({ data: record, meta: { mode } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getRestaurantById(req, res, next) {
  try {
    const where = { id: req.params.id, deletedAt: null };
    const restaurant = await prisma.restaurant.findFirst({ where });
    if (!restaurant) throw notFound('Restaurant');

    const authUserId = req.auth?.userId !== undefined ? Number(req.auth.userId) : null;
    const isOwner = authUserId !== null
      && restaurant.userId !== undefined
      && restaurant.userId !== null
      && Number(restaurant.userId) === authUserId;
    const isAdmin = isAdminUser(req);

    if (!isOwner && !isAdmin && Number(restaurant.valid) !== 1) throw notFound('Restaurant');
    return res.status(200).json({ data: restaurant });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function createRestaurant(req, res, next) {
  try {
    const data = { ...pick(req.body, RESTAURANT_FIELDS) };
    if (data.valid === undefined || data.valid === null) data.valid = 0;
    let record = await prisma.restaurant.create({ data });

    // Synchroniser la position PostGIS et la ville couverte
    if (data.latitude != null && data.longitude != null) {
      await _syncRestaurantLocation(record.id, data.latitude, data.longitude, data.country);
      record = await prisma.restaurant.findUnique({ where: { id: record.id } });
    }

    return res.status(201).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getRestaurantByLegacy(req, res, next) {
  try {
    const legacyId = Number.parseInt(req.params.restaurantId, 10);
    if (!Number.isInteger(legacyId)) throw badRequest('restaurantId doit être un entier.');
    const restaurant = await prisma.restaurant.findFirst({ where: { restaurantId: legacyId, deletedAt: null } });
    if (!restaurant) throw notFound('Restaurant');

    const authUserId = req.auth?.userId !== undefined ? Number(req.auth.userId) : null;
    const isOwner = authUserId !== null
      && restaurant.userId !== undefined
      && restaurant.userId !== null
      && Number(restaurant.userId) === authUserId;
    const isAdmin = isAdminUser(req);

    if (!isOwner && !isAdmin && Number(restaurant.valid) !== 1) throw notFound('Restaurant');
    return res.status(200).json({ data: restaurant });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function deleteRestaurantByLegacy(req, res, next) {
  try {
    const legacyId = Number.parseInt(req.params.restaurantId, 10);
    if (!Number.isInteger(legacyId)) throw badRequest('restaurantId doit être un entier.');
    const restaurant = await prisma.restaurant.findFirst({ where: { restaurantId: legacyId, deletedAt: null } });
    if (!restaurant) throw notFound('Restaurant');
    const deleted = await prisma.restaurant.update({
      where: { id: restaurant.id }, data: { deletedAt: new Date() },
    });
    return res.status(200).json({ data: deleted });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  restaurant: {
    ...restaurants,
    list: listRestaurants,
    getById: getRestaurantById,
    create: createRestaurant,
    getMenu: getRestaurantMenu,
    setAvailability: setRestaurantAvailability,
    manageLegacy: manageRestaurantLegacy,
    getByLegacy: getRestaurantByLegacy,
    deleteByLegacy: deleteRestaurantByLegacy,
  },
  dish: { ...dishes, list: listDishes },
  category: categories,
  gallery,
  DISH_FIELDS,
  RESTAURANT_FIELDS,
};
