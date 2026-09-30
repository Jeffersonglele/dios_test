const prisma = require('../config/prisma');
const { handleControllerError } = require('./controller.utils');

async function getDashboardStats(req, res, next) {
  try {
    const country = req.query.country;
    
    const userWhere = { deletedAt: null };
    if (country) userWhere.country = country;

    const restaurantWhere = { deletedAt: null };
    if (country) restaurantWhere.country = country;

    // Calcul du début du mois
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const newUsersWhere = { ...userWhere, createdAt: { gte: startOfMonth } };

    const [
      totalUsers,
      totalRestaurants,
      newUsersThisMonth,
      ordersConfirmed,
      ordersPending,
    ] = await Promise.all([
      prisma.user.count({ where: userWhere }),
      prisma.restaurant.count({ where: restaurantWhere }),
      prisma.user.count({ where: newUsersWhere }),
      // status in ['CONFIRMED', 'DELIVERED', 'IN_TRANSIT', 'PREPARING']
      prisma.order.count({ where: { status: { in: ['CONFIRMED', 'DELIVERED', 'IN_TRANSIT', 'PREPARING'] } } }),
      prisma.order.count({ where: { status: 'PENDING' } }),
    ]);

    // totalRevenue (exemple simplifié: somme de totalAmount pour les livrées)
    const revenueResult = await prisma.order.aggregate({
      _sum: { totalAmount: true },
      where: { status: 'DELIVERED' }
    });

    const totalRevenue = revenueResult._sum.totalAmount || 0;

    return res.status(200).json({
      success: true,
      stats: {
        totalUsers,
        totalRestaurants,
        newUsersThisMonth,
        totalOrders: ordersConfirmed,
        pendingOrders: ordersPending,
        totalRevenue
      }
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function validateRestaurant(req, res, next) {
  try {
    const restaurantId = Number.parseInt(req.params.restaurantId, 10);
    const valid = req.body.valid;
    const reviewRemark = req.body.reviewRemark;

    const restaurant = await prisma.restaurant.findUnique({ where: { restaurantId } });
    if (!restaurant) throw notFound('Restaurant');

    const updated = await prisma.restaurant.update({
      where: { restaurantId },
      data: { valid, reviewRemark }
    });

    return res.status(200).json({ success: true, data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setIdentityStatus(req, res, next) {
  try {
    const userId = Number.parseInt(req.params.userId, 10);
    const status = req.body.status; // e.g. "APPROVED", "REJECTED"

    const user = await prisma.user.findUnique({ where: { userId } });
    if (!user) throw notFound('User');

    const updated = await prisma.user.update({
      where: { userId },
      data: { status }
    });

    return res.status(200).json({ success: true, data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  getDashboardStats,
  validateRestaurant,
  setIdentityStatus,
};
