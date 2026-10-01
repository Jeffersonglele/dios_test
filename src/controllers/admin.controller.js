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

    let proDocumentsCount;
    let deliveryDocumentsCount;
    if (country) {
      const countryUserIds = (
        await m.user.findMany({ where: userWhere, select: { userId: true, id: true } })
      )
        .map((u) => u.userId)
        .filter((v) => v !== null && v !== undefined);
      const countryRestauIds = (
        await m.restaurant.findMany({ where: restauWhere, select: { restaurantId: true, id: true } })
      )
        .map((r) => r.restaurantId)
        .filter((v) => v !== null && v !== undefined);

      const proWhere = {
        OR: [
          { userId: { in: countryUserIds } },
          { restaurantId: { in: countryRestauIds } },
        ],
      };
      if (countryUserIds.length === 0 && countryRestauIds.length === 0) {
        proDocumentsCount = 0;
      } else if (countryUserIds.length === 0) {
        proDocumentsCount = await m.proDocument.count({ where: { restaurantId: { in: countryRestauIds } } });
      } else if (countryRestauIds.length === 0) {
        proDocumentsCount = await m.proDocument.count({ where: { userId: { in: countryUserIds } } });
      } else {
        proDocumentsCount = await m.proDocument.count({ where: proWhere });
      }

      if (countryUserIds.length === 0) {
        deliveryDocumentsCount = 0;
      } else {
        deliveryDocumentsCount = await m.identity.count({
          where: { deletedAt: null, userId: { in: countryUserIds } },
        });
      }
    } else {
      proDocumentsCount = await m.proDocument.count();
      deliveryDocumentsCount = await m.identity.count({ where: { deletedAt: null } });
    }

    const categoriesCount = await m.category.count({ where: { deletedAt: null } });
    const promoCodesCount = await m.promoCode.count({ where: { deletedAt: null } });

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

    let docs;
    if (country) {
      const userWhere = { deletedAt: null, country: country };
      const restauWhere = { deletedAt: null, country: country };
      const countryUserIds = (
        await m.user.findMany({ where: userWhere, select: { userId: true } })
      )
        .map((u) => u.userId)
        .filter((v) => v !== null && v !== undefined);
      const countryRestauIds = (
        await m.restaurant.findMany({ where: restauWhere, select: { restaurantId: true } })
      )
        .map((r) => r.restaurantId)
        .filter((v) => v !== null && v !== undefined);

      const where = {};
      const orParts = [];
      if (countryUserIds.length > 0) orParts.push({ userId: { in: countryUserIds } });
      if (countryRestauIds.length > 0) orParts.push({ restaurantId: { in: countryRestauIds } });
      if (orParts.length === 1) Object.assign(where, orParts[0]);
      else if (orParts.length > 1) where.OR = orParts;

      if (orParts.length === 0) {
        docs = [];
      } else {
        docs = await m.proDocument.findMany({ where });
      }
    } else {
      docs = await m.proDocument.findMany();
    }

    const userIds = [...new Set(docs.map((d) => d.userId).filter((v) => v !== null && v !== undefined))];
    const restauIds = [...new Set(docs.map((d) => d.restaurantId).filter((v) => v !== null && v !== undefined))];
    const usersMap = new Map();
    const restaurantsMap = new Map();
    if (userIds.length > 0) {
      (await m.user.findMany({ where: { userId: { in: userIds } } })).forEach((u) => usersMap.set(u.userId, u));
    }
    if (restauIds.length > 0) {
      (await m.restaurant.findMany({ where: { restaurantId: { in: restauIds } } })).forEach((r) => restaurantsMap.set(r.restaurantId, r));
    }
    const data = docs.map((d) => {
      const copy = { ...d };
      if (d.userId !== null && d.userId !== undefined) copy.user = usersMap.get(d.userId) || null;
      if (d.restaurantId !== null && d.restaurantId !== undefined) copy.restaurant = restaurantsMap.get(d.restaurantId) || null;
      return copy;
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

    let identities;
    if (country) {
      const userWhere = { deletedAt: null, country: country };
      const countryUserIds = (
        await m.user.findMany({ where: userWhere, select: { userId: true } })
      )
        .map((u) => u.userId)
        .filter((v) => v !== null && v !== undefined);

      if (countryUserIds.length === 0) {
        identities = [];
      } else {
        identities = await m.identity.findMany({
          where: { deletedAt: null, userId: { in: countryUserIds } },
        });
      }
    } else {
      identities = await m.identity.findMany({ where: { deletedAt: null } });
    }

    const userIds = [...new Set(identities.map((d) => d.userId).filter((v) => v !== null && v !== undefined))];
    const usersMap = new Map();
    if (userIds.length > 0) {
      (await m.user.findMany({ where: { userId: { in: userIds } } })).forEach((u) => usersMap.set(u.userId, u));
    }
    const data = identities.map((d) => {
      const copy = { ...d };
      if (d.userId !== null && d.userId !== undefined) copy.user = usersMap.get(d.userId) || null;
      return copy;
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

async function getAvailableCountries(req, res, next) {
  try {
    const m = _model();
    // Récupère les valeurs distinctes du champ country dans la table users
    const rows = await m.user.findMany({
      where: { deletedAt: null, country: { isNotNull: true } },
      select: { country: true },
      distinct: ['country'],
    });
    // Filtre les valeurs vides et déduplique (insensible à la casse)
    const seen = new Set();
    const countries = [];
    for (const row of rows) {
      const c = (row.country || '').trim();
      const key = c.toLowerCase();
      if (c && !seen.has(key)) {
        seen.add(key);
        countries.push(c);
      }
    }
    return res.status(200).json({ data: countries });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getUserDetailsByLegacyId(req, res, next) {
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
      const err = new Error('Utilisateur introuvable.');
      err.statusCode = 404;
      throw err;
    }
    const { password, ...safeUser } = user;
    const identity = await m.identity.findFirst({
      where: { userId: user.userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    const restaurant = await m.restaurant.findFirst({
      where: { userId: user.userId, deletedAt: null },
    });
    return res.status(200).json({
      data: {
        user: safeUser,
        identity: identity || null,
        restaurant: restaurant || null,
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateUserProfileByLegacyId(req, res, next) {
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
      const err = new Error('Utilisateur introuvable.');
      err.statusCode = 404;
      throw err;
    }
    const allowedFields = ['firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal', 'telephoneE164', 'image'];
    const data = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) data[field] = req.body[field];
    }
    const updated = await m.user.update({ where: { id: user.id }, data });
    if (data.firstname !== undefined || data.lastname !== undefined || data.username !== undefined || data.email !== undefined || data.telephone !== undefined || data.image !== undefined) {
      await prisma.authUser.updateMany({
        where: { legacyUserId: user.userId },
        data: {
          ...(data.firstname !== undefined && { firstname: data.firstname }),
          ...(data.lastname !== undefined && { lastname: data.lastname }),
          ...(data.username !== undefined && { username: data.username }),
          ...(data.email !== undefined && { email: data.email }),
          ...(data.telephone !== undefined && { telephone: data.telephone }),
          ...(data.telephoneLocal !== undefined && { telephoneLocal: data.telephoneLocal }),
          ...(data.telephoneE164 !== undefined && { telephoneE164: data.telephoneE164 }),
          ...(data.image !== undefined && { image: data.image }),
        },
      });
    }
    const { password, ...safeUpdated } = updated;
    return res.status(200).json({ data: safeUpdated });
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
  getAvailableCountries,
  getUserDetailsByLegacyId,
  updateUserProfileByLegacyId,
};
