const { randomUUID } = require('crypto');
const { Prisma } = require('@prisma/client');

const prisma = require('../config/prisma');
const { badRequest, conflict, notFound } = require('../controllers/controller.utils');

function safeInt(val, fallback = null) {
  if (val === undefined || val === null) return fallback;
  const parsed = Number.parseInt(String(val).trim(), 10);
  return Number.isInteger(parsed) ? parsed : fallback;
}

function safeFloat(val, fallback = 0.0) {
  if (val === undefined || val === null) return fallback;
  const parsed = Number.parseFloat(String(val).trim());
  return Number.isFinite(parsed) ? parsed : fallback;
}

function isValidUUID(str) {
  return typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str.trim());
}

function configuredCourierRoleIds() {
  return String(process.env.LIVREUR_ROLE_IDS || '')
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
}

function dispatchSettings() {
  return {
    maxCandidates: Math.min(10, Math.max(1, Number.parseInt(process.env.DISPATCH_OFFER_LIMIT, 10) || 3)),
    offerTtlSeconds: Math.min(300, Math.max(15, Number.parseInt(process.env.DISPATCH_OFFER_TTL_SECONDS, 10) || 60)),
    freshLocationMinutes: Math.min(30, Math.max(1, Number.parseInt(process.env.COURIER_LOCATION_MAX_AGE_MINUTES, 10) || 5)),
  };
}

async function eligibleCouriers(delivery) {
  if (!Number.isFinite(delivery.pickupLatitude) || !Number.isFinite(delivery.pickupLongitude)) return [];
  const settings = dispatchSettings();
  const roleIds = configuredCourierRoleIds();
  const roleFilter = roleIds.length
    ? Prisma.sql`AND u."roleId" IN (${Prisma.join(roleIds)})`
    : Prisma.empty;
  return prisma.$queryRaw(Prisma.sql`
    WITH latest_location AS (
      SELECT DISTINCT ON (cl."livreur_id")
        cl."livreur_id", cl."city_id", cl."location", cl."recorded_at"
      FROM "courier_locations" cl
      WHERE cl."city_id" = ${delivery.cityId}
        AND cl."recorded_at" >= NOW() - (${settings.freshLocationMinutes} * INTERVAL '1 minute')
      ORDER BY cl."livreur_id", cl."recorded_at" DESC
    )
    SELECT
      ll."livreur_id" AS "delivererId",
      ST_Distance(
        ll."location",
        ST_SetSRID(ST_MakePoint(${delivery.pickupLongitude}, ${delivery.pickupLatitude}), 4326)::geography
      ) / 1000.0 AS "distanceToPickupKm"
    FROM latest_location ll
    INNER JOIN "users" u ON u."userId" = ll."livreur_id"
    WHERE u."deletedAt" IS NULL
      AND u."courier_status" = 'ACTIVE'
      AND ll."location" IS NOT NULL
      ${roleFilter}
      AND NOT EXISTS (
        SELECT 1 FROM "deliveries" assigned
        WHERE assigned."livreur_id" = ll."livreur_id"
          AND assigned."status" IN ('ASSIGNED', 'AT_PICKUP', 'PICKED_UP', 'IN_TRANSIT')
      )
    ORDER BY "distanceToPickupKm" ASC
    LIMIT ${settings.maxCandidates}
  `);
}

async function offerDelivery(deliveryId) {
  const delivery = await prisma.delivery.findUnique({ where: { id: deliveryId } });
  if (!delivery) throw notFound('Livraison');
  if (delivery.status !== 'SEARCHING') return { delivery, offers: [] };

  await prisma.deliveryOffer.updateMany({
    where: { deliveryId: delivery.id, status: 'PENDING', expiresAt: { lt: new Date() } },
    data: { status: 'EXPIRED', respondedAt: new Date() },
  });
  const couriers = await eligibleCouriers(delivery);
  const expiresAt = new Date(Date.now() + (dispatchSettings().offerTtlSeconds * 1000));
  if (couriers.length > 0) {
    await prisma.deliveryOffer.createMany({
      data: couriers.map((courier, index) => ({
        id: randomUUID(),
        deliveryId: delivery.id,
        delivererId: safeInt(courier.delivererId),
        rank: index + 1,
        distanceToPickupKm: safeFloat(courier.distanceToPickupKm),
        expiresAt,
      })),
      skipDuplicates: true,
    });
  }
  const offers = await prisma.deliveryOffer.findMany({
    where: { deliveryId: delivery.id, status: 'PENDING' }, orderBy: { rank: 'asc' },
  });
  return { delivery, offers };
}

