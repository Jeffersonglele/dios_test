const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, pagination, pick, sendPage } = require('./controller.utils');
const { startDispatchForOrder } = require('../services/delivery-dispatch.service');
const { quoteDelivery } = require('../services/delivery-pricing.service');

const ORDER_FIELDS = [
  'externalOrderId', 'userId', 'legacyUserId', 'restaurantId', 'legacyRestaurantId',
  'restaurateurId', 'legacyRestaurateurId', 'paymentMethodId', 'externalPaymentId',
  'deliveryFee', 'legacyDeliveryFee', 'reduction', 'globalReduction', 'orderedAt',
  'legacyOrderedAt', 'orderedTime', 'addressId', 'deliveryAddressId', 'rating',
  'comment', 'status', 'legacyStatus', 'orderStatus', 'currency', 'promoCode',
  'deliveryMode', 'subtotalAmount', 'totalAmount', 'delivererId', 'deliveryStatus',
  'country', 'isPro', 'delivererName', 'livraisonStatus', 'livraisonDate',
  'delivererLatitude', 'delivererLongitude', 'cityId', 'paymentProvider', 'tipAmount',
  'delivererBasePay', 'delivererDistancePay', 'delivererEarningsStatus',
];
const ORDER_LINE_FIELDS = [
  'lineId', 'legacyLineId', 'orderId', 'externalOrderId', 'dishId', 'legacyDishId',
  'quantity', 'unitPrice', 'legacyUnitPrice', 'reduction', 'rating', 'comment', 'options',
];

const orderCrud = createCrudController({
  delegate: 'order', resource: 'Commande', fields: ORDER_FIELDS,
  filterFields: ['status', 'country', 'deliveryMode', 'paymentProvider'],
});
const orderLineCrud = createCrudController({
  delegate: 'orderLine', resource: 'Ligne de commande', fields: ORDER_LINE_FIELDS,
});

async function nextOrderId(tx) {
  const last = await tx.order.findFirst({
    where: { orderId: { not: null } }, orderBy: { orderId: 'desc' }, select: { orderId: true },
  });
  return (last?.orderId || 0) + 1;
}

function hasRole(roleName, roleId) {
  const configured = String(process.env[`${roleName}_ROLE_IDS`] || '')
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
  return configured.includes(roleId);
}

