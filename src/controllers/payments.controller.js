const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const { evaluatePromo } = require('../services/promo.service');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, isValidUUID, notFound, pick } = require('./controller.utils');

const PAYMENT_METHOD_FIELDS = [
  'paymentMethodId', 'externalId', 'name', 'label', 'userId', 'stripePaymentId',
  'brand', 'last4', 'expirationMonth', 'expirationYear', 'type', 'isDefault',
];
const TRANSACTION_FIELDS = [
  'transactionId', 'orderId', 'provider', 'amount', 'currency', 'status', 'providerRef',
  'operator', 'phone', 'paymentMethod', 'providerData', 'settlementStatus', 'commissionRate',
  'subtotalAmount', 'commissionAmount', 'restaurantShare', 'deliveryFeeShare', 'settledAt',
];
const PROMO_FIELDS = [
  'code', 'description', 'discountPercent', 'discountFixed', 'minOrder', 'validFrom',
  'validUntil', 'active', 'maxUses', 'usedCount',
];

const paymentMethod = createCrudController({
  delegate: 'paymentMethod', resource: 'Moyen de paiement', fields: PAYMENT_METHOD_FIELDS,
  filterFields: ['userId', 'type'],
});
const transaction = createCrudController({
  delegate: 'transaction', resource: 'Transaction', fields: TRANSACTION_FIELDS,
  filterFields: ['provider', 'status', 'settlementStatus'],
});
const promoCode = createCrudController({
  delegate: 'promoCode', resource: 'Code promo', fields: PROMO_FIELDS,
  filterFields: ['code', 'active'],
});

async function createTransaction(req, res, next) {
  try {
    const data = pick(req.body, TRANSACTION_FIELDS);
    if (!data.orderId || !data.provider || data.amount === undefined) {
      throw badRequest('orderId, provider et amount sont obligatoires.');
    }
    const created = await prisma.transaction.create({
      data: { ...data, transactionId: data.transactionId || randomUUID(), status: data.status || 'pending' },
    });
    return res.status(201).json({ data: created });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateTransactionStatus(req, res, next) {
  try {
    const record = await prisma.transaction.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!record) throw notFound('Transaction');
    if (!req.body.status) throw badRequest('Le statut est obligatoire.');
    const updated = await prisma.transaction.update({
      where: { id: record.id },
      data: { status: req.body.status, providerRef: req.body.providerRef, providerData: req.body.providerData },
    });
    return res.status(200).json({ data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function confirmCashCollection(req, res, next) {
  try {
    const rawParam = String(req.params.id || '').trim();
    const parsedOrderId = Number.parseInt(rawParam, 10);
    const orderConditions = [
      ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
      ...(isValidUUID(rawParam) ? [{ id: rawParam }] : []),
    ];
    if (orderConditions.length === 0) throw notFound('Commande');

    const order = await prisma.order.findFirst({
      where: {
        OR: orderConditions,
        deletedAt: null,
      },
    });
    if (!order) throw notFound('Commande');
    if (String(order.paymentProvider || '').toUpperCase() !== 'CASH') {
      throw badRequest('Cette commande n’est pas réglée en espèces.');
    }
    const delivery = await prisma.delivery.findFirst({ where: { orderId: order.orderId, delivererId: req.auth.userId } });
    if (!delivery || delivery.status !== 'DELIVERED') {
      throw badRequest('Seul le livreur assigné peut confirmer les espèces après la livraison.');
    }
    const transaction = await prisma.transaction.findFirst({
      where: { orderId: order.orderId, provider: 'cash', paymentMethod: 'CASH', deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!transaction) throw notFound('Encaissement espèces');
    if (transaction.status === 'PAID') return res.status(200).json({ data: transaction, meta: { idempotent: true } });

    const collectedAmount = req.body.collectedAmount === undefined ? Number(transaction.amount) : Number(req.body.collectedAmount);
    if (!Number.isFinite(collectedAmount) || collectedAmount !== Number(transaction.amount)) {
      throw badRequest('Le montant encaissé doit correspondre exactement au total de la commande.');
    }
    const updated = await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        status: 'PAID',
        settledAt: new Date(),
        settlementStatus: 'PENDING_PAYOUT',
        providerData: { ...(transaction.providerData || {}), collectedBy: req.auth.userId, collectedAt: new Date().toISOString() },
      },
    });
    return res.status(200).json({ data: updated, meta: { idempotent: false } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Vérifie un code depuis le panier. Sous-total = plats (hors livraison),
/// comme lors de la création de la commande.
async function validatePromoCode(req, res, next) {
  try {
    const subtotal = req.body.subtotal ?? req.body.orderAmount;
    const { promo, discount } = await evaluatePromo(prisma, {
      code: req.body.code,
      subtotal,
      userId: req.auth?.userId,
    });
    return res.status(200).json({
      success: true,
      data: {
        code: promo.code,
        description: promo.description || null,
        discountPercent: promo.discountPercent || null,
        discountFixed: Number(promo.discountFixed) || 0,
        minOrder: promo.minOrder !== null ? Number(promo.minOrder) : null,
        discountAmount: discount,
        discount,
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  paymentMethod,
  transaction: { ...transaction, create: createTransaction, updateStatus: updateTransactionStatus },
  confirmCashCollection,
  promoCode: { ...promoCode, validate: validatePromoCode },
};
