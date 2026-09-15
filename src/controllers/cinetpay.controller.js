const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const {
  cpmStatusIsFinalFailure,
  cpmStatusIsSuccessful,
  initiatePayment,
  isMockMode,
  verifyPayment,
  verifyWebhookSignature,
} = require('../services/cinetpay.service');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');

function paymentPayload(transaction) {
  const data = transaction.providerData || {};
  return {
    transactionId: transaction.transactionId,
    status: transaction.status,
    amount: transaction.amount,
    currency: transaction.currency,
    provider: transaction.provider,
    providerRef: transaction.providerRef,
    mode: data.mode || 'mock',
    paymentUrl: data.paymentUrl || null,
  };
}

async function findOwnedOrder(orderUuid, userId) {
  const order = await prisma.order.findFirst({ where: { id: orderUuid, userId, deletedAt: null } });
  if (!order) throw notFound('Commande');
  if (!order.orderId || !order.totalAmount || Number(order.totalAmount) <= 0) {
    throw badRequest('Cette commande ne possède pas un total payable valide.');
  }
  return order;
}

async function finalizeTransaction(transactionId) {
  const transaction = await prisma.transaction.findUnique({ where: { transactionId } });
  if (!transaction) throw notFound('Transaction');
  if (transaction.status === 'PAID') return { transaction, idempotent: true };

  const verification = await verifyPayment(transaction);
  const expectedAmount = Number(transaction.amount);
  const verifiedAmount = Number(verification.amount);
  const currencyMatches = !verification.currency
    || String(verification.currency).toUpperCase() === String(transaction.currency || 'CDF').toUpperCase();

  if (cpmStatusIsSuccessful(verification.status) && verifiedAmount === expectedAmount && currencyMatches) {
    const providerData = {
      ...(transaction.providerData || {}),
      verification: verification.raw,
      verifiedAt: new Date().toISOString(),
    };
    return prisma.$transaction(async (tx) => {
      const current = await tx.transaction.findUnique({ where: { transactionId } });
      if (current.status === 'PAID') return { transaction: current, idempotent: true };
      const paidTransaction = await tx.transaction.update({
        where: { id: current.id },
        data: {
          status: 'PAID',
          providerRef: verification.providerRef || current.providerRef,
          providerData,
          settlementStatus: 'PENDING_PAYOUT',
          settledAt: new Date(),
        },
      });
      if (current.providerData?.kind === 'TIP') {
        await tx.tip.updateMany({
          where: { transactionId: current.transactionId, status: 'PENDING' },
          data: { status: 'PAID', paidAt: new Date(), paymentMethod: 'CINETPAY' },
        });
      } else {
        await tx.order.updateMany({
          where: {
            orderId: current.orderId,
            deletedAt: null,
            status: { in: ['pending', 'PENDING', 'AWAITING_PAYMENT'] },
          },
          data: { status: 'PAYEE', orderStatus: 'PAYEE', paymentProvider: 'CINETPAY' },
        });
      }
      return { transaction: paidTransaction, idempotent: false };
    });
  }

  if (cpmStatusIsFinalFailure(verification.status)
    || (Number.isFinite(verifiedAmount) && verifiedAmount !== expectedAmount)
    || !currencyMatches) {
    const failed = await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        status: 'FAILED',
        providerData: {
          ...(transaction.providerData || {}),
          verification: verification.raw,
          verifiedAt: new Date().toISOString(),
        },
      },
    });
    return { transaction: failed, idempotent: false };
  }

  return { transaction, idempotent: false };
}

