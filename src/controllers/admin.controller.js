const { handleControllerError, canonicalCountry } = require('./controller.utils');
const prisma = require('../config/prisma');

function _model() {
  return {
    user: prisma.user || prisma.users,
    order: prisma.order || prisma.commande || prisma.orders,
    restaurant: prisma.restaurant || prisma.restaurants,
    category: prisma.category || prisma.categories,
    promoCode: prisma.promoCode || prisma.promoCodes,
    identity: prisma.identity || prisma.identities,
    proDocument: prisma.proDocument || prisma.proDocuments,
    auditLog: prisma.auditLog || prisma.auditLogs,
  };
}

async function getDashboardStats(req, res, next) {
  try {
    const m = _model();
    const countryRaw = req.query?.country;
    const country = countryRaw ? canonicalCountry(countryRaw) : null;

    const userWhere = { deletedAt: null };
    if (country) userWhere.country = country;
    const usersCount = await m.user.count({ where: userWhere });

    const orderWhere = { deletedAt: null };
    if (country) orderWhere.country = country;
    const ordersCount = await m.order.count({ where: orderWhere });

    const restauWhere = { deletedAt: null };
    if (country) restauWhere.country = country;
    const restaurantsCount = await m.restaurant.count({ where: restauWhere });

    const proDocsWhere = {};
    if (country) {
      proDocsWhere.OR = [
        { country: country },
        { user: { country: country } },
        { restaurant: { country: country } },
      ];
    }
    const proDocumentsCount = await m.proDocument.count({ where: proDocsWhere });

    const categoriesCount = await m.category.count({ where: { deletedAt: null } });
    const promoCodesCount = await m.promoCode.count({ where: { deletedAt: null } });

    const deliveryDocsWhere = { deletedAt: null };
    if (country) {
      deliveryDocsWhere.user = { country: country };
    }
    const deliveryDocumentsCount = await m.identity.count({ where: deliveryDocsWhere });

    const referralCount = await m.promoCode.count({
      where: {
        deletedAt: null,
        description: { contains: 'parrainage', mode: 'insensitive' },
      },
    });

    const scheduledDeletionsCount = 0;

    const auditLogWhere = {};
    if (country) auditLogWhere.country = country;
    const auditLogCount = await m.auditLog.count({ where: auditLogWhere });

    const revenueAgg = await m.order.aggregate({
      where: {
        ...orderWhere,
        status: { in: ['confirmed', 'Confirmed', 'CONFIRMED', 'delivered', 'Delivered', 'DELIVERED', 'paid', 'Paid', 'PAID'] },
      },
      _sum: { totalAmount: true },
    });
    const totalRevenue = Number(revenueAgg?._sum?.totalAmount ?? 0);

    const confirmedCount = await m.order.count({
      where: {
        ...orderWhere,
        status: { in: ['confirmed', 'Confirmed', 'CONFIRMED', 'delivered', 'Delivered', 'DELIVERED', 'paid', 'Paid', 'PAID'] },
      },
    });

    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);
    const newUsersThisMonth = await m.user.count({
      where: {
        ...userWhere,
        createdAt: { gte: startOfMonth },
      },
    });

    const data = {
      totalUsers: usersCount,
      users: usersCount,
      totalOrders: confirmedCount,
      orders: ordersCount,
      totalRestaurants: restaurantsCount,
      restaurants: restaurantsCount,
      totalRevenue,
      newUsersThisMonth,
      proDocuments: proDocumentsCount,
      categories: categoriesCount,
      promoCodes: promoCodesCount,
      deliveryDocuments: deliveryDocumentsCount,
      referralCount,
      scheduledDeletionsCount,
      auditLogCount,
    };

    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getProDocuments(req, res, next) {
  try {
    const m = _model();
    const countryRaw = req.query?.country;
    const country = countryRaw ? canonicalCountry(countryRaw) : null;
    const where = {};
    if (country) {
      where.OR = [
        { country: country },
        { user: { country: country } },
        { restaurant: { country: country } },
      ];
    }
    const data = await m.proDocument.findMany({
      where,
      include: {
        restaurant: true,
        user: true,
      },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function validateProDocuments(req, res, next) {
  try {
    const m = _model();
    const { documentId, status } = req.body;
    let whereClause;
    try {
      whereClause = { id: documentId };
      await m.proDocument.update({ where: whereClause, data: {} });
    } catch (_) {
      const docIdNum = Number(documentId);
      if (Number.isInteger(docIdNum)) whereClause = { documentId: docIdNum };
    }
    const document = await m.proDocument.update({
      where: whereClause,
      data: { status },
    });
    return res.status(200).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getDeliveryDocuments(req, res, next) {
  try {
    const m = _model();
    const countryRaw = req.query?.country;
    const country = countryRaw ? canonicalCountry(countryRaw) : null;
    const where = { deletedAt: null };
    if (country) {
      where.user = { country: country };
    }
    const data = await m.identity.findMany({
      where,
      include: { user: true },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function validateDeliveryDocuments(req, res, next) {
  try {
    const m = _model();
    const { documentId, status } = req.body;
    let whereClause;
    try {
      whereClause = { id: documentId };
      await m.identity.update({ where: whereClause, data: {} });
    } catch (_) {
      const docIdNum = Number(documentId);
      if (Number.isInteger(docIdNum)) whereClause = { identityId: docIdNum };
    }
    const document = await m.identity.update({
      where: whereClause,
      data: { status },
    });
    return res.status(200).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getScheduledDeletions(req, res, next) {
  try {
    return res.status(200).json({ data: [] });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getReferralStats(req, res, next) {
  try {
    const m = _model();
    const referralWhere = {
      deletedAt: null,
      description: { contains: 'parrainage', mode: 'insensitive' },
    };
    const activeCodes = await m.promoCode.count({
      where: { ...referralWhere, active: true },
    });
    const allCodes = await m.promoCode.findMany({ where: referralWhere });

    let totalReferrals = 0;
    for (const code of allCodes) {
      totalReferrals += Number(code.usedCount || 0);
    }

    return res.status(200).json({
      data: {
        totalReferrals,
        activeCodes,
        rewardsGiven: totalReferrals * 5,
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function sendEmail(req, res, next) {
  try {
    return res.status(200).json({ success: true, message: 'Email envoyé' });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function forceDeleteUser(req, res, next) {
  try {
    const m = _model();
    const { userId } = req.params;
    const legacyUserId = Number(userId);
    let user;
    if (Number.isInteger(legacyUserId)) {
      user = await m.user.findFirst({ where: { userId: legacyUserId, deletedAt: null } });
    }
    if (!user) {
      user = await m.user.findFirst({ where: { id: userId, deletedAt: null } });
    }
    if (!user) {
      return res.status(404).json({ success: false, message: 'Utilisateur introuvable.' });
    }
    await m.user.delete({ where: { id: user.id } });
    return res.status(200).json({ success: true });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function validateRestaurant(req, res, next) {
  try {
    const m = _model();
    const { restaurantId } = req.params;
    const { valid, reviewRemark } = req.body;
    const legacyRestoId = Number(restaurantId);
    let resto;
    if (Number.isInteger(legacyRestoId)) {
      resto = await m.restaurant.findFirst({ where: { restaurantId: legacyRestoId } });
    }
    if (!resto) {
      resto = await m.restaurant.findFirst({ where: { id: restaurantId } });
    }
    if (!resto) {
      const err = new Error('Restaurant introuvable.');
      err.statusCode = 404;
      throw err;
    }
    const data = await m.restaurant.update({
      where: { id: resto.id },
      data: { valid: Number(valid), ...(reviewRemark ? { reviewRemark } : {}) },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setIdentityStatus(req, res, next) {
  try {
    const m = _model();
    const { userId } = req.params;
    const { status } = req.body;
    const legacyUserId = Number(userId);
    let user;
    if (Number.isInteger(legacyUserId)) {
      user = await m.user.findFirst({ where: { userId: legacyUserId, deletedAt: null } });
    }
    if (!user) {
      user = await m.user.findFirst({ where: { id: userId, deletedAt: null } });
    }
    if (!user) {
      const error = new Error('Utilisateur introuvable.');
      error.statusCode = 404;
      throw error;
    }
    const data = await m.user.update({
      where: { id: user.id },
      data: { identity: String(status || '').trim() },
    });
    const { password, ...safeData } = data;
    return res.status(200).json({ data: safeData });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  getDashboardStats,
  sendEmail,
  forceDeleteUser,
  getProDocuments,
  validateProDocuments,
  getDeliveryDocuments,
  validateDeliveryDocuments,
  getScheduledDeletions,
  getReferralStats,
  validateRestaurant,
  setIdentityStatus,
};