async function startDispatchForOrder(order) {
  const orderIdInt = safeInt(order?.orderId);
  if (!order || !orderIdInt) throw badRequest('La commande est invalide.');
  
  let pickup = order.pickupSnapshot;
  let destination = order.deliveryAddressSnapshot;
  let cityId = safeInt(order.cityId);
  let restaurantId = safeInt(order.restaurantId);

  // Fallback if pickup is missing: fetch from restaurant table
  if (!pickup && order.restaurantId) {
    const parsedRestauId = safeInt(order.restaurantId);
    const restauIdStr = String(order.restaurantId ?? '').trim();
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          ...(parsedRestauId ? [{ restaurantId: parsedRestauId }] : []),
          ...(isValidUUID(restauIdStr) ? [{ id: restauIdStr }] : []),
        ],
        deletedAt: null,
      },
    });
    if (restaurant) {
      if (!restaurantId) restaurantId = safeInt(restaurant.restaurantId);
      pickup = {
        restaurantId: restaurant.restaurantId,
        name: restaurant.name,
        address: restaurant.address,
        latitude: safeFloat(restaurant.latitude, 0.0),
        longitude: safeFloat(restaurant.longitude, 0.0),
        cityId: safeInt(restaurant.cityId, 1),
      };
      if (!cityId) cityId = safeInt(restaurant.cityId);
    }
  }

  // Fallback if destination is missing: fetch from address table
  if (!destination && order.addressId) {
    const addrId = safeInt(order.addressId);
    if (addrId) {
      const addr = await prisma.address.findFirst({
        where: { addressId: addrId, deletedAt: null },
      });
      if (addr) {
        destination = {
          addressId: addr.addressId,
          fullAddress: addr.fullAddress || addr.name,
          latitude: safeFloat(addr.latitude, 0.0),
          longitude: safeFloat(addr.longitude, 0.0),
          cityId: safeInt(addr.cityId, 1),
        };
        if (!cityId) cityId = safeInt(addr.cityId);
      }
    }
  }

  if (!cityId) cityId = safeInt(pickup?.cityId) || safeInt(destination?.cityId) || 1;

  if (!pickup || !destination) {
    throw badRequest('La commande doit contenir un devis et des points de retrait/livraison validés.');
  }

  const existing = await prisma.delivery.findFirst({ where: { orderId: orderIdInt } });
  const delivery = existing || await prisma.delivery.create({
    data: {
      id: randomUUID(),
      deliveryId: randomUUID(),
      orderId: orderIdInt,
      cityId: cityId,
      restaurantId: restaurantId || safeInt(pickup?.restaurantId),
      pickupLatitude: safeFloat(pickup.latitude, 0.0),
      pickupLongitude: safeFloat(pickup.longitude, 0.0),
      deliveryLatitude: safeFloat(destination.latitude, 0.0),
      deliveryLongitude: safeFloat(destination.longitude, 0.0),
      quotedDistanceKm: safeFloat(order.deliveryDistanceKm, 1.0),
      status: 'SEARCHING',
      dispatchAttempt: 1,
    },
  });
  if (delivery.status !== 'SEARCHING') return { delivery, offers: [] };
  return offerDelivery(delivery.id);
}

