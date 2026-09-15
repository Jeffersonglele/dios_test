const { Prisma } = require('@prisma/client');

const prisma = require('../config/prisma');
const { badRequest, conflict, notFound } = require('../controllers/controller.utils');

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
        deliveryId: delivery.id,
        delivererId: Number(courier.delivererId),
        rank: index + 1,
        distanceToPickupKm: Number(courier.distanceToPickupKm),
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
  if (!order || !Number.isInteger(order.orderId)) throw badRequest('La commande est invalide.');
  const pickup = order.pickupSnapshot;
  const destination = order.deliveryAddressSnapshot;
  if (!order.cityId || !pickup || !destination) {
    throw badRequest('La commande doit contenir un devis et des points de retrait/livraison validés.');
  }

  const existing = await prisma.delivery.findFirst({ where: { orderId: order.orderId } });
  const delivery = existing || await prisma.delivery.create({
    data: {
      orderId: order.orderId,
      cityId: order.cityId,
      restaurantId: order.restaurantId,
      pickupLatitude: Number(pickup.latitude),
      pickupLongitude: Number(pickup.longitude),
      deliveryLatitude: Number(destination.latitude),
      deliveryLongitude: Number(destination.longitude),
      quotedDistanceKm: Number(order.deliveryDistanceKm),
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
  ASSIGNED: ['AT_PICKUP'],
  AT_PICKUP: ['PICKED_UP'],
  PICKED_UP: ['IN_TRANSIT'],
  IN_TRANSIT: ['DELIVERED'],
});

async function advanceDelivery({ deliveryId, delivererId, status }) {
  const nextStatus = String(status || '').toUpperCase();
  const delivery = await prisma.delivery.findFirst({ where: { id: deliveryId, delivererId } });
  if (!delivery) throw notFound('Livraison');
  if (!(STATUS_TRANSITIONS[delivery.status] || []).includes(nextStatus)) {
    throw conflict(`Transition impossible de ${delivery.status} vers ${nextStatus}.`);
  }
  const timestamps = {
    ...(nextStatus === 'PICKED_UP' ? { pickedUpAt: new Date() } : {}),
    ...(nextStatus === 'DELIVERED' ? { deliveredAt: new Date() } : {}),
  };
  const updated = await prisma.delivery.update({ where: { id: delivery.id }, data: { status: nextStatus, ...timestamps } });
  if (nextStatus === 'DELIVERED') {
    await prisma.$transaction([
      prisma.user.updateMany({ where: { userId: delivererId, deletedAt: null }, data: { courierStatus: 'ACTIVE' } }),
      prisma.order.updateMany({
        where: { orderId: delivery.orderId, deletedAt: null },
        data: { status: 'LIVREE', orderStatus: 'LIVREE', deliveryStatus: 'DELIVERED' },
      }),
    ]);
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
  return prisma.delivery.findMany({
    where: { delivererId }, orderBy: { updatedAt: 'desc' }, take: 50,
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