async function createOrder(req, res, next) {
  try {
    const payload = req.body.order || req.body;
    const lines = req.body.lines || req.body.orderLines || [];
    const userId = req.auth?.userId;
    if (!userId || !payload.restaurantId) {
      throw badRequest('restaurantId est obligatoire pour le client authentifié.');
    }
    if (payload.userId !== undefined && Number(payload.userId) !== userId) {
      throw badRequest('Une commande ne peut être créée que pour le compte connecté.');
    }
    if (!Array.isArray(lines) || lines.length === 0) {
      throw badRequest('Une commande doit contenir au moins une ligne.');
    }

    const restaurantId = Number.parseInt(payload.restaurantId, 10);
    if (!Number.isInteger(restaurantId)) throw badRequest('restaurantId est invalide.');
    const restaurant = await prisma.restaurant.findFirst({ where: { restaurantId, deletedAt: null } });
    if (!restaurant) throw notFound('Restaurant');
    if (restaurant.isOpen === 0) throw badRequest('Ce marchand est actuellement fermé.');

    const requestedDishIds = lines.map((line) => Number.parseInt(line.dishId, 10));
    if (requestedDishIds.some((dishId) => !Number.isInteger(dishId))) {
      throw badRequest('Chaque ligne doit référencer un plat valide.');
    }
    const dishes = await prisma.dish.findMany({
      where: { dishId: { in: requestedDishIds }, restaurantId, deletedAt: null },
    });
    if (dishes.length !== new Set(requestedDishIds).size) {
      throw badRequest('Le panier contient un plat indisponible ou appartenant à un autre marchand.');
    }
    const dishById = new Map(dishes.map((dish) => [dish.dishId, dish]));
    const normalizedLines = lines.map((line) => {
      const dishId = Number.parseInt(line.dishId, 10);
      const quantity = Number.parseInt(line.quantity, 10);
      const dish = dishById.get(dishId);
      if (!Number.isInteger(quantity) || quantity < 1 || quantity > 99 || !dish || !Number.isFinite(Number(dish.price))) {
        throw badRequest('Chaque ligne doit contenir une quantité valide et un plat tarifé.');
      }
      return { line, dishId, quantity, unitPrice: Number(dish.price) };
    });
    const subtotalAmount = normalizedLines.reduce((total, line) => total + (line.unitPrice * line.quantity), 0);
    const deliveryMode = String(payload.deliveryMode || 'DELIVERY').toUpperCase();
    const isDelivery = ['DELIVERY', 'LIVRAISON'].includes(deliveryMode);
    let quote = null;
    let deliveryAddress = null;
    if (isDelivery) {
      const addressId = Number.parseInt(payload.deliveryAddressId || payload.addressId, 10);
      if (!Number.isInteger(addressId)) throw badRequest('Une adresse de livraison est obligatoire.');
      quote = await quoteDelivery({ restaurantId, addressId, userId });
      if (!quote.available) throw badRequest(quote.message);
      deliveryAddress = await prisma.address.findFirst({ where: { addressId, objectId: userId, deletedAt: null } });
    }
    const deliveryFee = quote?.deliveryFee || 0;
    const totalAmount = subtotalAmount + deliveryFee;
    const paymentMethod = String(payload.paymentMethod || payload.paymentProvider || 'CASH').trim().toUpperCase();
    if (!['CASH', 'CINETPAY'].includes(paymentMethod)) {
      throw badRequest('Le moyen de paiement doit être CASH ou CINETPAY. Le portefeuille reste désactivé.');
    }

    const order = await prisma.$transaction(async (tx) => {
      const orderId = await nextOrderId(tx);
      const externalOrderId = payload.externalOrderId || randomUUID();
      const created = await tx.order.create({
        data: {
          ...pick(payload, ORDER_FIELDS),
          orderId,
          externalOrderId,
          userId,
          restaurantId,
          deliveryMode: isDelivery ? 'DELIVERY' : 'PICKUP',
          deliveryFee,
          subtotalAmount,
          totalAmount,
          currency: 'CDF',
          paymentProvider: paymentMethod,
          cityId: quote?.cityId || restaurant.cityId,
          deliveryDistanceKm: quote?.estimatedDistanceKm || null,
          deliveryQuoteSnapshot: quote,
          deliveryAddressSnapshot: deliveryAddress ? {
            addressId: deliveryAddress.addressId,
            fullAddress: deliveryAddress.fullAddress,
            latitude: deliveryAddress.latitude,
            longitude: deliveryAddress.longitude,
            cityId: deliveryAddress.cityId,
          } : undefined,
          pickupSnapshot: isDelivery ? {
            restaurantId: restaurant.restaurantId,
            name: restaurant.name,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
            cityId: quote.cityId,
          } : undefined,
          orderedAt: payload.orderedAt ? new Date(payload.orderedAt) : new Date(),
          status: paymentMethod === 'CASH' ? 'CONFIRMED_CASH' : 'AWAITING_PAYMENT',
          orderStatus: paymentMethod === 'CASH' ? 'CONFIRMED_CASH' : 'AWAITING_PAYMENT',
        },
      });

      if (paymentMethod === 'CASH') {
        await tx.transaction.create({
          data: {
            transactionId: `CASH-${orderId}-${randomUUID().replace(/-/g, '')}`,
            orderId,
            provider: 'cash',
            amount: totalAmount,
            currency: 'CDF',
            status: 'PENDING_CASH_COLLECTION',
            paymentMethod: 'CASH',
            subtotalAmount,
            restaurantShare: subtotalAmount,
            deliveryFeeShare: deliveryFee,
            commissionRate: 0,
            commissionAmount: 0,
            settlementStatus: 'PENDING_DELIVERY',
          },
        });
      }

      await tx.orderLine.createMany({
        data: normalizedLines.map(({ line, dishId, quantity, unitPrice }) => ({
          ...pick(line, ORDER_LINE_FIELDS.filter((field) => !['unitPrice', 'legacyUnitPrice', 'quantity', 'dishId'].includes(field))),
          lineId: randomUUID(),
          orderId: String(orderId),
          externalOrderId,
          dishId,
          quantity,
          unitPrice,
        })),
      });
      return created;
    });

    const orderLines = await prisma.orderLine.findMany({ where: { orderId: String(order.orderId), deletedAt: null } });
    return res.status(201).json({ data: { order, lines: orderLines } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getOrderDetails(req, res, next) {
  try {
    const order = await prisma.order.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!order) throw notFound('Commande');
    const lines = await prisma.orderLine.findMany({ where: { orderId: String(order.orderId), deletedAt: null } });
    const transactions = await prisma.transaction.findMany({ where: { orderId: order.orderId, deletedAt: null } });
    return res.status(200).json({ data: { order, lines, transactions } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listOrders(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { deletedAt: null };
    for (const field of ['userId', 'restaurantId', 'restaurateurId', 'delivererId', 'cityId']) {
      if (req.query[field] !== undefined) where[field] = Number.parseInt(req.query[field], 10);
    }
    for (const field of ['status', 'deliveryStatus', 'deliveryMode', 'paymentProvider']) {
      if (req.query[field] !== undefined) where[field] = String(req.query[field]);
    }

    const [data, total] = await prisma.$transaction([
      prisma.order.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { orderedAt: 'desc' } }),
      prisma.order.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateOrderStatus(req, res, next) {
  try {
    const order = await prisma.order.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!order) throw notFound('Commande');
    if (!req.body.status) throw badRequest('Le statut est obligatoire.');
    const requestedStatus = String(req.body.status).toUpperCase();
    const isAdmin = hasRole('ADMIN', req.auth.roleId);
    const restaurant = await prisma.restaurant.findFirst({ where: { restaurantId: order.restaurantId, deletedAt: null } });
    const isRestaurantOwner = restaurant?.userId === req.auth.userId;
    const isCustomer = order.userId === req.auth.userId;
    const restaurantWorkflowStatuses = ['EN_PREPARATION', 'PRETE', 'READY', 'REFUSED'];
    const restaurantDispatchStatuses = ['PRETE', 'READY'];
    const customerCancellationStatuses = ['CANCELLED', 'CANCELED'];
    if (!isAdmin
      && !(isRestaurantOwner && restaurantWorkflowStatuses.includes(requestedStatus))
      && !(isCustomer && customerCancellationStatuses.includes(requestedStatus) && ['PENDING', 'WAITING_PAYMENT'].includes(String(order.status).toUpperCase()))) {
      throw badRequest('Vous ne pouvez pas appliquer ce statut à cette commande.');
    }
    const updated = await prisma.order.update({
      where: { id: order.id },
      data: {
        status: requestedStatus,
        orderStatus: req.body.orderStatus || requestedStatus,
        deliveryStatus: req.body.deliveryStatus,
        ...(isAdmin ? { delivererId: req.body.delivererId, delivererName: req.body.delivererName } : {}),
      },
    });
    let delivery = null;
    if (restaurantDispatchStatuses.includes(requestedStatus) && updated.deliveryMode === 'DELIVERY') {
      const dispatched = await startDispatchForOrder(updated);
      delivery = dispatched.delivery;
    }
    return res.status(200).json({ data: { order: updated, delivery } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  order: { ...orderCrud, create: createOrder, list: listOrders, getDetails: getOrderDetails, updateStatus: updateOrderStatus },
  orderLine: orderLineCrud,
  ORDER_FIELDS,
  ORDER_LINE_FIELDS,
};
