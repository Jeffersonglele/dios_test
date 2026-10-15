const prisma = require('../config/prisma');
const { badRequest, conflict, handleControllerError } = require('./controller.utils');

// Cibles d'un avis (mêmes codes que l'application) :
// 1 = restaurant, 2 = plat, 3 = livreur.
const TARGETS = { RESTAURANT: 1, DISH: 2, COURIER: 3 };
const DELIVERED_STATUSES = ['DELIVERED', 'COMPLETED', 'LIVREE', 'LIVRÉE'];

function isDelivered(order) {
  return DELIVERED_STATUSES.includes(String(order.status || '').toUpperCase())
    || String(order.deliveryStatus || '').toUpperCase() === 'DELIVERED';
}

/// Pseudo affiché : « Prénom N. », jamais le nom complet ni l'email.
function publicName(user) {
  const first = String(user?.firstname || '').trim();
  const last = String(user?.lastname || '').trim();
  if (first) return last ? `${first} ${last[0].toUpperCase()}.` : first;
  return String(user?.username || 'Client').trim();
}

function parseTarget(query) {
  const targetType = Number.parseInt(query.targetType ?? query.target, 10);
  const targetId = Number.parseInt(query.targetId ?? query.targetID, 10);
  if (!Object.values(TARGETS).includes(targetType) || !Number.isInteger(targetId)) {
    throw badRequest('targetType (1, 2 ou 3) et targetId sont obligatoires.');
  }
  return { targetType, targetId };
}

function serializeReview(comment) {
  return {
    id: comment.id,
    userId: comment.userId,
    targetType: comment.target,
    targetId: comment.targetId,
    orderId: comment.orderId,
    rating: comment.rating,
    comment: comment.description || '',
    tags: Array.isArray(comment.tags) ? comment.tags : [],
    username: comment.username || 'Client',
    createdAt: comment.createdAt,
  };
}

/// Commande livrée du client qui justifie l'avis (anti faux avis).
async function findEligibleOrder({ userId, targetType, targetId, orderId }) {
  const where = { userId, deletedAt: null };
  if (Number.isInteger(orderId)) where.orderId = orderId;
  if (targetType === TARGETS.RESTAURANT) where.restaurantId = targetId;
  if (targetType === TARGETS.COURIER) where.delivererId = targetId;

  const orders = await prisma.order.findMany({ where, orderBy: { orderedAt: 'desc' }, take: 50 });
  for (const order of orders) {
    if (!isDelivered(order)) continue;
    if (targetType !== TARGETS.DISH) return order;
    const line = await prisma.orderLine.findFirst({
      where: { orderId: String(order.orderId), dishId: targetId, deletedAt: null },
      select: { id: true },
    });
    if (line) return order;
  }
  return null;
}

/// Recalcule la note moyenne stockée sur le restaurant ou le plat.
async function refreshAverage(tx, targetType, targetId) {
  if (targetType !== TARGETS.RESTAURANT && targetType !== TARGETS.DISH) return null;
  const agg = await tx.comment.aggregate({
    where: { target: targetType, targetId, rating: { not: null }, deletedAt: null },
    _avg: { rating: true },
  });
  const average = agg._avg.rating == null ? null : Math.round(agg._avg.rating * 10) / 10;
  if (targetType === TARGETS.RESTAURANT) {
    await tx.restaurant.updateMany({ where: { restaurantId: targetId }, data: { rating: average } });
  } else {
    await tx.dish.updateMany({ where: { dishId: targetId }, data: { rating: average } });
  }
  return average;
}

/// POST /reviews { targetType, targetId, rating, comment?, tags?, orderId? }
async function createReview(req, res, next) {
  try {
    const userId = req.auth.userId;
    const { targetType, targetId } = parseTarget(req.body);
    const rating = Number.parseInt(req.body.rating ?? req.body.note, 10);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw badRequest('La note doit être un entier entre 1 et 5.');
    }
    const text = String(req.body.comment ?? req.body.commentaire ?? '').trim().slice(0, 1000);
    const tags = Array.isArray(req.body.tags)
      ? [...new Set(req.body.tags.map((t) => String(t).trim()).filter(Boolean))].slice(0, 8)
      : [];
    const requestedOrderId = Number.parseInt(req.body.orderId, 10);

    const order = await findEligibleOrder({
      userId,
      targetType,
      targetId,
      orderId: Number.isInteger(requestedOrderId) ? requestedOrderId : undefined,
    });
    if (!order) {
      throw badRequest('Vous pourrez donner votre avis une fois une commande livrée.');
    }

    const existing = await prisma.comment.findFirst({
      where: { userId, target: targetType, targetId, orderId: order.orderId, deletedAt: null },
      select: { id: true },
    });
    if (existing) throw conflict('Vous avez déjà donné votre avis pour cette commande.');

    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    const result = await prisma.$transaction(async (tx) => {
      const created = await tx.comment.create({
        data: {
          userId,
          target: targetType,
          targetId,
          orderId: order.orderId,
          rating,
          description: text || null,
          tags,
          username: publicName(user),
        },
      });
      const average = await refreshAverage(tx, targetType, targetId);
      return { created, average };
    });

    return res.status(201).json({
      data: { review: serializeReview(result.created), average: result.average },
    });
  } catch (error) {
    if (error?.code === 'P2002') {
      return next(conflict('Vous avez déjà donné votre avis pour cette commande.'));
    }
    return handleControllerError(error, next);
  }
}

/// GET /reviews?targetType=&targetId=&limit=&skip=
async function listReviews(req, res, next) {
  try {
    const { targetType, targetId } = parseTarget(req.query);
    const take = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 10, 1), 50);
    const skip = Math.max(Number.parseInt(req.query.skip, 10) || 0, 0);
    const where = { target: targetType, targetId, deletedAt: null };
    const [rows, total] = await Promise.all([
      prisma.comment.findMany({ where, orderBy: { createdAt: 'desc' }, take, skip }),
      prisma.comment.count({ where }),
    ]);
    return res.status(200).json({ data: rows.map(serializeReview), meta: { total, limit: take, skip } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// GET /reviews/summary?targetType=&targetId=
/// Note moyenne, nombre d'avis et étiquettes les plus citées (en %).
async function reviewSummary(req, res, next) {
  try {
    const { targetType, targetId } = parseTarget(req.query);
    const where = { target: targetType, targetId, deletedAt: null };
    const rows = await prisma.comment.findMany({ where, select: { rating: true, tags: true } });
    const rated = rows.filter((r) => Number.isInteger(r.rating));
    const note = rated.length
      ? Math.round((rated.reduce((sum, r) => sum + r.rating, 0) / rated.length) * 10) / 10
      : 0;
    const counts = new Map();
    for (const row of rows) {
      for (const tag of Array.isArray(row.tags) ? row.tags : []) {
        counts.set(tag, (counts.get(tag) || 0) + 1);
      }
    }
    const characteristics = [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
      .map(([tag, count]) => ({ tag, count, pct: Math.round((count / rows.length) * 100) }));
    return res.status(200).json({ data: { note, count: rows.length, characteristics } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { createReview, listReviews, reviewSummary, TARGETS };