async function acceptOffer({ offerId, delivererId }) {
  return prisma.$transaction(async (tx) => {
    const offer = await tx.deliveryOffer.findFirst({ where: { id: offerId, delivererId } });
    if (!offer) throw notFound('Proposition de livraison');
    if (offer.status !== 'PENDING' || (offer.expiresAt && offer.expiresAt <= new Date())) {
      throw conflict('Cette proposition a expiré ou a déjà reçu une réponse.');
    }
    const claimed = await tx.delivery.updateMany({
      where: { id: offer.deliveryId, status: 'SEARCHING', delivererId: null },
      data: { status: 'ASSIGNED', delivererId, acceptedAt: new Date() },
    });
    if (claimed.count !== 1) throw conflict('Cette course a déjà été acceptée par un autre livreur.');
    await tx.deliveryOffer.update({ where: { id: offer.id }, data: { status: 'ACCEPTED', respondedAt: new Date() } });
    await tx.deliveryOffer.updateMany({
      where: { deliveryId: offer.deliveryId, id: { not: offer.id }, status: 'PENDING' },
      data: { status: 'REJECTED', respondedAt: new Date() },
    });
    await tx.user.updateMany({ where: { userId: delivererId, deletedAt: null }, data: { courierStatus: 'BUSY' } });
    const delivery = await tx.delivery.findUnique({ where: { id: offer.deliveryId } });
    return { delivery, offer: { ...offer, status: 'ACCEPTED' } };
  });
}

async function rejectOffer({ offerId, delivererId }) {
  const offer = await prisma.deliveryOffer.findFirst({ where: { id: offerId, delivererId } });
  if (!offer) throw notFound('Proposition de livraison');
  if (offer.status !== 'PENDING') throw conflict('Cette proposition a déjà reçu une réponse.');
  return prisma.deliveryOffer.update({ where: { id: offer.id }, data: { status: 'REJECTED', respondedAt: new Date() } });
}