async function initialize(req, res, next) {
  try {
    const { orderId, channels = 'ALL' } = req.body;
    if (!orderId) throw badRequest('orderId est obligatoire.');
    const order = await findOwnedOrder(orderId, req.auth.userId);
    const existing = await prisma.transaction.findFirst({
      where: {
        orderId: order.orderId,
        provider: 'cinetpay',
        status: { in: ['PENDING', 'INITIATED'] },
        deletedAt: null,
      },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return res.status(200).json({ data: { ...paymentPayload(existing), reused: true } });

    const transactionId = `DD-${order.orderId}-${randomUUID().replace(/-/g, '')}`;
    const created = await prisma.transaction.create({
      data: {
        transactionId,
        orderId: order.orderId,
        provider: 'cinetpay',
        amount: order.totalAmount,
        currency: String(order.currency || 'CDF').toUpperCase(),
        status: 'INITIATED',
        paymentMethod: 'ONLINE',
        subtotalAmount: order.subtotalAmount,
        restaurantShare: order.subtotalAmount,
        deliveryFeeShare: order.deliveryFee,
        providerData: { mode: isMockMode() ? 'mock' : 'live', channels, kind: 'ORDER' },
      },
    });
    const user = await prisma.user.findFirst({ where: { userId: req.auth.userId, deletedAt: null } });
    let gateway;
    try {
      gateway = await initiatePayment({
        transactionId,
        amount: order.totalAmount,
        currency: order.currency || 'CDF',
        channels,
        customer: {
          name: [user?.firstname, user?.lastname].filter(Boolean).join(' '),
          email: user?.email,
          phone: user?.telephoneE164 || user?.telephone,
        },
      });
    } catch (error) {
      await prisma.transaction.update({
        where: { id: created.id },
        data: {
          status: 'FAILED',
          providerData: { ...(created.providerData || {}), initiationError: error.message },
        },
      });
      throw error;
    }
    const transaction = await prisma.transaction.update({
      where: { id: created.id },
      data: {
        status: gateway.status,
        providerRef: gateway.providerRef,
        providerData: { ...(created.providerData || {}), mode: gateway.mode, paymentUrl: gateway.paymentUrl },
      },
    });
    return res.status(201).json({ data: paymentPayload(transaction) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function initializeTip(req, res, next) {
  try {
    const { orderId, amount, channels = 'ALL' } = req.body;
    if (!orderId) throw badRequest('orderId est obligatoire.');
    const tipAmount = Math.round(Number(amount));
    const tipMax = Math.max(1, Number.parseInt(process.env.TIP_MAX_CDF, 10) || 50000);
    if (!Number.isInteger(tipAmount) || tipAmount <= 0 || tipAmount > tipMax) {
      throw badRequest(`Le pourboire doit être compris entre 1 et ${tipMax} CDF.`);
    }
    const order = await findOwnedOrder(orderId, req.auth.userId);
    const delivery = await prisma.delivery.findFirst({ where: { orderId: order.orderId, status: 'DELIVERED' } });
    if (!delivery?.delivererId) throw badRequest('Le pourboire est disponible après la livraison réussie.');

    const existingTip = await prisma.tip.findFirst({
      where: { orderId: order.orderId, customerId: req.auth.userId, status: { in: ['PENDING', 'PAID'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (existingTip?.status === 'PAID') throw badRequest('Un pourboire a déjà été payé pour cette livraison.');
    if (existingTip?.transactionId) {
      const transaction = await prisma.transaction.findUnique({ where: { transactionId: existingTip.transactionId } });
      if (transaction) return res.status(200).json({ data: { ...paymentPayload(transaction), tipId: existingTip.id, reused: true } });
    }

    const transactionId = `DD-TIP-${order.orderId}-${randomUUID().replace(/-/g, '')}`;
    const { tip, transaction: created } = await prisma.$transaction(async (tx) => {
      const createdTip = await tx.tip.create({
        data: {
          orderId: order.orderId,
          deliveryId: delivery.id,
          customerId: req.auth.userId,
          delivererId: delivery.delivererId,
          amount: tipAmount,
          currency: 'CDF',
          paymentMethod: 'CINETPAY',
          transactionId,
          status: 'PENDING',
        },
      });
      const createdTransaction = await tx.transaction.create({
        data: {
          transactionId,
          orderId: order.orderId,
          provider: 'cinetpay',
          amount: tipAmount,
          currency: 'CDF',
          status: 'INITIATED',
          paymentMethod: 'TIP',
          settlementStatus: 'PENDING_PAYOUT',
          providerData: { mode: isMockMode() ? 'mock' : 'live', channels, kind: 'TIP', tipId: createdTip.id },
        },
      });
      return { tip: createdTip, transaction: createdTransaction };
    });
    const user = await prisma.user.findFirst({ where: { userId: req.auth.userId, deletedAt: null } });
    let gateway;
    try {
      gateway = await initiatePayment({
        transactionId,
        amount: tipAmount,
        currency: 'CDF',
        channels,
        customer: {
          name: [user?.firstname, user?.lastname].filter(Boolean).join(' '),
          email: user?.email,
          phone: user?.telephoneE164 || user?.telephone,
        },
      });
    } catch (error) {
      await prisma.transaction.update({
        where: { id: created.id },
        data: { status: 'FAILED', providerData: { ...(created.providerData || {}), initiationError: error.message } },
      });
      await prisma.tip.update({ where: { id: tip.id }, data: { status: 'FAILED' } });
      throw error;
    }
    const transaction = await prisma.transaction.update({
      where: { id: created.id },
      data: {
        status: gateway.status,
        providerRef: gateway.providerRef,
        providerData: { ...(created.providerData || {}), mode: gateway.mode, paymentUrl: gateway.paymentUrl },
      },
    });
    return res.status(201).json({ data: { ...paymentPayload(transaction), tipId: tip.id } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getPayment(req, res, next) {
  try {
    const transaction = await prisma.transaction.findUnique({ where: { transactionId: req.params.transactionId } });
    if (!transaction) throw notFound('Transaction');
    const order = await prisma.order.findFirst({
      where: { orderId: transaction.orderId, userId: req.auth.userId, deletedAt: null },
    });
    if (!order) throw notFound('Transaction');
    return res.status(200).json({ data: paymentPayload(transaction) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function webhook(req, res, next) {
  try {
    const receivedToken = req.get('x-token');
    if (!verifyWebhookSignature(req.body, receivedToken)) {
      const error = new Error('Signature CinetPay invalide.');
      error.statusCode = 401;
      throw error;
    }
    const transactionId = req.body.cpm_trans_id || req.body.cpm_custom;
    if (!transactionId) throw badRequest('Référence de transaction CinetPay absente.');
    const result = await finalizeTransaction(String(transactionId));
    return res.status(200).json({
      data: { transactionId, status: result.transaction.status, idempotent: result.idempotent },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function mockConfirm(req, res, next) {
  try {
    if (!isMockMode()) {
      const error = new Error('La confirmation simulée est désactivée hors mode mock.');
      error.statusCode = 404;
      throw error;
    }
    const transaction = await prisma.transaction.findUnique({ where: { transactionId: req.params.transactionId } });
    if (!transaction) throw notFound('Transaction');
    const order = await prisma.order.findFirst({
      where: { orderId: transaction.orderId, userId: req.auth.userId, deletedAt: null },
    });
    if (!order) throw notFound('Transaction');
    await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        providerData: {
          ...(transaction.providerData || {}),
          mockStatus: req.body.success === false ? 'REFUSED' : 'ACCEPTED',
        },
      },
    });
    const result = await finalizeTransaction(transaction.transactionId);
    return res.status(200).json({ data: { ...paymentPayload(result.transaction), idempotent: result.idempotent } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

function paymentReturn(req, res) {
  return res.status(200).type('html').send('<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Paiement Dios Delices</title></head><body><main><h1>Paiement en cours de vérification</h1><p>Vous pouvez revenir dans Dios Delices. La commande ne sera confirmée qu’après vérification côté serveur.</p></main></body></html>');
}

module.exports = { getPayment, initialize, initializeTip, mockConfirm, paymentReturn, webhook };
