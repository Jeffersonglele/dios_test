const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, conflict } = require('./controller.utils');
const dispatch = require('../services/delivery-dispatch.service');
const geolocation = require('../services/geolocation.service');
const { configurationForCity, quoteDelivery } = require('../services/delivery-pricing.service');
const { currencyForCountry } = require('../services/country.service');
const { broadcastDeliveryStatus } = require('../sockets/socket.manager');
const dispatchCron = require('../cron/dispatch.cron');

const CITY_FIELDS = ['cityId', 'name', 'country', 'countryCode', 'deliveryEnabled', 'active'];
const ZONE_FIELDS = [
  'zoneId', 'cityId', 'name', 'polygon', 'deliveryTimeMin', 'deliveryTimeMax',
  'deliveryFeeLevel', 'priority', 'active',
];
const CONFIG_FIELDS = [
  'configId', 'cityId', 'baseFee', 'perKmRate', 'includedDistanceKm', 'maxDistanceKm',
  'fuelPricePerLitre', 'fuelSurcharge', 'demandMultiplier', 'weatherMultiplier', 'roundingIncrement',
  'currency', 'minFee', 'updatedBy', 'active',
  'commissionRate', 'exchangeRate', 'delivererBasePay', 'delivererPerKm', 'subscriptionsEnabled',
];

const city = createCrudController({
  delegate: 'city', resource: 'Ville', fields: CITY_FIELDS, filterFields: ['country', 'active'],
});
const zone = createCrudController({
  delegate: 'deliveryZone', resource: 'Zone de livraison', fields: ZONE_FIELDS,
  filterFields: ['cityId', 'active', 'deliveryFeeLevel'],
});
const config = createCrudController({
  delegate: 'deliveryConfig', resource: 'Configuration de livraison', fields: CONFIG_FIELDS,
  hasSoftDelete: false, filterFields: ['active'],
});

function pointIsInsidePolygon(latitude, longitude, polygon) {
  // Polygon format: [[latitude, longitude], ...]. The API validates it before use.
  let isInside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [latI, lngI] = polygon[i];
    const [latJ, lngJ] = polygon[j];
    const intersects = ((lngI > longitude) !== (lngJ > longitude))
      && (latitude < ((latJ - latI) * (longitude - lngI)) / (lngJ - lngI) + latI);
    if (intersects) isInside = !isInside;
  }
  return isInside;
}

