const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, pagination, sendPage } = require('./controller.utils');

const RESTAURANT_FIELDS = [
  'restaurantId', 'userId', 'categories', 'description', 'address', 'addressId',
  'name', 'rating', 'image', 'dateCreation', 'valid', 'orderCount', 'openingHours',
  'deliveryFee', 'isOpen', 'professionalType', 'trainingCompleted', 'reviewRemark',
  'currency', 'openingDays', 'minOrderAmount', 'deliveryRadius', 'closedDates',
  'recoveryMode', 'country', 'isPro', 'cityId', 'rccm', 'paymentMethod',
  'mobileMoneyPhone', 'iban', 'bankName', 'accountHolder',
];

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

    const pageInfo = pagination(req.query);
    const where = { restaurantId, deletedAt: null };
    const [dishesList, total] = await prisma.$transaction([
      prisma.dish.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.dish.count({ where }),
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

module.exports = {
  restaurant: { ...restaurants, list: listRestaurants, getMenu: getRestaurantMenu, setAvailability: setRestaurantAvailability },
  dish: { ...dishes, list: listDishes },
  category: categories,
  gallery,
  DISH_FIELDS,
  RESTAURANT_FIELDS,
};
