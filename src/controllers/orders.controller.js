const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, pagination, pick, sendPage } = require('./controller.utils');
const { startDispatchForOrder } = require('../services/delivery-dispatch.service');
const { quoteDelivery, resolveRestaurantLocation, configurationForCity } = require('../services/delivery-pricing.service');
const { broadcastDeliveryStatus } = require('../sockets/socket.manager');

/**
 * Vérifie si une chaîne ressemble à un UUID valide (format avec tirets, 36 caractères)
 */
function isValidUUID(str) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

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
    orderBy: { orderId: 'desc' }, select: { orderId: true },
  });
  return (last?.orderId || 0) + 1;
}

const OTP_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateRetrievalOtp(length = 4) {
  const chunks = [];
  for (let i = 0; i < length; i += 1) {
    chunks.push(
      OTP_ALPHABET[Math.floor(Math.random() * OTP_ALPHABET.length)],
    );
  }
  return chunks.join('');
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

    const resolvedLocation = await resolveRestaurantLocation(restaurant);
    const resolvedLat = Number.isFinite(resolvedLocation.latitude) ? resolvedLocation.latitude : Number(restaurant.latitude);
    const resolvedLng = Number.isFinite(resolvedLocation.longitude) ? resolvedLocation.longitude : Number(restaurant.longitude);
    if (resolvedLocation.source && (resolvedLat !== Number(restaurant.latitude) || resolvedLng !== Number(restaurant.longitude))) {
      try {
        await prisma.restaurant.updateMany({
          where: { restaurantId, deletedAt: null },
          data: { latitude: resolvedLat, longitude: resolvedLng },
        });
      } catch (_) {}
    }

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
    const deliveryMode = String(payload.deliveryMode || 'DELIVERY').toUpperCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    const pickupTokens = new Set(['PICKUP', 'EMPORTER', 'A EMPORTER', 'TAKEAWAY', 'EMPORT', 'TOGO', 'TO GO']);
    const isDelivery = !pickupTokens.has(deliveryMode) && !deliveryMode.startsWith('EMPORTER') && !deliveryMode.includes('EMPORTER');
    let quote = null;
    let deliveryAddress = null;
    if (isDelivery) {
      const addressId = Number.parseInt(payload.deliveryAddressId || payload.addressId, 10);
      if (!Number.isInteger(addressId)) throw badRequest('Une adresse de livraison est obligatoire.');
      quote = await quoteDelivery({ restaurantId, addressId, userId });
      const gpsReasons = new Set(['MISSING_LOCATION', 'NO_GPS_FALLBACK', null, undefined]);
      const isGpsTolerable = quote.available === true
        || quote.noGpsFallback === true
        || gpsReasons.has(String(quote.reason || '').toUpperCase())
        || (quote.missingRestaurantLocation === true)
        || (quote.missingCustomerLocation === true)
        || (typeof quote.deliveryFee === 'number' && Number.isFinite(quote.deliveryFee) && quote.deliveryFee > 0);
      if (!quote.available && !isGpsTolerable) throw badRequest(quote.message);
      const numericUserId = Number.isInteger(userId) ? userId : Number.parseInt(String(userId ?? ''), 10);
      deliveryAddress = await prisma.address.findFirst({
        where: {
          addressId,
          ...(Number.isInteger(numericUserId) ? { objectId: numericUserId } : {}),
          deletedAt: null,
        },
      });
    }
    let deliveryFee = Number(
      (quote && Number.isFinite(Number(quote.deliveryFee))) ? quote.deliveryFee : (quote?.deliveryFee || 0)
    );
    if (isDelivery && (!Number.isFinite(deliveryFee) || deliveryFee <= 0)) {
      const resDeliveryFee = Number(restaurant.deliveryFee || 0);
      if (Number.isFinite(resDeliveryFee) && resDeliveryFee > 0) {
        deliveryFee = resDeliveryFee;
      } else {
        const addressCityId = deliveryAddress?.cityId != null ? Number(deliveryAddress.cityId) : null;
        const fallbackCfg = await configurationForCity(addressCityId ?? null);
        deliveryFee = Number(fallbackCfg?.baseFee || 0);
      }
    }
    const requestedReduction = Number(payload.reduction || 0);
    const reduction = Number.isFinite(requestedReduction) && requestedReduction > 0 ? requestedReduction : 0;
    const totalAmount = Math.max(0, Number(subtotalAmount) + Number(deliveryFee) - Number(reduction));
    const defaultCurrency = String(payload.currency || payload.currencyCode || restaurant.currency || 'CDF').toUpperCase();
    const supportedCurrencies = new Set(['CDF', 'USD', 'XAF', 'XOF', 'EUR', 'GBP']);
    const currency = supportedCurrencies.has(defaultCurrency) ? defaultCurrency : 'CDF';
    const paymentMethod = String(payload.paymentMethod || payload.paymentProvider || 'CASH').trim().toUpperCase();
    if (!['CASH', 'NYOLE', 'WALLET'].includes(paymentMethod)) {
      throw badRequest("Le moyen de paiement doit être CASH, NYOLE ou WALLET.");
    }

    let walletForCreation = null;
    if (paymentMethod === 'WALLET') {
      walletForCreation = await prisma.walletAccount.findUnique({ where: { userId } });
      if (!walletForCreation) throw badRequest('Portefeuille introuvable. Veuillez initialiser votre portefeuille.');
      if (walletForCreation.status !== 'ACTIVE') throw badRequest('Portefeuille inactif. Veuillez activer votre portefeuille.');
      
      // Ajustement automatique de la devise si le solde est 0
      if (walletForCreation.currency && String(walletForCreation.currency).toUpperCase() !== currency) {
        if (Number(walletForCreation.balance || 0) === 0) {
          walletForCreation = await prisma.walletAccount.update({
            where: { id: walletForCreation.id },
            data: { currency },
          });
        } else {
          throw badRequest(`La devise du portefeuille (${walletForCreation.currency}) ne correspond pas à celle de la commande (${currency}).`);
        }
      }

      if (Number(walletForCreation.balance || 0) < Number(totalAmount)) {
        const currentBalance = Number(walletForCreation.balance || 0);
        const walletCurr = walletForCreation.currency || currency;
        throw badRequest(`Solde du portefeuille insuffisant (${currentBalance} ${walletCurr}). Total commande: ${totalAmount} ${currency}. Veuillez recharger votre portefeuille.`);
      }
    }

    const order = await prisma.$transaction(async (tx) => {
      const orderId = await nextOrderId(tx);
      const externalOrderId = payload.externalOrderId || randomUUID();
      let orderStatusValue = 'AWAITING_PAYMENT';
      if (paymentMethod === 'CASH') orderStatusValue = 'CONFIRMED_CASH';
      if (paymentMethod === 'WALLET') orderStatusValue = 'PAID';

      let walletAfterDebit = null;
      if (paymentMethod === 'WALLET') {
        const locked = await tx.walletAccount.findUnique({
          where: { id: walletForCreation.id },
          select: { id: true, balance: true, currency: true, status: true, version: true },
        });
        if (!locked || Number(locked.balance || 0) < Number(totalAmount)) {
          throw badRequest('Solde du portefeuille insuffisant (concurrent). Veuillez réessayer.');
        }
        walletAfterDebit = await tx.walletAccount.update({
          where: { id: walletForCreation.id },
          data: { balance: { decrement: Number(totalAmount) } },
        });
        await tx.walletLedgerEntry.create({
          data: {
            walletAccountId: walletForCreation.id,
            direction: 'DEBIT',
            amount: Number(totalAmount),
            currency: walletAfterDebit.currency || currency,
            status: 'COMPLETED',
            referenceType: 'ORDER_PAYMENT',
            referenceId: String(orderId),
            description: `Paiement commande #${orderId}`,
            postedAt: new Date(),
          },
        });
      }

      const created = await tx.order.create({
        data: {
          ...pick(payload, ORDER_FIELDS),
          orderId,
          externalOrderId,
          userId,
          restaurantId,
          restaurateurId: Number.isInteger(restaurant.userId) ? restaurant.userId : null,
          deliveryMode: isDelivery ? 'DELIVERY' : 'PICKUP',
          deliveryFee,
          reduction,
          subtotalAmount,
          totalAmount,
          currency,
          paymentProvider: paymentMethod,
          cityId: quote?.cityId || restaurant.cityId,
          deliveryDistanceKm: quote?.estimatedDistanceKm || null,
          deliveryQuoteSnapshot: quote,
          deliveryAddressSnapshot: isDelivery && deliveryAddress ? {
            addressId: deliveryAddress.addressId,
            fullAddress: deliveryAddress.fullAddress,
            latitude: deliveryAddress.latitude,
            longitude: deliveryAddress.longitude,
            cityId: deliveryAddress.cityId,
          } : undefined,
          pickupSnapshot: !isDelivery ? {
            restaurantId: restaurant.restaurantId,
            name: restaurant.name,
            address: restaurant.address,
            latitude: Number.isFinite(resolvedLat) ? resolvedLat : restaurant.latitude,
            longitude: Number.isFinite(resolvedLng) ? resolvedLng : restaurant.longitude,
            cityId: quote?.cityId || restaurant.cityId,
            resolvedSource: resolvedLocation.source,
          } : undefined,
          orderedAt: payload.orderedAt ? new Date(payload.orderedAt) : new Date(),
          status: orderStatusValue,
          orderStatus: orderStatusValue,
          retrievalOtp: generateRetrievalOtp(4),
          isOtpVerified: false,
        },
      });

      if (paymentMethod === 'CASH') {
        await tx.transaction.create({
          data: {
            transactionId: `CASH-${orderId}-${randomUUID().replace(/-/g, '')}`,
            orderId,
            provider: 'cash',
            amount: totalAmount,
            currency,
            status: 'PENDING_CASH_COLLECTION',
            paymentMethod: 'CASH',
            subtotalAmount,
            restaurantShare: Math.max(0, Number(subtotalAmount) - Number(reduction)),
            deliveryFeeShare: deliveryFee,
            commissionRate: 0,
            commissionAmount: 0,
            settlementStatus: 'PENDING_DELIVERY',
          },
        });
      } else if (paymentMethod === 'WALLET') {
        await tx.transaction.create({
          data: {
            transactionId: `WALLET-${orderId}-${randomUUID().replace(/-/g, '')}`,
            orderId,
            provider: 'wallet',
            amount: totalAmount,
            currency,
            status: 'COMPLETED',
            paymentMethod: 'WALLET',
            subtotalAmount,
            restaurantShare: Math.max(0, Number(subtotalAmount) - Number(reduction)),
            deliveryFeeShare: deliveryFee,
            commissionRate: 0,
            commissionAmount: 0,
            settlementStatus: isDelivery ? 'PENDING_DELIVERY' : 'SETTLED',
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
      return { created, walletAfterDebit };
    });

    const { created: createdOrder, walletAfterDebit } = order;
    const orderLines = await prisma.orderLine.findMany({ where: { orderId: String(createdOrder.orderId), deletedAt: null } });
    const responseData = { order: createdOrder, lines: orderLines };
    if (walletAfterDebit) {
      responseData.wallet = {
        id: walletAfterDebit.id,
        balance: Number(walletAfterDebit.balance),
        currency: walletAfterDebit.currency || currency,
      };
    }
    return res.status(201).json({ data: responseData });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getOrderDetails(req, res, next) {
  try {
    const orderId = req.params.id;
    const parsedOrderId = Number.parseInt(orderId, 10);
    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          ...(isValidUUID(orderId) ? [{ id: orderId }] : []),
        ],
        deletedAt: null,
      },
    });
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

    const includeLines = req.query.includeLines === 'true';

    const [orders, total] = await prisma.$transaction([
      prisma.order.findMany({
        where,
        skip: pageInfo.skip,
        take: pageInfo.take,
        orderBy: { orderedAt: 'desc' },
      }),
      prisma.order.count({ where }),
    ]);

    const data = orders;

    // Si includeLines est activé, récupérer les lignes séparément
    if (includeLines) {
      const orderIds = orders.map(order => String(order.orderId));
      const allLines = await prisma.orderLine.findMany({
        where: {
          orderId: { in: orderIds },
          deletedAt: null,
        },
      });

      // Grouper les lignes par orderId
      const linesByOrderId = new Map();
      for (const line of allLines) {
        const orderId = line.orderId;
        if (!linesByOrderId.has(orderId)) {
          linesByOrderId.set(orderId, []);
        }
        linesByOrderId.get(orderId).push(line);
      }

      // Attacher les lignes à chaque order
      for (const order of data) {
        order.lines = linesByOrderId.get(String(order.orderId)) || [];
      }

      // Récupérer les noms des plats pour chaque ligne
      for (const order of data) {
        if (order.lines && order.lines.length > 0) {
          const dishIds = order.lines.map(line => line.dishId).filter(id => id != null);
          if (dishIds.length > 0) {
            const dishes = await prisma.dish.findMany({
              where: { dishId: { in: dishIds }, deletedAt: null },
              select: { dishId: true, name: true },
            });
            const dishMap = new Map(dishes.map(d => [d.dishId, d.name]));
            order.lines = order.lines.map(line => ({
              ...line,
              dishName: dishMap.get(line.dishId) || null,
            }));
          }
        }
      }
    }

    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateOrderStatus(req, res, next) {
  try {
    const orderId = req.params.id;
    const parsedOrderId = Number.parseInt(orderId, 10);
    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          ...(isValidUUID(orderId) ? [{ id: orderId }] : []),
        ],
        deletedAt: null,
      },
    });
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
    const orderIdentifier = updated.orderId ?? updated.id;
    if (orderIdentifier) {
      broadcastDeliveryStatus({
        orderId: orderIdentifier,
        status: updated.deliveryStatus || updated.orderStatus || updated.status,
        courierId: updated.delivererId,
        extra: { orderStatus: updated.orderStatus, status: updated.status },
      });
    }
    return res.status(200).json({ data: { order: updated, delivery } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function verifyRetrievalOrder(req, res, next) {
  try {
    const orderId = req.params.id;
    const parsedOrderId = Number.parseInt(orderId, 10);
    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          ...(isValidUUID(orderId) ? [{ id: orderId }] : []),
        ],
        deletedAt: null,
      },
    });
    if (!order) throw notFound('Commande');

    const otp = typeof req.body.otp === 'string' ? req.body.otp.trim().toUpperCase() : '';
    const proofPhotoUrl = typeof req.body.proofPhotoUrl === 'string'
      ? req.body.proofPhotoUrl.trim()
      : req.body.proofPhotoUrl;

    const isDelivery = String(order.deliveryMode || '').toUpperCase() === 'DELIVERY';

    if (!otp) {
      throw badRequest("Le code OTP est obligatoire pour valider la remise.");
    }

    if (isDelivery) {
      if (!proofPhotoUrl) {
        throw badRequest('Photo de preuve obligatoire pour la livraison.');
      }
      if (order.delivererId === null || order.delivererId === undefined) {
        const err = new Error('Aucun livreur n\'est assigné à cette commande.');
        err.statusCode = 400;
        throw err;
      }
      if (Number(order.delivererId) !== Number(req.auth.userId)) {
        const err = new Error('Seul le livreur assigné peut valider cette livraison.');
        err.statusCode = 403;
        throw err;
      }
      if (!order.retrievalOtp || otp !== String(order.retrievalOtp).toUpperCase()) {
        throw badRequest('Code OTP incorrect.');
      }
      if (order.isOtpVerified === true) {
        return res.status(200).json({
          data: { message: 'La livraison est déjà validée.', order },
        });
      }

      const isCashPayment = order.paymentProvider === 'CASH';

      const result = await prisma.$transaction(async (tx) => {
        const updated = await tx.order.update({
          where: { id: order.id },
          data: {
            isOtpVerified: true,
            proofPhotoUrl,
            status: 'DELIVERED',
            orderStatus: 'DELIVERED',
            deliveryStatus: 'DELIVERED',
          },
        });

        if (isCashPayment && order.delivererId) {
          const deliverer = await tx.user.findFirst({
            where: { userId: order.delivererId, deletedAt: null },
          });
          if (deliverer) {
            await tx.user.update({
              where: { id: deliverer.id },
              data: {
                cashOnHand: {
                  increment: Number(order.totalAmount || 0),
                },
              },
            });
          }
        }

        return updated;
      });

      const orderIdentifier = result.orderId ?? result.id;
      if (orderIdentifier) {
        broadcastDeliveryStatus({
          orderId: orderIdentifier,
          status: 'DELIVERED',
          courierId: order.delivererId,
          extra: { orderStatus: result.orderStatus, status: result.status },
        });
      }
      return res.status(200).json({
        data: { message: 'Livraison validée avec succès.', order: result },
      });
    }

    // Cas B : À EMPORTER (PICKUP)
    const restaurant = await prisma.restaurant.findFirst({
      where: { restaurantId: order.restaurantId, deletedAt: null },
    });
    if (!restaurant) {
      throw notFound('Restaurant associé à la commande.');
    }
    if (Number(restaurant.userId) !== Number(req.auth.userId)) {
      const err = new Error('Seul le restaurateur propriétaire peut valider ce retrait.');
      err.statusCode = 403;
      throw err;
    }
    if (!order.retrievalOtp || otp !== String(order.retrievalOtp).toUpperCase()) {
      throw badRequest('Code OTP incorrect.');
    }
    if (order.isOtpVerified === true) {
      return res.status(200).json({
        data: { message: 'Le retrait est déjà validé.', order },
      });
    }
    const updated = await prisma.order.update({
      where: { id: order.id },
      data: {
        isOtpVerified: true,
        status: 'COMPLETED',
        orderStatus: 'COMPLETED',
      },
    });
    const orderIdentifier = updated.orderId ?? updated.id;
    if (orderIdentifier) {
      broadcastDeliveryStatus({
        orderId: orderIdentifier,
        status: 'COMPLETED',
        courierId: updated.delivererId,
        extra: { orderStatus: updated.orderStatus, status: updated.status },
      });
    }
    return res.status(200).json({
      data: { message: 'Retrait validé avec succès.', order: updated },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function submitDispute(req, res, next) {
  try {
    const orderId = Number.parseInt(req.params.orderId, 10);
    const { reason, proofPhotoUrl } = req.body;
    const userId = req.auth.userId;

    if (!Number.isInteger(orderId)) throw badRequest('orderId invalide');
    if (!reason || typeof reason !== 'string' || reason.trim() === '') {
      throw badRequest('La raison du litige est obligatoire');
    }
    if (!proofPhotoUrl || typeof proofPhotoUrl !== 'string' || proofPhotoUrl.trim() === '') {
      throw badRequest('La photo de preuve est obligatoire');
    }

    const order = await prisma.order.findFirst({
      where: { orderId, deletedAt: null },
    });
    if (!order) throw notFound('Commande introuvable');

    if (order.userId !== userId) {
      const err = new Error('Seul le client peut soumettre un litige pour sa commande');
      err.statusCode = 403;
      throw err;
    }

    const delivery = await prisma.delivery.findUnique({
      where: { orderId },
    });
    if (!delivery) throw notFound('Livraison introuvable');

    if (!delivery.deliveredAt) {
      throw badRequest('La commande n\'a pas encore été livrée');
    }

    const now = new Date();
    const diff = now.getTime() - delivery.deliveredAt.getTime();
    const sixtyMinutesInMs = 60 * 60 * 1000;

    if (diff > sixtyMinutesInMs) {
      const err = new Error('Le délai de réclamation de 60 minutes est dépassé');
      err.statusCode = 403;
      throw err;
    }

    const existingDispute = await prisma.dispute.findUnique({
      where: { orderId },
    });
    if (existingDispute) {
      throw badRequest('Un litige existe déjà pour cette commande');
    }

    const dispute = await prisma.dispute.create({
      data: {
        orderId,
        userId,
        reason: reason.trim(),
        proofPhotoUrl: proofPhotoUrl.trim(),
        status: 'OPEN',
      },
    });

    return res.status(201).json({ data: dispute });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function payOrderWithWallet(req, res, next) {
  try {
    const orderId = req.params.orderId;
    const userId = req.auth.userId;

    if (!orderId) throw badRequest('orderId est obligatoire');

    const parsedOrderId = Number.parseInt(orderId, 10);
    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          ...(isValidUUID(orderId) ? [{ id: orderId }] : []),
        ],
        deletedAt: null,
      },
      select: {
        id: true,
        orderId: true,
        userId: true,
        totalAmount: true,
        status: true,
        orderStatus: true,
        paymentProvider: true,
        currency: true,
      },
    });

    if (!order) throw notFound('Commande introuvable');
    if (order.userId !== userId) {
      const err = new Error('Non autorisé : cette commande ne vous appartient pas');
      err.statusCode = 403;
      throw err;
    }

    const payableStatuses = ['PENDING', 'AWAITING_PAYMENT', 'ACCEPTED', 'CONFIRMED_CASH'];
    if (!payableStatuses.includes(order.status) && !payableStatuses.includes(order.orderStatus)) {
      throw badRequest('Cette commande ne peut plus être payée (statut invalide)');
    }

    if (order.paymentProvider === 'WALLET' || order.status === 'PAID') {
      return res.status(200).json({
        data: {
          success: true,
          message: 'Cette commande est déjà payée avec le portefeuille.',
          order,
        },
      });
    }

    const wallet = await prisma.walletAccount.findUnique({
      where: { userId },
    });

    if (!wallet) {
      throw badRequest('Portefeuille introuvable. Veuillez initialiser votre portefeuille.');
    }

    if (wallet.status !== 'ACTIVE') {
      throw badRequest('Portefeuille inactif. Veuillez activer votre portefeuille.');
    }

    const walletBalance = Number(wallet.balance || 0);
    const orderAmount = Number(order.totalAmount || 0);

    if (walletBalance < orderAmount) {
      const err = new Error('Solde insuffisant. Veuillez recharger votre portefeuille.');
      err.statusCode = 400;
      throw err;
    }

    const result = await prisma.$transaction(async (tx) => {
      const recheckOrder = await tx.order.findUnique({
        where: { id: order.id },
        select: { paymentProvider: true },
      });

      if (recheckOrder && recheckOrder.paymentProvider === 'WALLET') {
        throw badRequest('Cette commande a déjà été payée par un autre processus.');
      }

      const updatedWallet = await tx.walletAccount.update({
        where: { id: wallet.id },
        data: {
          balance: {
            decrement: orderAmount,
          },
        },
      });

      const ledgerEntry = await tx.walletLedgerEntry.create({
        data: {
          walletAccountId: wallet.id,
          direction: 'DEBIT',
          amount: orderAmount,
          currency: order.currency || wallet.currency,
          status: 'COMPLETED',
          referenceType: 'ORDER_PAYMENT',
          referenceId: String(order.orderId),
          description: `Paiement commande #${order.orderId}`,
          postedAt: new Date(),
        },
      });

      const updatedOrder = await tx.order.update({
        where: { id: order.id },
        data: {
          paymentProvider: 'WALLET',
          status: 'PAID',
          orderStatus: 'PAID',
        },
      });

      return {
        wallet: updatedWallet,
        ledgerEntry,
        order: updatedOrder,
        newBalance: Number(updatedWallet.balance),
      };
    });

    return res.status(200).json({
      data: result,
      message: 'Paiement effectué avec succès',
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  order: {
    ...orderCrud,
    create: createOrder,
    list: listOrders,
    getDetails: getOrderDetails,
    updateStatus: updateOrderStatus,
    verifyRetrieval: verifyRetrievalOrder,
    submitDispute,
    payOrderWithWallet,
  },
  orderLine: orderLineCrud,
  ORDER_FIELDS,
  ORDER_LINE_FIELDS,
};