async function resolveZone(req, res, next) {
  try {
    const cityId = Number.parseInt(req.body.cityId, 10);
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    if (!Number.isInteger(cityId) || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw badRequest('cityId, latitude et longitude sont obligatoires.');
    }

    const postgisMatches = await prisma.$queryRaw`
      SELECT "id"
      FROM "delivery_zones"
      WHERE "cityId" = ${cityId}
        AND "active" = true
        AND "deletedAt" IS NULL
        AND "boundary" IS NOT NULL
        AND ST_Covers("boundary", ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326))
      ORDER BY "priority" DESC NULLS LAST
      LIMIT 1
    `;
    if (postgisMatches[0]) {
      const zoneMatch = await prisma.deliveryZone.findUnique({ where: { id: postgisMatches[0].id } });
      return res.status(200).json({ data: zoneMatch, meta: { resolution: 'POSTGIS' } });
    }

    const zones = await prisma.deliveryZone.findMany({
      where: { cityId, active: true, deletedAt: null },
      orderBy: { priority: 'desc' },
    });
    const zoneMatch = zones.find((zone) => {
      try {
        const polygon = JSON.parse(zone.polygon);
        return Array.isArray(polygon) && polygon.length >= 3 && pointIsInsidePolygon(latitude, longitude, polygon);
      } catch (_) {
        return false;
      }
    });
    if (!zoneMatch) throw notFound('Zone de livraison');
    return res.status(200).json({ data: zoneMatch, meta: { resolution: 'LEGACY_POLYGON' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function activeConfig(req, res, next) {
  try {
    const cityId = req.query.cityId === undefined ? null : Number.parseInt(req.query.cityId, 10);
    if (req.query.cityId !== undefined && !Number.isInteger(cityId)) throw badRequest('cityId est invalide.');
    // Avec une ville : tarif réellement appliqué (configuration de la ville
    // ou grille par défaut du pays), comme dans le calcul des devis.
    if (cityId !== null) {
      const city = await prisma.city.findFirst({ where: { cityId, deletedAt: null } });
      if (!city) throw notFound('Ville');
      const effective = await configurationForCity(cityId, city.countryCode || city.country);
      const record = await prisma.deliveryConfig.findFirst({
        where: { active: true, cityId },
        orderBy: { updatedAt: 'desc' },
      });
      return res.status(200).json({ data: { ...effective, cityId, configId: record?.configId ?? null, id: record?.id ?? null } });
    }
    const record = await prisma.deliveryConfig.findFirst({
      where: { active: true },
      orderBy: { updatedAt: 'desc' },
    });
    if (!record) throw notFound('Configuration de livraison');
    return res.status(200).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function quote(req, res, next) {
  try {
    const data = await quoteDelivery({
      restaurantId: req.body.restaurantId,
      addressId: req.body.addressId,
      userId: req.auth.userId,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateAddressLocation(req, res, next) {
  try {
    const data = await geolocation.updateCustomerAddressLocation({
      addressId: req.params.addressId,
      userId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      fullAddress: req.body.fullAddress,
      nominatimPlaceId: req.body.nominatimPlaceId,
      country: req.body.country,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateRestaurantLocation(req, res, next) {
  try {
    const data = await geolocation.updateRestaurantLocation({
      restaurantId: req.params.restaurantId,
      ownerId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      address: req.body.address,
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCityBoundary(req, res, next) {
  try {
    const data = await geolocation.setCityBoundary(req.params.cityId, req.body.geoJson || req.body);
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCourierAvailability(req, res, next) {
  try {
    const data = await geolocation.setCourierAvailability({ userId: req.auth.userId, status: req.body.status });
    // Un livreur qui passe en ligne peut recevoir tout de suite une course en attente.
    if (data?.courierStatus === 'ACTIVE') dispatchCron.kick();
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateCourierLocation(req, res, next) {
  try {
    const data = await geolocation.recordCourierLocation({
      userId: req.auth.userId,
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      accuracyM: req.body.accuracyM,
    });
    dispatchCron.kick();
    return res.status(201).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listCourierOffers(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.courierOffers(req.auth.userId) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listCourierDeliveries(req, res, next) {
  try {
    return res.status(200).json({ data: await dispatch.courierDeliveries(req.auth.userId) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function acceptDeliveryOffer(req, res, next) {
  try {
    const data = await dispatch.acceptOffer({ offerId: req.params.id, delivererId: req.auth.userId });
    if (data?.delivery?.orderId) {
      broadcastDeliveryStatus({
        orderId: data.delivery.orderId,
        status: data.delivery.status,
        courierId: req.auth.userId,
      });
    }
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function rejectDeliveryOffer(req, res, next) {
  try {
    const data = await dispatch.rejectOffer({ offerId: req.params.id, delivererId: req.auth.userId });
    // Si c'était la dernière proposition en attente, la course part au livreur suivant.
    dispatchCron.kick();
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateDeliveryStatus(req, res, next) {
  try {
    const data = await dispatch.advanceDelivery({
      deliveryId: req.params.id,
      delivererId: req.auth.userId,
      status: req.body.status,
    });
    if (data?.orderId) {
      broadcastDeliveryStatus({
        orderId: data.orderId,
        status: data.status,
        courierId: req.auth.userId,
      });
    }
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Décalage horaire de l'app (Kinshasa, Cotonou : UTC+1) pour regrouper
/// les gains par jour local.
function appOffsetMinutes() {
  const value = Number.parseInt(process.env.APP_UTC_OFFSET_MINUTES, 10);
  return Number.isInteger(value) ? value : 60;
}

function localDayKey(date, offset) {
  return new Date(date.getTime() + offset * 60000).toISOString().slice(0, 10);
}

/// Début (UTC) du jour local « AAAA-MM-JJ ».
function localDayStart(key, offset) {
  return new Date(Date.parse(`${key}T00:00:00.000Z`) - offset * 60000);
}

/// Période demandée : today | week (7 jours) | month (30 jours) | custom
/// (startDate / endDate au format AAAA-MM-JJ, bornes incluses, 366 j max).
function earningsRange(query, offset) {
  const todayKey = localDayKey(new Date(), offset);
  const shift = (key, days) => localDayKey(new Date(localDayStart(key, offset).getTime() + days * 86400000), offset);
  const period = String(query.period || 'week').toLowerCase();
  let fromKey;
  let toKey = todayKey;
  if (period === 'custom') {
    const valid = (v) => /^\d{4}-\d{2}-\d{2}$/.test(String(v || ''));
    if (!valid(query.startDate) || !valid(query.endDate)) {
      throw badRequest('Choisissez une date de début et une date de fin.');
    }
    fromKey = String(query.startDate);
    toKey = String(query.endDate);
    if (fromKey > toKey) [fromKey, toKey] = [toKey, fromKey];
    if (toKey > todayKey) toKey = todayKey;
    const days = (localDayStart(toKey, offset) - localDayStart(fromKey, offset)) / 86400000;
    if (days > 366) throw badRequest('La période ne peut pas dépasser un an.');
  } else if (period === 'today') {
    fromKey = todayKey;
  } else if (period === 'month') {
    fromKey = shift(todayKey, -29);
  } else {
    fromKey = shift(todayKey, -6);
  }
  return {
    period: ['today', 'month', 'custom'].includes(period) ? period : 'week',
    fromKey,
    toKey,
    from: localDayStart(fromKey, offset),
    to: new Date(localDayStart(toKey, offset).getTime() + 86400000),
  };
}

/// Gains du livreur sur ses courses livrées : frais de livraison +
/// pourboires, détail par jour et liste des courses.
async function getCourierEarnings(req, res, next) {
  try {
    const userId = Number(req.auth.userId);
    const offset = appOffsetMinutes();
    const range = earningsRange(req.query, offset);

    const [courier, orders] = await Promise.all([
      prisma.user.findFirst({
        where: { userId, deletedAt: null },
        select: { country: true, cashOnHand: true },
      }),
      prisma.order.findMany({
        where: {
          delivererId: userId,
          deletedAt: null,
          status: { in: ['DELIVERED', 'LIVREE'] },
          // Marge d'un jour : la date de remise exacte est lue sur la livraison.
          updatedAt: { gte: new Date(range.from.getTime() - 86400000) },
        },
        orderBy: { updatedAt: 'desc' },
        take: 2000,
      }),
    ]);

    const orderIds = orders.map((o) => o.orderId).filter(Number.isInteger);
    const [deliveries, restaurants] = await Promise.all([
      orderIds.length
        ? prisma.delivery.findMany({
            where: { orderId: { in: orderIds } },
            select: { orderId: true, deliveredAt: true, quotedDistanceKm: true },
          })
        : [],
      prisma.restaurant.findMany({
        where: { restaurantId: { in: [...new Set(orders.map((o) => o.restaurantId).filter(Number.isInteger))] } },
        select: { restaurantId: true, name: true },
      }),
    ]);
    const deliveryByOrder = new Map(deliveries.map((d) => [d.orderId, d]));
    const restaurantName = new Map(restaurants.map((r) => [r.restaurantId, r.name]));
    const num = (v) => {
      const n = Number(v);
      return Number.isFinite(n) ? n : 0;
    };

    const days = new Map();
    for (let t = range.from.getTime(); t < range.to.getTime(); t += 86400000) {
      const key = localDayKey(new Date(t), offset);
      days.set(key, { date: key, gains: 0, deliveries: 0 });
    }

    const rows = [];
    let totalFees = 0;
    let totalTips = 0;
    for (const order of orders) {
      const delivery = deliveryByOrder.get(order.orderId);
      const deliveredAt = delivery?.deliveredAt || order.updatedAt;
      if (deliveredAt < range.from || deliveredAt >= range.to) continue;
      const fee = num(order.deliveryFee ?? order.legacyDeliveryFee);
      const tip = num(order.tipAmount);
      totalFees += fee;
      totalTips += tip;
      const key = localDayKey(deliveredAt, offset);
      const day = days.get(key);
      if (day) {
        day.gains += fee + tip;
        day.deliveries += 1;
      }
      rows.push({
        orderId: order.orderId,
        deliveredAt: deliveredAt.toISOString(),
        restaurantName: restaurantName.get(order.restaurantId) || null,
        deliveryFee: fee,
        tip,
        total: fee + tip,
        paymentMethod: order.paymentProvider || null,
        distanceKm: delivery?.quotedDistanceKm != null ? num(delivery.quotedDistanceKm) : num(order.deliveryDistanceKm) || null,
      });
    }
    rows.sort((a, b) => b.deliveredAt.localeCompare(a.deliveredAt));

    return res.status(200).json({
      data: {
        period: range.period,
        startDate: range.fromKey,
        endDate: range.toKey,
        currency: currencyForCountry(courier?.country),
        totalLivraisons: rows.length,
        totalDeliveryFees: totalFees,
        totalPourboires: totalTips,
        totalGains: totalFees + totalTips,
        averagePerDelivery: rows.length ? Math.round((totalFees + totalTips) / rows.length) : 0,
        cashOnHand: num(courier?.cashOnHand),
        dailyData: [...days.values()],
        deliveries: rows.slice(0, 100),
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function driverArrived(req, res, next) {
  try {
    const orderId = Number.parseInt(req.params.orderId, 10);
    const delivererId = req.auth.userId;
    if (!Number.isInteger(orderId)) throw badRequest('orderId invalide');

    const delivery = await prisma.delivery.findUnique({ where: { orderId } });
    if (!delivery) throw notFound('Livraison introuvable');
    if (delivery.delivererId !== delivererId) throw badRequest('Non autorisé : vous n\'êtes pas le livreur assigné');

    const updated = await prisma.delivery.update({
      where: { orderId },
      data: { driverArrivedAt: new Date() }
    });

    return res.status(200).json({ data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function clientUnreachable(req, res, next) {
  try {
    const orderId = Number.parseInt(req.params.orderId, 10);
    const delivererId = req.auth.userId;
    if (!Number.isInteger(orderId)) throw badRequest('orderId invalide');

    const delivery = await prisma.delivery.findUnique({ where: { orderId } });
    if (!delivery) throw notFound('Livraison introuvable');
    if (delivery.delivererId !== delivererId) throw badRequest('Non autorisé');
    if (!delivery.driverArrivedAt) throw badRequest('Le livreur n\'est pas encore arrivé');

    const now = new Date();
    const diff = now.getTime() - delivery.driverArrivedAt.getTime();
    if (diff < 10 * 60 * 1000) {
      throw badRequest('Le délai d\'attente de 10 minutes n\'est pas encore écoulé');
    }

    const order = await prisma.order.findUnique({ where: { orderId } });
    if (!order) throw notFound('Commande introuvable');

    const isCashPayment = order.paymentProvider === 'CASH';
    let user = null;
    if (isCashPayment && order.userId) {
      user = await prisma.user.findFirst({ where: { userId: order.userId, deletedAt: null } });
    }

    const updates = [
      prisma.order.update({
        where: { orderId },
        data: {
          status: 'CANCELLED',
          cancelledBy: 'CLIENT',
          cancellationReason: 'Client injoignable',
          cancelledAt: now
        }
      }),
      prisma.delivery.update({
        where: { orderId },
        data: {
          status: 'CANCELLED',
          cancellationReason: 'Client injoignable',
          cancelledAt: now
        }
      })
    ];

    if (user) {
      updates.push(
        prisma.user.update({
          where: { id: user.id },
          data: {
            cashDebtAmount: {
              increment: Number(order.totalAmount || 0)
            }
          }
        })
      );
    }

    await prisma.$transaction(updates);

    return res.status(200).json({ success: true, message: 'Commande annulée pour client injoignable' });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listAvailableDeliveries(req, res, next) {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    const radiusKm = Number(req.query.radiusKm) || 5;

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw badRequest('lat et lng sont obligatoires');
    }
    if (!Number.isFinite(radiusKm) || radiusKm <= 0) {
      throw badRequest('radiusKm doit être un nombre positif');
    }

    const deliveries = await prisma.$queryRaw`
      SELECT
        o."commande_id" as "orderId",
        o."id" as "orderUuid",
        o."totalAmount",
        o."paymentProvider",
        o."date_commande" as "orderedAt",
        o."delivery_address_snapshot" as "deliveryAddressSnapshot",
        o."restau_id" as "restaurantId",
        o."frais_livraison" as "deliveryFee",
        o."fraisLivraison" as "legacyDeliveryFee",
        o."delivery_distance_km" as "deliveryDistanceKm",
        r."name" as "restaurantName",
        r."adress" as "restaurantAddress",
        ST_AsGeoJSON(r."location") as "restaurantLocation",
        d."id" as "deliveryId",
        d."delivery_id",
        d."status" as "deliveryStatus",
        d."quoted_distance_km" as "quotedDistanceKm",
        d."quoted_distance_km" as "distanceKm",
        o."currency",
        CASE
          WHEN o."paymentProvider" IS NOT NULL THEN UPPER(o."paymentProvider")
          ELSE 'CARD'
        END as "paymentMethod",
        o."frais_livraison" as "courierFee",
        o."totalAmount" as "cashAmount",
        o."totalAmount" as "cashToCollect"
      FROM "orders" o
      INNER JOIN "restaurants" r ON o."restau_id" = r."restaurantId"
      INNER JOIN "deliveries" d ON o."commande_id" = d."commande_id"
      WHERE o."deletedAt" IS NULL
        AND r."deletedAt" IS NULL
        AND d."cancelled_at" IS NULL
        AND o."deliveryMode" = 'DELIVERY'
        AND o."livreur_id" IS NULL
        AND d."status" = 'SEARCHING'
        AND r."location" IS NOT NULL
        AND ST_DWithin(
          r."location",
          ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography,
          ${radiusKm * 1000}
        )
      ORDER BY o."date_commande" ASC
      LIMIT 50
    `;

    return res.status(200).json({ data: deliveries });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

const { MAX_CASH_ON_HAND } = dispatch;

async function acceptOrder(req, res, next) {
  try {
    const rawOrderId = req.params.orderId;
    const parsedOrderId = Number.parseInt(rawOrderId, 10);
    const isValidUUIDStr = (str) => typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str.trim());

    const delivererId = req.auth.userId;

    const user = await prisma.user.findFirst({
      where: { userId: delivererId, deletedAt: null },
      select: { id: true, cashOnHand: true, userId: true },
    });
    if (!user) throw notFound('Livreur introuvable');

    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          ...(isValidUUIDStr(rawOrderId) ? [{ id: rawOrderId }] : []),
        ],
        deletedAt: null,
      },
    });
    if (!order) throw notFound('Commande introuvable');

    if (order.delivererId !== null && Number(order.delivererId) !== Number(user.userId)) {
      throw conflict('Cette commande a déjà été acceptée par un autre livreur.');
    }

    if (order.paymentProvider === 'CASH') {
      const currentCashOnHand = Number(user.cashOnHand || 0);
      const orderAmount = Number(order.totalAmount || 0);
      if (currentCashOnHand + orderAmount > MAX_CASH_ON_HAND) {
        const err = new Error('Plafond d\'espèces atteint. Veuillez effectuer un reversement Mobile Money pour accepter de nouvelles commandes en espèces.');
        err.statusCode = 403;
        throw err;
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      // Réservation atomique : deux livreurs qui acceptent en même temps ne
      // peuvent pas obtenir la même commande.
      await dispatch.claimOrderForCourier(tx, order.orderId, user.userId);
      const updatedOrder = await tx.order.findUnique({ where: { id: order.id } });

      let existingDelivery = await tx.delivery.findFirst({
        where: { orderId: order.orderId },
      });

      let updatedDelivery;
      if (existingDelivery) {
        if (existingDelivery.delivererId && Number(existingDelivery.delivererId) !== Number(user.userId)) {
          throw conflict('Cette commande a déjà été acceptée par un autre livreur.');
        }
        if (['CANCELLED', 'DELIVERED'].includes(existingDelivery.status)) {
          throw conflict('Cette course n’est plus disponible.');
        }
        updatedDelivery = await tx.delivery.update({
          where: { id: existingDelivery.id },
          data: {
            delivererId: user.userId,
            status: 'ASSIGNED',
            acceptedAt: existingDelivery.acceptedAt || new Date(),
          },
        });
        // Les propositions envoyées aux autres livreurs sont closes.
        await tx.deliveryOffer.updateMany({
          where: { deliveryId: existingDelivery.id, status: 'PENDING' },
          data: { status: 'REJECTED', respondedAt: new Date() },
        });
      } else {
        const { randomUUID } = require('crypto');
        updatedDelivery = await tx.delivery.create({
          data: {
            id: randomUUID(),
            deliveryId: randomUUID(),
            orderId: order.orderId,
            cityId: order.cityId || 1,
            restaurantId: order.restaurantId,
            delivererId: user.userId,
            status: 'ASSIGNED',
            acceptedAt: new Date(),
          },
        });
      }

      await tx.user.update({
        where: { id: user.id },
        data: { courierStatus: 'BUSY' },
      });

      return { order: updatedOrder, delivery: updatedDelivery };
    });

    broadcastDeliveryStatus({
      orderId: order.orderId,
      status: 'ASSIGNED',
      courierId: user.userId,
    });

    return res.status(200).json({ data: result });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  city,
  zone: { ...zone, resolve: resolveZone },
  config: { ...config, active: activeConfig },
  quote,
  updateAddressLocation,
  updateRestaurantLocation,
  updateCityBoundary,
  updateCourierAvailability,
  updateCourierLocation,
  listCourierOffers,
  listCourierDeliveries,
  getCourierEarnings,
  acceptDeliveryOffer,
  rejectDeliveryOffer,
  updateDeliveryStatus,
  driverArrived,
  clientUnreachable,
  listAvailableDeliveries,
  acceptOrder,
  pointIsInsidePolygon,
};
