const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const {
  confirmSandbox,
  initiatePayment,
  isFinalFailure,
  isSuccessful,
  verifyPayment,
  verifyWebhookSignature,
} = require('../services/nyole.service');
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
    mode: data.mode || 'test',
    paymentUrl: data.paymentUrl || null,
    providerOrderId: data.providerOrderId || null,
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

async function findTransaction(externalId) {
  return prisma.transaction.findFirst({
    where: { OR: [{ transactionId: externalId }, { providerRef: externalId }], deletedAt: null },
  });
}

async function finalizeTransaction(externalId) {
  const transaction = await findTransaction(externalId);
  if (!transaction) throw notFound('Transaction');
  if (['PAID', 'FAILED', 'CANCELLED'].includes(String(transaction.status).toUpperCase())) {
    return { transaction, idempotent: true };
  }

  const verification = await verifyPayment(transaction);
  const expectedAmount = Number(transaction.amount);
  const verifiedAmount = Number(verification.amount);
  const currencyMatches = String(verification.currency || transaction.currency || 'CDF').toUpperCase()
    === String(transaction.currency || 'CDF').toUpperCase();

  if (isSuccessful(verification.status) && verifiedAmount === expectedAmount && currencyMatches) {
    const providerData = {
      ...(transaction.providerData || {}),
      verification: verification.raw,
      verifiedAt: new Date().toISOString(),
    };
    return prisma.$transaction(async (tx) => {
      const current = await tx.transaction.findUnique({ where: { id: transaction.id } });
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
          data: { status: 'PAID', paidAt: new Date(), paymentMethod: 'NYOLE' },
        });
      } else {
        await tx.order.updateMany({
          where: {
            orderId: current.orderId,
            deletedAt: null,
            status: { in: ['pending', 'PENDING', 'AWAITING_PAYMENT', 'WAITING_PAYMENT'] },
          },
          data: { status: 'PAYEE', orderStatus: 'PAYEE', paymentProvider: 'NYOLE' },
        });
      }
      return { transaction: paidTransaction, idempotent: false };
    });
  }

  if (isFinalFailure(verification.status)
    || (Number.isFinite(verifiedAmount) && verifiedAmount !== expectedAmount)
    || !currencyMatches) {
    const failed = await prisma.transaction.update({
      where: { id: transaction.id },
      data: {
        status: verification.status === 'CANCELLED' ? 'CANCELLED' : 'FAILED',
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

async function createCheckout(req, res, next, kind = 'ORDER') {
  try {
    const { orderId } = req.body;
    if (!orderId) throw badRequest('orderId est obligatoire.');
    const order = await findOwnedOrder(orderId, req.auth.userId);
    const existing = await prisma.transaction.findFirst({
      where: {
        orderId: order.orderId,
        provider: 'nyole',
        status: { in: ['PENDING', 'INITIATED'] },
        deletedAt: null,
        providerData: { path: ['kind'], equals: kind },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return res.status(200).json({ data: { ...paymentPayload(existing), reused: true } });

    const transactionId = `DD-NYOLE-${order.orderId}-${randomUUID().replace(/-/g, '')}`;
    const created = await prisma.transaction.create({
      data: {
        transactionId,
        orderId: order.orderId,
        provider: 'nyole',
        amount: kind === 'TIP' ? 0 : order.totalAmount,
        currency: String(order.currency || 'CDF').toUpperCase(),
        status: 'INITIATED',
        paymentMethod: 'NYOLE',
        subtotalAmount: order.subtotalAmount,
        restaurantShare: order.subtotalAmount,
        deliveryFeeShare: order.deliveryFee,
        providerData: { mode: process.env.NYOLE_MODE === 'live' ? 'live' : 'test', kind },
      },
    });
    const user = await prisma.user.findFirst({ where: { userId: req.auth.userId, deletedAt: null } });
    let gateway;
    try {
      gateway = await initiatePayment({
        transactionId,
        amount: created.amount,
        currency: created.currency,
        customer: {
          name: [user?.firstname, user?.lastname].filter(Boolean).join(' '),
          email: user?.email,
          phone: user?.telephoneE164 || user?.telephone,
        },
        metadata: { order_id: String(order.orderId), kind },
      });
    } catch (error) {
      await prisma.transaction.update({
        where: { id: created.id },
        data: { status: 'FAILED', providerData: { ...(created.providerData || {}), initiationError: error.message } },
      });
      throw error;
    }
    const transaction = await prisma.transaction.update({
      where: { id: created.id },
      data: {
        status: gateway.status,
        providerRef: gateway.providerRef,
        providerData: {
          ...(created.providerData || {}),
          mode: gateway.mode,
          livemode: gateway.livemode,
          paymentUrl: gateway.paymentUrl,
          providerOrderId: gateway.providerOrderId,
          session: gateway.raw,
        },
      },
    });
    return res.status(201).json({ data: paymentPayload(transaction) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function initialize(req, res, next) {
  return createCheckout(req, res, next);
}

async function initializeTip(req, res, next) {
  try {
    const amount = Number(req.body.amount);
    const tipMax = Math.max(1, Number.parseInt(process.env.TIP_MAX_CDF, 10) || 50000);
    if (!Number.isInteger(amount) || amount <= 0 || amount > tipMax) {
      throw badRequest(`Le pourboire doit être compris entre 1 et ${tipMax} CDF.`);
    }
    // The shared checkout helper uses the order total; tips are created below
    // separately so their exact amount remains auditable.
    const order = await findOwnedOrder(req.body.orderId, req.auth.userId);
    const delivery = await prisma.delivery.findFirst({ where: { orderId: order.orderId, status: 'DELIVERED' } });
    if (!delivery?.delivererId) throw badRequest('Le pourboire est disponible après la livraison réussie.');
    const existingTip = await prisma.tip.findFirst({
      where: { orderId: order.orderId, customerId: req.auth.userId, status: { in: ['PENDING', 'PAID'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (existingTip?.status === 'PAID') throw badRequest('Un pourboire a déjà été payé pour cette livraison.');
    if (existingTip?.transactionId) {
      const existingTransaction = await prisma.transaction.findUnique({ where: { transactionId: existingTip.transactionId } });
      if (existingTransaction) return res.status(200).json({ data: { ...paymentPayload(existingTransaction), tipId: existingTip.id, reused: true } });
    }

    const transactionId = `DD-NYOLE-TIP-${order.orderId}-${randomUUID().replace(/-/g, '')}`;
    const { tip, created } = await prisma.$transaction(async (tx) => {
      const tip = await tx.tip.create({
        data: {
          orderId: order.orderId,
          deliveryId: delivery.id,
          customerId: req.auth.userId,
          delivererId: delivery.delivererId,
          amount,
          currency: 'CDF',
          paymentMethod: 'NYOLE',
          transactionId,
          status: 'PENDING',
        },
      });
      const created = await tx.transaction.create({
        data: {
          transactionId,
          orderId: order.orderId,
          provider: 'nyole',
          amount,
          currency: 'CDF',
          status: 'INITIATED',
          paymentMethod: 'NYOLE',
          settlementStatus: 'PENDING_PAYOUT',
          providerData: { mode: process.env.NYOLE_MODE === 'live' ? 'live' : 'test', kind: 'TIP', tipId: tip.id },
        },
      });
      return { tip, created };
    });
    const user = await prisma.user.findFirst({ where: { userId: req.auth.userId, deletedAt: null } });
    let gateway;
    try {
      gateway = await initiatePayment({
        transactionId,
        amount,
        currency: 'CDF',
        customer: { name: [user?.firstname, user?.lastname].filter(Boolean).join(' '), email: user?.email, phone: user?.telephoneE164 || user?.telephone },
        metadata: { order_id: String(order.orderId), kind: 'TIP', tip_id: tip.id },
      });
    } catch (error) {
      await prisma.transaction.update({ where: { id: created.id }, data: { status: 'FAILED', providerData: { ...(created.providerData || {}), initiationError: error.message } } });
      await prisma.tip.update({ where: { id: tip.id }, data: { status: 'FAILED' } });
      throw error;
    }
    const transaction = await prisma.transaction.update({
      where: { id: created.id },
      data: {
        status: gateway.status,
        providerRef: gateway.providerRef,
        providerData: { ...(created.providerData || {}), mode: gateway.mode, livemode: gateway.livemode, paymentUrl: gateway.paymentUrl, providerOrderId: gateway.providerOrderId, session: gateway.raw },
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
    const order = await prisma.order.findFirst({ where: { orderId: transaction.orderId, userId: req.auth.userId, deletedAt: null } });
    if (!order) throw notFound('Transaction');
    const resolved = ['PAID', 'FAILED', 'CANCELLED'].includes(String(transaction.status).toUpperCase())
      ? { transaction }
      : await finalizeTransaction(transaction.providerRef);
    return res.status(200).json({ data: paymentPayload(resolved.transaction) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function webhook(req, res, next) {
  let payload;
  try {
    const rawBody = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : String(req.body || '');
    payload = JSON.parse(rawBody);
    const livemode = payload.livemode === true;
    if (!verifyWebhookSignature(rawBody, req.headers, livemode)) {
      const error = new Error('Signature Nyole invalide ou expirée.');
      error.statusCode = 401;
      throw error;
    }
    const externalEventId = req.get('x-afriflow-delivery')
      || `${payload.event || 'payment.updated'}:${payload.data?.id || 'unknown'}:${payload.data?.status || ''}:${payload.timestamp || ''}`;
    const existing = await prisma.paymentWebhookEvent.findFirst({ where: { provider: 'nyole', externalEventId } });
    if (existing?.processedAt) {
      return res.status(200).json({ data: { idempotent: true, eventId: externalEventId } });
    }
    if (!existing) {
      try {
        await prisma.paymentWebhookEvent.create({
          data: { provider: 'nyole', externalEventId, transactionId: payload.data?.id || null, payload, signatureValid: true },
        });
      } catch (error) {
        // Two deliveries can arrive at the same time. The unique constraint
        // makes the second one reuse the first event instead of duplicating it.
        if (error.code !== 'P2002') throw error;
      }
    }
    if (!payload.data?.id) throw badRequest('Référence de session Nyole absente.');
    const result = await finalizeTransaction(String(payload.data.id));
    await prisma.paymentWebhookEvent.updateMany({ where: { provider: 'nyole', externalEventId }, data: { processedAt: new Date(), transactionId: result.transaction.transactionId } });
    return res.status(200).json({ data: { transactionId: result.transaction.transactionId, status: result.transaction.status, idempotent: result.idempotent } });
  } catch (error) {
    if (error instanceof SyntaxError) {
      error.statusCode = 400;
      error.message = 'Le corps du webhook Nyole est invalide.';
    }
    return handleControllerError(error, next);
  }
}

async function sandboxConfirm(req, res, next) {
  try {
    const transaction = await prisma.transaction.findUnique({ where: { transactionId: req.params.transactionId } });
    if (!transaction || transaction.provider !== 'nyole') throw notFound('Transaction');
    const order = await prisma.order.findFirst({ where: { orderId: transaction.orderId, userId: req.auth.userId, deletedAt: null } });
    if (!order) throw notFound('Transaction');
    await confirmSandbox(transaction.providerRef, req.body.success === false ? 'echec' : 'succes');
    const result = await finalizeTransaction(transaction.providerRef);
    return res.status(200).json({ data: { ...paymentPayload(result.transaction), idempotent: result.idempotent } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

function paymentReturn(req, res) {
  const title = req.query.status === 'success' ? 'reçu' : 'en cours de vérification';
  return res.status(200).type('html').send(`<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Paiement Dios Delices</title></head><body><main><h1>Paiement ${title}</h1><p>Vous pouvez revenir dans Dios Delices. La commande ne sera confirmée qu’après vérification côté serveur.</p></main></body></html>`);
}

module.exports = { getPayment, initialize, initializeTip, paymentReturn, sandboxConfirm, webhook };
