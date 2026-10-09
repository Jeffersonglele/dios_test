const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound, conflict } = require('./controller.utils');
const dispatch = require('../services/delivery-dispatch.service');
const geolocation = require('../services/geolocation.service');
const { quoteDelivery } = require('../services/delivery-pricing.service');
const { broadcastDeliveryStatus } = require('../sockets/socket.manager');

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
    const record = await prisma.deliveryConfig.findFirst({
      where: { active: true, ...(cityId === null ? {} : { cityId }) },
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
    return res.status(200).json({ data: await dispatch.rejectOffer({ offerId: req.params.id, delivererId: req.auth.userId }) });
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

async function getCourierEarnings(req, res, next) {
  try {
    const userId = req.auth.userId;
    const period = String(req.query.period || 'week').toLowerCase();

    const now = new Date();
    let start;
    if (period === 'today') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    } else if (period === 'month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1);
    } else {
      // week (default): last 7 days inclusive
      start = new Date(now);
      start.setDate(start.getDate() - 6);
      start.setHours(0, 0, 0, 0);
    }

    const m = {
      delivery: prisma.delivery || prisma.deliveries,
      order: prisma.order || prisma.orders || prisma.commande,
      delivererPayout: prisma.delivererPayout || prisma.delivererPayouts,
      tip: prisma.tip || prisma.tips,
    };

    const deliveries = await m.delivery.count({
      where: {
        delivererId: userId,
        status: 'DELIVERED',
        deliveredAt: { gte: start },
      },
    });

    const payoutAgg = await m.delivererPayout.aggregate({
      where: { delivererId: userId, weekStart: { gte: start } },
      _sum: { totalBasePay: true, totalDistancePay: true, totalTips: true, netAmount: true },
    });

    const base = Number(payoutAgg?._sum?.totalBasePay ?? 0);
    const dist = Number(payoutAgg?._sum?.totalDistancePay ?? 0);
    const tips = Number(payoutAgg?._sum?.totalTips ?? 0);
    const net = Number(payoutAgg?._sum?.netAmount ?? 0);
    const totalGains = net > 0 ? net : base + dist + tips;

    return res.status(200).json({
      data: {
        period,
        startDate: start.toISOString(),
        totalLivraisons: deliveries,
        totalBasePay: base,
        totalDistancePay: dist,
        totalPourboires: tips,
        totalGains,
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

const MAX_CASH_ON_HAND = 50000;

async function acceptOrder(req, res, next) {
  try {
    const orderId = Number.parseInt(req.params.orderId, 10);
    const delivererId = req.auth.userId;

    if (!Number.isInteger(orderId)) throw badRequest('orderId invalide');

    const user = await prisma.user.findFirst({
      where: { userId: delivererId, deletedAt: null },
      select: { id: true, cashOnHand: true, userId: true },
    });
    if (!user) throw notFound('Livreur introuvable');

    const order = await prisma.order.findUnique({
      where: { orderId },
      select: {
        id: true,
        orderId: true,
        totalAmount: true,
        paymentProvider: true,
        delivererId: true,
        status: true,
      },
    });
    if (!order) throw notFound('Commande introuvable');

    if (order.delivererId !== null) {
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
      const recheckOrder = await tx.order.findUnique({
        where: { orderId },
        select: { delivererId: true },
      });

      if (!recheckOrder || recheckOrder.delivererId !== null) {
        throw conflict('Cette commande a déjà été acceptée par un autre livreur.');
      }

      const updatedOrder = await tx.order.update({
        where: { orderId },
        data: {
          delivererId: user.userId,
          status: 'ACCEPTED',
        },
      });

      const updatedDelivery = await tx.delivery.update({
        where: { orderId },
        data: {
          delivererId: user.userId,
          status: 'ASSIGNED',
          acceptedAt: new Date(),
        },
      });

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