const STATUS_TRANSITIONS = Object.freeze({
  SEARCHING: ['ASSIGNED', 'AT_PICKUP', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'],
  ASSIGNED: ['AT_PICKUP', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'],
  AT_PICKUP: ['PICKED_UP', 'IN_TRANSIT', 'DELIVERED'],
  PICKED_UP: ['IN_TRANSIT', 'DELIVERED'],
  IN_TRANSIT: ['DELIVERED'],
});

async function advanceDelivery({ deliveryId, delivererId, status }) {
  const nextStatus = String(status || '').toUpperCase().trim();
  const parsedOrderId = safeInt(deliveryId);
  const rawIdStr = String(deliveryId || '').trim();

  const whereOr = [
    ...(parsedOrderId ? [{ orderId: parsedOrderId }] : []),
    ...(isValidUUID(rawIdStr) ? [{ deliveryId: rawIdStr }, { id: rawIdStr }] : []),
  ];

  if (whereOr.length === 0) {
    throw notFound('Livraison introuvable');
  }

  const delivery = await prisma.delivery.findFirst({
    where: {
      OR: whereOr,
      ...(delivererId ? { delivererId: safeInt(delivererId) } : {}),
    },
  });

  if (!delivery) throw notFound('Livraison introuvable');

  const allowedNext = STATUS_TRANSITIONS[delivery.status] || ['ASSIGNED', 'AT_PICKUP', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'];
  if (!allowedNext.includes(nextStatus) && delivery.status !== nextStatus) {
    throw conflict(`Transition impossible de ${delivery.status} vers ${nextStatus}.`);
  }

  const timestamps = {
    ...(nextStatus === 'AT_PICKUP' ? { driverArrivedAt: new Date() } : {}),
    ...(nextStatus === 'PICKED_UP' ? { pickedUpAt: new Date() } : {}),
    ...(nextStatus === 'DELIVERED' ? { deliveredAt: new Date() } : {}),
  };

  const updated = await prisma.delivery.update({
    where: { id: delivery.id },
    data: { status: nextStatus, ...timestamps },
  });

  await prisma.order.updateMany({
    where: { orderId: delivery.orderId, deletedAt: null },
    data: {
      deliveryStatus: nextStatus,
      ...(nextStatus === 'DELIVERED' ? { status: 'LIVREE', orderStatus: 'LIVREE' } : {}),
    },
  });

  if (nextStatus === 'DELIVERED') {
    await prisma.user.updateMany({
      where: { userId: delivererId, deletedAt: null },
      data: { courierStatus: 'ACTIVE' },
    });
  }

  return updated;
}

async function courierOffers(delivererId) {
  const offers = await prisma.deliveryOffer.findMany({
    where: { delivererId, status: 'PENDING', OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
    orderBy: [{ rank: 'asc' }, { createdAt: 'desc' }],
  });
  const deliveries = offers.length ? await prisma.delivery.findMany({ where: { id: { in: offers.map((offer) => offer.deliveryId) } } }) : [];
  const deliveryById = new Map(deliveries.map((delivery) => [delivery.id, delivery]));
  return offers.map((offer) => ({ ...offer, delivery: deliveryById.get(offer.deliveryId) || null }));
}

async function courierDeliveries(delivererId) {
  const orders = await prisma.order.findMany({
    where: {
      delivererId,
      deletedAt: null,
    },
    orderBy: { orderedAt: 'desc' },
    take: 100,
  });
  const orderIds = orders.filter((o) => Number.isInteger(o.orderId)).map((o) => o.orderId);
  const deliveriesById = new Map();
  if (orderIds.length) {
    const rows = await prisma.delivery.findMany({ where: { orderId: { in: orderIds } } });
    for (const d of rows) deliveriesById.set(d.orderId, d);
  }
  const now = new Date();
  return orders.map((order) => {
    const delivery = deliveriesById.get(order.orderId);
    const num = (value, fallback = 0) => {
      if (value === null || value === undefined) return fallback;
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : fallback;
    };
    const dateCommande = order.orderedAt || order.legacyOrderedAt || order.createdAt || now;
    const deliveryStatus =
      (delivery && delivery.status) ||
      order.deliveryStatus ||
      order.livraisonStatus ||
      order.status ||
      '';
    return {
      commandeID: order.orderId ?? order.id,
      userID: order.userId ?? order.legacyUserId ?? 0,
      restauID: order.restaurantId ?? order.legacyRestaurantId ?? 0,
      restaurateurID: order.restaurateurId ?? order.legacyRestaurateurId ?? 0,
      moyenPaiementID: order.paymentMethodId ?? 0,
      fraisLivraison: num(order.legacyDeliveryFee ?? order.deliveryFee),
      reduction: num(order.reduction),
      dateCommande: dateCommande.toISOString(),
      heure: order.orderedTime ?? null,
      addressID: order.deliveryAddressId ?? order.addressId ?? null,
      note: num(order.rating, 0),
      status: order.status ?? 'Pending',
      livreurID: delivererId,
      deliveryStatus,
      livreurLat: num(order.delivererLatitude, 0),
      livreurLng: num(order.delivererLongitude, 0),
      totalAmount: num(order.totalAmount),
      deliveryMode: order.deliveryMode ?? null,
      promoCode: order.promoCode ?? null,
      subtotalAmount: num(order.subtotalAmount ?? order.totalAmount),
      country: order.country ?? 'RDC',
      cityID: order.cityId ?? 1,
      distance: delivery?.quotedDistanceKm != null ? num(delivery.quotedDistanceKm) : num(order.deliveryDistanceKm),
      pourboire: num(order.tipAmount),
      paymentStatus: order.paymentProvider ?? null,
      paymentDate: order.createdAt?.toISOString() ?? now.toISOString(),
      delivererBasePay: num(order.delivererBasePay),
      delivererDistancePay: num(order.delivererDistancePay),
      delivererEarningsStatus: order.delivererEarningsStatus ?? null,
      // Embarque aussi les dates de la course Delivery pour l'UI livreur
      deliveryAcceptedAt: delivery?.acceptedAt?.toISOString() ?? null,
      deliveryPickedUpAt: delivery?.pickedUpAt?.toISOString() ?? null,
      deliveryDeliveredAt: delivery?.deliveredAt?.toISOString() ?? null,
    };
  });
}

module.exports = {
  acceptOffer,
  advanceDelivery,
  courierDeliveries,
  courierOffers,
  offerDelivery,
  rejectOffer,
  startDispatchForOrder,
};
