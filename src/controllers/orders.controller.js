const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, pagination, pick, sendPage } = require('./controller.utils');

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

async function createOrder(req, res, next) {
  try {
    const payload = req.body.order || req.body;
    const lines = req.body.lines || req.body.orderLines || [];
    if (!payload.userId || !payload.restaurantId) {
      throw badRequest('userId et restaurantId sont obligatoires.');
    }
    if (!Array.isArray(lines) || lines.length === 0) {
      throw badRequest('Une commande doit contenir au moins une ligne.');
    }

    const order = await prisma.$transaction(async (tx) => {
      const orderId = await nextOrderId(tx);
      const externalOrderId = payload.externalOrderId || randomUUID();
      const created = await tx.order.create({
        data: {
          ...pick(payload, ORDER_FIELDS),
          orderId,
          externalOrderId,
          orderedAt: payload.orderedAt ? new Date(payload.orderedAt) : new Date(),
          status: payload.status || 'pending',
        },
      });

      await tx.orderLine.createMany({
        data: lines.map((line) => ({
          ...pick(line, ORDER_LINE_FIELDS),
          lineId: line.lineId || randomUUID(),
          orderId: String(orderId),
          externalOrderId,
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
    const updated = await prisma.order.update({
      where: { id: order.id },
      data: {
        status: req.body.status,
        orderStatus: req.body.orderStatus || req.body.status,
        deliveryStatus: req.body.deliveryStatus,
        delivererId: req.body.delivererId,
        delivererName: req.body.delivererName,
      },
    });
    return res.status(200).json({ data: updated });
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
