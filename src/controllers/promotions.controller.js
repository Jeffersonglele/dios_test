const prisma = require('../config/prisma');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');
const { createCrudController } = require('./crud.controller');

const PROMO_FIELDS = [
  'code', 'description', 'discountPercent', 'discountFixed', 'minOrder',
  'validFrom', 'validUntil', 'active', 'maxUses', 'usedCount',
];

const promoCode = createCrudController({
  delegate: 'promoCode',
  resource: 'Code promotionnel',
  fields: PROMO_FIELDS,
  filterFields: ['active', 'code'],
});

async function validatePromo(req, res, next) {
  try {
    const { code, subtotal, deliveryFee } = req.body;
    if (!code) throw badRequest('Le code promo est requis.');
    
    const promo = await prisma.promoCode.findUnique({
      where: { code: code.toUpperCase() },
    });

    if (!promo || !promo.active || promo.deletedAt) {
      throw notFound('Code promotionnel invalide ou inactif');
    }

    if (promo.validUntil && promo.validUntil < new Date()) {
      throw badRequest('Ce code promotionnel a expiré.');
    }

    if (promo.validFrom && promo.validFrom > new Date()) {
      throw badRequest('Ce code promotionnel n\'est pas encore valide.');
    }

    if (promo.maxUses && promo.usedCount >= promo.maxUses) {
      throw badRequest('Ce code promotionnel a atteint sa limite d\'utilisation.');
    }

    const orderAmount = Number(subtotal) || 0;
    if (promo.minOrder && orderAmount < Number(promo.minOrder)) {
      throw badRequest(`Le montant minimum pour ce code est de ${promo.minOrder}.`);
    }

    let discountAmount = 0;
    if (promo.discountPercent && promo.discountPercent > 0) {
      discountAmount = orderAmount * (promo.discountPercent / 100);
    } else if (promo.discountFixed && promo.discountFixed > 0) {
      discountAmount = Number(promo.discountFixed);
    }

    discountAmount = Math.min(discountAmount, orderAmount);

    return res.status(200).json({
      success: true,
      data: {
        code: promo.code,
        description: promo.description,
        discountPercent: promo.discountPercent,
        discountFixed: Number(promo.discountFixed) || 0,
        discountAmount,
        discount: discountAmount,
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function createReferral(req, res, next) {
  try {
    const { userID } = req.body;
    if (!userID) throw badRequest('L\'identifiant de l\'utilisateur est requis.');
    const code = `REF-${userID}-${Math.random().toString(36).substring(2, 7).toUpperCase()}`;
    const promo = await prisma.promoCode.create({
      data: {
        code,
        description: 'Code de parrainage',
        discountFixed: 5.0, // Fixed amount for referral
        active: true,
      }
    });
    return res.status(201).json({ success: true, data: promo });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function applyReferral(req, res, next) {
  try {
    const { code, newUserID } = req.body;
    if (!code || !newUserID) throw badRequest('Le code et le nouvel identifiant sont requis.');
    
    const promo = await prisma.promoCode.findUnique({
      where: { code: code.toUpperCase() },
    });

    if (!promo || !promo.active || promo.deletedAt) {
      throw notFound('Code promotionnel invalide ou inactif');
    }

    // Usually, apply referral gives discount to both users, for now just update count
    await prisma.promoCode.update({
      where: { id: promo.id },
      data: { usedCount: { increment: 1 } },
    });

    return res.status(200).json({ success: true, data: { applied: true } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  promoCode: {
    ...promoCode,
    validatePromo,
    createReferral,
    applyReferral,
  },
};
