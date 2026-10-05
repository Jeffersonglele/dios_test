const prisma = require('../config/prisma');

/**
 * Vérifie si un utilisateur est autorisé à accéder au chat d'une commande
 * (Client, Livreur assigné, ou Propriétaire du restaurant).
 */
async function canAccessOrderChat(order, userId, roleId) {
  if (!order || !userId) return false;

  // 1. Client de la commande
  if (order.userId === userId || order.legacyUserId === userId) {
    return true;
  }

  // 2. Livreur assigné
  if (order.delivererId === userId) {
    return true;
  }

  const delivery = await prisma.delivery.findFirst({
    where: { orderId: order.orderId },
    select: { delivererId: true },
  });
  if (delivery?.delivererId === userId) {
    return true;
  }

  // 3. Restaurateur
  if (order.restaurateurId === userId || order.legacyRestaurateurId === userId) {
    return true;
  }

  if (order.restaurantId) {
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { restaurantID: order.restaurantId },
          { id: String(order.restaurantId) },
        ],
        deletedAt: null,
      },
      select: { userID: true },
    });
    if (restaurant?.userID === userId) {
      return true;
    }
  }

  // 4. Admin (rôle ID 1 ou 2)
  if (roleId === 1 || roleId === 2) {
    return true;
  }

  return false;
}

/**
 * Récupère l'historique des messages d'une commande.
 * GET /api/v1/chat/orders/:orderId/messages
 */
async function getOrderMessages(req, res, next) {
  try {
    const { orderId } = req.params;
    const userId = req.auth?.userId || req.user?.userId;
    const roleId = req.auth?.roleId || req.user?.roleId;

    if (!userId) {
      const error = new Error('Authentification requise.');
      error.statusCode = 401;
      throw error;
    }

    const parsedOrderId = Number.parseInt(orderId, 10);
    const order = await prisma.order.findFirst({
      where: {
        OR: [
          ...(Number.isInteger(parsedOrderId) ? [{ orderId: parsedOrderId }] : []),
          { id: String(orderId) },
        ],
        deletedAt: null,
      },
      select: {
        id: true,
        orderId: true,
        userId: true,
        legacyUserId: true,
        restaurantId: true,
        restaurateurId: true,
        legacyRestaurateurId: true,
        delivererId: true,
      },
    });

    if (!order) {
      const error = new Error('Commande introuvable.');
      error.statusCode = 404;
      throw error;
    }

    const authorized = await canAccessOrderChat(order, userId, roleId);
    if (!authorized) {
      const error = new Error('Accès non autorisé à cette discussion.');
      error.statusCode = 403;
      throw error;
    }

    const messages = await prisma.message.findMany({
      where: {
        orderId: order.orderId,
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    return res.status(200).json({
      data: messages,
      orderId: order.orderId,
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  canAccessOrderChat,
  getOrderMessages,
};
