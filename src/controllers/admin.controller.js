const { handleControllerError } = require('./controller.utils');
const prisma = require('../config/prisma');

async function getDashboardStats(req, res, next) {
  try {
    const usersCount = await prisma.users.count({ where: { deletedAt: null } });
    const ordersCount = await prisma.commande.count();
    const proDocumentsCount = await prisma.proDocument.count();
    const categoriesCount = await prisma.category.count({ where: { deletedAt: null } });
    const promoCodesCount = await prisma.promoCode.count({ where: { deletedAt: null } });
    const deliveryDocumentsCount = await prisma.identity.count({ where: { deletedAt: null, documentType: 'DRIVER' } });
    const referralCount = await prisma.promoCode.count({ where: { deletedAt: null, description: 'Code de parrainage' } });
    const scheduledDeletionsCount = await prisma.users.count({ where: { isDeleted: 1 } });
    const auditLogCount = await prisma.auditLog.count();

    const data = {
      users: usersCount,
      orders: ordersCount,
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
    const data = await prisma.proDocument.findMany({
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
    const { documentId, status } = req.body;
    const document = await prisma.proDocument.update({
      where: { id: documentId },
      data: { status },
    });
    return res.status(200).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getDeliveryDocuments(req, res, next) {
  try {
    // Identity with documentType = 'DRIVER' (if that's how it's modelled)
    const data = await prisma.identity.findMany({
      where: { documentType: 'DRIVER' }, // Need to adapt to actual schema
      include: { user: true },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function validateDeliveryDocuments(req, res, next) {
  try {
    const { documentId, status } = req.body;
    const document = await prisma.identity.update({
      where: { id: documentId },
      data: { status },
    });
    return res.status(200).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getScheduledDeletions(req, res, next) {
  try {
    const data = await prisma.users.findMany({
      where: { isDeleted: 1 },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getReferralStats(req, res, next) {
  try {
    const activeCodes = await prisma.promoCode.count({ where: { deletedAt: null, active: true, description: 'Code de parrainage' } });
    const allCodes = await prisma.promoCode.findMany({ where: { deletedAt: null, description: 'Code de parrainage' } });
    
    let totalReferrals = 0;
    for (const code of allCodes) {
      totalReferrals += code.usedCount;
    }

    return res.status(200).json({
      data: {
        totalReferrals,
        activeCodes,
        rewardsGiven: totalReferrals * 5, // Just an example
      }
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function sendEmail(req, res, next) {
  try {
    // Mock email sending
    return res.status(200).json({ success: true, message: 'Email envoyé' });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function forceDeleteUser(req, res, next) {
  try {
    const { userId } = req.params;
    await prisma.users.delete({ where: { userId: Number(userId) } });
    return res.status(200).json({ success: true });
  } catch (error) {
    return handleControllerError(error, next);
  }
}
async function validateRestaurant(req, res, next) {
  try {
    const { restaurantId } = req.params;
    const { valid, reviewRemark } = req.body;
    const data = await prisma.restaurant.update({
      where: { restaurantId: Number(restaurantId) },
      data: { valid: Number(valid), ...(reviewRemark ? { reviewRemark } : {}) },
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setIdentityStatus(req, res, next) {
  try {
    const { userId } = req.params;
    const { status } = req.body;
    const data = await prisma.users.update({
      where: { userId: Number(userId) },
      data: { identityStatus: status },
    });
    return res.status(200).json({ data });
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
