const { badRequest, handleControllerError, canonicalCountry, notFound } = require('./controller.utils');
const { IDENTITY, isIdentityVerified } = require('../services/courier.service');
const {
  adminContext, assertCountryInScope, recordAudit, requireSuperAdmin, scopedCountry,
} = require('../services/admin-scope.service');
const prisma = require('../config/prisma');
const {
  sendSellerApprovedEmail,
  sendSellerRejectedEmail,
  sendRestaurantApprovedEmail,
  sendRestaurantRejectedEmail,
  sendCourierApprovedEmail,
  sendCourierRejectedEmail,
  sendAdminAccountEmail,
  sendDirectMessageEmail,
} = require('../services/email.service');
const bcrypt = require('bcryptjs');
const { randomBytes } = require('crypto');

function restaurateurRoleId() {
  const configured = Number.parseInt(process.env.RESTAURATEUR_ROLE_ID || '3', 10);
  return Number.isInteger(configured) ? configured : 3;
}
function courierRoleId() {
  const configured = Number.parseInt(process.env.COURIER_ROLE_ID || '5', 10);
  return Number.isInteger(configured) ? configured : 5;
}
function adminRoleIds() {
  return String(process.env.ADMIN_ROLE_IDS || '1,4')
    .split(',')
    .map((s) => Number.parseInt(s.trim(), 10))
    .filter((n) => Number.isInteger(n));
}

function _notifyAsync(fn) {
  setImmediate(() => {
    Promise.resolve(fn()).catch((err) => {
      console.error('[admin] Échec envoi email notification', {
        message: err?.message,
        cause: err?.cause?.message,
      });
    });
  });
}

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

/// Chiffre d'affaires et commandes réalisées : commandes livrées.
const DELIVERED_STATUSES = ['DELIVERED', 'LIVREE', 'delivered', 'Delivered'];

async function getDashboardStats(req, res, next) {
  try {
    const m = _model();
    const country = scopedCountry(await adminContext(req), req.query?.country);

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
        status: { in: DELIVERED_STATUSES },
      },
      _sum: { totalAmount: true },
    });
    const totalRevenue = Number(revenueAgg?._sum?.totalAmount ?? 0);

    const confirmedCount = await m.order.count({
      where: {
        ...orderWhere,
        status: { in: DELIVERED_STATUSES },
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
    const country = scopedCountry(await adminContext(req), req.query?.country);

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
    const { documentId, status, remark } = req.body;
    let whereClause;
    try {
      whereClause = { id: documentId };
      await m.proDocument.update({ where: whereClause, data: {} });
    } catch (_) {
      const docIdNum = Number(documentId);
      if (Number.isInteger(docIdNum)) whereClause = { documentId: docIdNum };
    }
    const previous = await m.proDocument.findFirst({ where: whereClause });
    if (!previous) throw notFound('Document professionnel');
    const docOwner = previous.userId != null
      ? await m.user.findFirst({ where: { userId: previous.userId }, select: { country: true } })
      : null;
    assertCountryInScope(await adminContext(req), docOwner?.country);

    const normalizedStatus = String(status || '').trim();
    const isApproved = normalizedStatus === 'approved';
    const isRejected = normalizedStatus === 'rejected';

    const updated = await prisma.$transaction(async (tx) => {
      const docPromise = tx.proDocument.update({
        where: whereClause,
        data: { status: normalizedStatus, ...(remark ? { remark } : {}) },
      });

      let targetUser = null;
      let targetRestaurant = null;
      const legacyUserId = previous.userId;
      const legacyRestoId = previous.restaurantId;

      if (legacyUserId !== null && legacyUserId !== undefined) {
        const found = await tx.user.findFirst({ where: { userId: legacyUserId, deletedAt: null } });
        if (found) targetUser = found;
      }
      if (!targetUser && legacyRestoId !== null && legacyRestoId !== undefined) {
        const resto = await tx.restaurant.findFirst({ where: { restaurantId: legacyRestoId } });
        if (resto) {
          targetRestaurant = resto;
          if (resto.userId !== null && resto.userId !== undefined) {
            const u = await tx.user.findFirst({ where: { userId: resto.userId, deletedAt: null } });
            if (u) targetUser = u;
          }
        }
      }

      if (isApproved) {
        const newRole = restaurateurRoleId();
        const adminIds = adminRoleIds();
        if (targetUser && targetUser.roleId !== newRole && !adminIds.includes(Number(targetUser.roleId))) {
          await tx.user.update({
            where: { id: targetUser.id },
            data: { roleId: newRole, accountType: 'RESTAURATEUR' },
          });
        }
        if (targetRestaurant) {
          await tx.restaurant.update({
            where: { id: targetRestaurant.id },
            data: { isPro: true },
          });
        } else if (legacyRestoId !== null && legacyRestoId !== undefined) {
          const found = await tx.restaurant.findFirst({ where: { restaurantId: legacyRestoId } });
          if (found) {
            await tx.restaurant.update({
              where: { id: found.id },
              data: { isPro: true },
            });
            targetRestaurant = found;
          }
        }
      }

      const doc = await docPromise;
      return { doc, targetUser, targetRestaurant, isApproved, isRejected };
    });

    const { doc, targetUser, targetRestaurant, isApproved: approved, isRejected: rejected } = updated;
    const safeRemark = remark || previous.remark;

    if (targetUser?.email && (approved || rejected)) {
      _notifyAsync(() => approved
        ? sendSellerApprovedEmail({ to: targetUser.email, firstname: targetUser.firstname })
        : sendSellerRejectedEmail({ to: targetUser.email, firstname: targetUser.firstname, reason: safeRemark })
      );
    } else if (!targetUser?.email && (approved || rejected)) {
      console.warn('[admin][validateProDocuments] Aucun email pour notifier l’utilisateur', {
        documentId: doc.id,
        docUserId: previous.userId,
        docRestaurantId: previous.restaurantId,
        status: normalizedStatus,
      });
    }

    await recordAudit(req, `courier_file:${normalizedStatus}`, {
      documentId: doc.id, userId: previous.userId, remark: remark || null,
    });
    return res.status(200).json({ data: doc });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getDeliveryDocuments(req, res, next) {
  try {
    const m = _model();
    const country = scopedCountry(await adminContext(req), req.query?.country);

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
      const user = d.userId !== null && d.userId !== undefined ? usersMap.get(d.userId) || null : null;
      if (user) {
        const { password, ...safeUser } = user;
        copy.user = safeUser;
      } else {
        copy.user = null;
      }
      // Champs lus par l'écran admin « Livreurs ».
      copy.status = d.status === 'approved' ? 'validated' : (d.status || 'pending');
      copy.userName = [user?.firstname, user?.lastname].filter(Boolean).join(' ') || user?.username || '';
      copy.phone = user?.telephone || '';
      copy.idCardUrl = d.identityFileUrl || '';
      copy.licenseUrl = d.licenseUrl || '';
      copy.photoUrl = d.photoUrl || '';
      copy.vehicleType = d.vehicleType || user?.vehicleType || '';
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
    const { documentId, status, remark } = req.body;
    let whereClause;
    try {
      whereClause = { id: documentId };
      await m.identity.update({ where: whereClause, data: {} });
    } catch (_) {
      const docIdNum = Number(documentId);
      if (Number.isInteger(docIdNum)) whereClause = { identityId: docIdNum };
    }
    const previous = await m.identity.findFirst({ where: whereClause });
    if (!previous) throw notFound('Vérification d’identité');
    const fileOwner = previous.userId != null
      ? await m.user.findFirst({ where: { userId: previous.userId }, select: { country: true } })
      : null;
    assertCountryInScope(await adminContext(req), fileOwner?.country);

    // L'app admin envoie VALIDATED / REJECTED ; l'API historique approved / rejected.
    const rawStatus = String(status || '').trim().toLowerCase();
    const normalizedStatus = ['validated', 'approved', 'verified'].includes(rawStatus)
      ? 'approved'
      : ['rejected', 'refused'].includes(rawStatus) ? 'rejected' : null;
    if (!normalizedStatus) throw badRequest('Le statut doit être VALIDATED ou REJECTED.');
    const isApproved = normalizedStatus === 'approved';
    const isRejected = normalizedStatus === 'rejected';

    const updated = await prisma.$transaction(async (tx) => {
      const docPromise = tx.identity.update({
        where: whereClause,
        data: { status: normalizedStatus, ...(remark ? { remark } : {}) },
      });

      let targetUser = null;
      const legacyUserId = previous.userId;
      if (legacyUserId !== null && legacyUserId !== undefined) {
        const found = await tx.user.findFirst({ where: { userId: legacyUserId, deletedAt: null } });
        if (found) targetUser = found;
      }

      if (isApproved && targetUser) {
        const newRole = courierRoleId();
        const adminIds = adminRoleIds();
        if (targetUser.roleId !== newRole && !adminIds.includes(Number(targetUser.roleId))) {
          targetUser = await tx.user.update({
            where: { id: targetUser.id },
            data: { roleId: newRole, accountType: 'LIVREUR', identity: IDENTITY.VERIFIED },
          });
        } else if (targetUser.identity !== IDENTITY.VERIFIED) {
          targetUser = await tx.user.update({
            where: { id: targetUser.id },
            data: { identity: IDENTITY.VERIFIED },
          });
        }
      } else if (isRejected && targetUser) {
        // Refus : le livreur ne peut plus travailler et doit renvoyer un dossier.
        targetUser = await tx.user.update({
          where: { id: targetUser.id },
          data: { identity: IDENTITY.REJECTED, courierStatus: 'INACTIVE' },
        });
      }

      const doc = await docPromise;
      return { doc, targetUser, isApproved, isRejected };
    });

    const { doc, targetUser, isApproved: approved, isRejected: rejected } = updated;
    const safeRemark = remark || previous.remark;

    if (targetUser?.email && (approved || rejected)) {
      _notifyAsync(() => approved
        ? sendCourierApprovedEmail({ to: targetUser.email, firstname: targetUser.firstname })
        : sendCourierRejectedEmail({ to: targetUser.email, firstname: targetUser.firstname, reason: safeRemark })
      );
    } else if (!targetUser?.email && (approved || rejected)) {
      console.warn('[admin][validateDeliveryDocuments] Aucun email pour notifier l’utilisateur', {
        documentId: doc.id,
        docUserId: previous.userId,
        status: normalizedStatus,
      });
    }

    await recordAudit(req, `pro_document:${normalizedStatus}`, {
      documentId: doc.id, userId: previous.userId, remark: remark || null,
    });
    return res.status(200).json({ data: doc });
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
    const to = String(req.body.to || req.body.email || '').trim();
    const subject = String(req.body.subject || '').trim();
    const text = String(req.body.text || req.body.message || req.body.body || '').trim();
    if (!to || !subject || !text) throw badRequest('Destinataire, objet et message sont obligatoires.');
    await sendDirectMessageEmail({ to, subject, text });
    await recordAudit(req, 'email:sent', { to, subject });
    return res.status(200).json({ success: true, message: 'Email envoyé' });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Création d'un administrateur (super admin uniquement). Un mot de passe
/// temporaire est envoyé par email ; il devra être changé à la connexion.
async function createAdmin(req, res, next) {
  try {
    const context = await adminContext(req);
    requireSuperAdmin(context);
    const email = String(req.body.email || '').trim().toLowerCase();
    const username = String(req.body.username || '').trim();
    const firstname = String(req.body.firstname || '').trim() || null;
    const lastname = String(req.body.lastname || '').trim() || null;
    const roleId = Number(req.body.roleId) === 4 ? 4 : 1;
    const country = canonicalCountry(req.body.country) || context.country;
    if (!email || !username) throw badRequest('Email et nom d’utilisateur sont obligatoires.');
    if (!country) throw badRequest('Pays de l’administrateur inconnu.');
    const existing = await prisma.authUser.findFirst({
      where: { OR: [{ email }, { username }] },
    });
    if (existing) {
      const err = new Error('Un compte utilise déjà cet email ou ce nom d’utilisateur.');
      err.statusCode = 409;
      throw err;
    }
    const temporaryPassword = randomBytes(9).toString('base64url');
    const passwordHash = await bcrypt.hash(temporaryPassword, 12);
    const created = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          username, email, firstname, lastname, country, roleId,
          password: passwordHash,
          status: 'Verified',
          identity: 'Verified',
          accountType: 'ADMIN',
          mustChangePassword: true,
          ageConfirmed: true,
        },
      });
      await tx.authUser.create({
        data: {
          username, email, firstname, lastname,
          password: passwordHash,
          emailVerified: true,
          legacyUserId: user.userId,
        },
      });
      return user;
    });
    await sendAdminAccountEmail({
      to: email,
      name: firstname || username,
      accessLabel: roleId === 4 ? 'super administrateur' : `administrateur (${country})`,
      username,
      temporaryPassword,
    }).catch((err) => console.error('[admin] email nouvel admin impossible', { message: err?.message }));
    await recordAudit(req, 'admin:created', { userId: created.userId, email, roleId }, country);
    const { password, ...safeUser } = created;
    return res.status(201).json({ data: safeUser });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Indicateurs du super admin : paiements, commissions et litiges.
async function getSuperAdminStats(req, res, next) {
  try {
    requireSuperAdmin(await adminContext(req));
    const country = req.query?.country ? canonicalCountry(req.query.country) : null;
    const orderIds = country
      ? (await prisma.order.findMany({ where: { country, deletedAt: null }, select: { orderId: true } }))
        .map((o) => o.orderId)
      : null;
    const txWhere = { deletedAt: null, ...(orderIds ? { orderId: { in: orderIds } } : {}) };
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const [completed, pending, commissions, disputes] = await Promise.all([
      prisma.transaction.count({ where: { ...txWhere, status: { in: ['COMPLETED', 'PAID', 'SUCCESS'] } } }),
      prisma.transaction.count({
        where: { ...txWhere, status: { in: ['INITIATED', 'PENDING', 'PENDING_CASH_COLLECTION'] } },
      }),
      prisma.transaction.aggregate({
        where: { ...txWhere, createdAt: { gte: weekAgo }, status: { in: ['COMPLETED', 'PAID', 'SUCCESS'] } },
        _sum: { commissionAmount: true },
      }),
      prisma.dispute.groupBy({
        by: ['status'],
        _count: { _all: true },
        ...(orderIds ? { where: { orderId: { in: orderIds } } } : {}),
      }),
    ]);
    const disputeCount = (statuses) => disputes
      .filter((d) => statuses.includes(String(d.status).toUpperCase()))
      .reduce((sum, d) => sum + d._count._all, 0);
    return res.status(200).json({
      data: {
        weeklyCommissions: Number(commissions._sum.commissionAmount || 0),
        paymentsCompleted: completed,
        paymentsPending: pending,
        disputesOpen: disputeCount(['OPEN']),
        disputesInProgress: disputeCount(['IN_PROGRESS', 'IN_REVIEW', 'PENDING']),
        disputesResolved: disputeCount(['RESOLVED', 'CLOSED', 'REFUNDED', 'REJECTED']),
      },
    });
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
    assertCountryInScope(await adminContext(req), user.country);
    const context = await adminContext(req);
    if (Number(user.userId) === context.userId) {
      throw badRequest('Vous ne pouvez pas supprimer votre propre compte.');
    }
    if (adminRoleIds().includes(Number(user.roleId))) requireSuperAdmin(context);
    const now = new Date();
    await prisma.$transaction([
      prisma.user.update({ where: { id: user.id }, data: { deletedAt: now, courierStatus: 'INACTIVE' } }),
      prisma.authUser.updateMany({ where: { legacyUserId: user.userId, deletedAt: null }, data: { deletedAt: now } }),
    ]);
    await recordAudit(req, 'user:deleted', { userId: user.userId, email: user.email }, user.country);
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
    if (!resto) throw notFound('Restaurant');
    assertCountryInScope(await adminContext(req), resto.country);

    const newValid = Number(valid);
    if (![0, 1, 2].includes(newValid)) throw badRequest('valid doit valoir 0 (en attente), 1 (validé) ou 2 (refusé).');
    const previousValid = Number(resto.valid || 0);
    const nowApproved = newValid === 1 && previousValid !== 1;
    // L'app admin refuse avec valid = 2 ; l'ancien format (0 + motif) reste accepté.
    const nowRejected = (newValid === 2 && previousValid !== 2)
      || (newValid === 0 && previousValid !== 0 && Boolean(reviewRemark));

    const result = await prisma.$transaction(async (tx) => {
      // Le badge Pro ne vient plus de cette validation : il est accordé par
      // l'examen des documents professionnels (« Devenir Pro »).
      const data = { valid: newValid, ...(reviewRemark ? { reviewRemark } : {}) };

      const updatedResto = await tx.restaurant.update({ where: { id: resto.id }, data });
      let owner = null;
      const legacyOwnerId = updatedResto.userId ?? resto.userId;
      if (legacyOwnerId !== null && legacyOwnerId !== undefined) {
        owner = await tx.user.findFirst({ where: { userId: legacyOwnerId, deletedAt: null } });
      }
      if (nowApproved && owner) {
        const newRole = restaurateurRoleId();
        const adminIds = adminRoleIds();
        if (owner.roleId !== newRole && !adminIds.includes(Number(owner.roleId))) {
          owner = await tx.user.update({
            where: { id: owner.id },
            data: { roleId: newRole, accountType: 'RESTAURATEUR' },
          });
        }
      }
      return { updatedResto, owner, remark: reviewRemark || resto.reviewRemark };
    });

    const { updatedResto, owner, remark } = result;

    if (owner?.email && (nowApproved || nowRejected)) {
      _notifyAsync(() => nowApproved
        ? sendRestaurantApprovedEmail({
            to: owner.email,
            firstname: owner.firstname,
            restaurantName: updatedResto.name,
          })
        : sendRestaurantRejectedEmail({
            to: owner.email,
            firstname: owner.firstname,
            restaurantName: updatedResto.name,
            reason: remark,
          })
      );
    } else if (!owner?.email && (nowApproved || nowRejected)) {
      console.warn('[admin][validateRestaurant] Aucun email pour notifier le propriétaire', {
        restaurantId: updatedResto.id,
        restoUserId: resto.userId,
        valid: newValid,
      });
    }

    await recordAudit(req, newValid === 1 ? 'restaurant:approved' : newValid === 2 ? 'restaurant:rejected' : 'restaurant:pending', {
      restaurantId: updatedResto.restaurantId, name: updatedResto.name, remark: reviewRemark || null,
    }, updatedResto.country);
    return res.status(200).json({ data: updatedResto });
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
    assertCountryInScope(await adminContext(req), user.country);
    const data = await m.user.update({
      where: { id: user.id },
      data: { identity: String(status || '').trim() },
    });
    await recordAudit(req, 'user:identity', { userId: user.userId, identity: data.identity }, user.country);
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
      where: { deletedAt: null, country: { not: null } },
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
    assertCountryInScope(await adminContext(req), user.country);
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
    assertCountryInScope(await adminContext(req), user.country);
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
    await recordAudit(req, 'user:profile', { userId: user.userId, fields: Object.keys(data) }, user.country);
    const { password, ...safeUpdated } = updated;
    return res.status(200).json({ data: safeUpdated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Statut du dossier livreur tel qu'affiché dans l'admin.
function courierFileStatus(user, latestFile) {
  if (isIdentityVerified(user.identity)) return 'validated';
  if (latestFile?.status === 'pending') return 'pending';
  if (latestFile?.status === 'rejected' || String(user.identity || '').toLowerCase() === 'rejected') return 'rejected';
  return 'missing';
}

function courierRow(user, latestFile) {
  const { password, ...safeUser } = user;
  const courierStatus = String(user.courierStatus || '').toUpperCase();
  return {
    ...safeUser,
    isOnline: ['ACTIVE', 'ONLINE', 'AVAILABLE', 'BUSY'].includes(courierStatus),
    isBusy: courierStatus === 'BUSY',
    fileStatus: courierFileStatus(user, latestFile),
    file: latestFile || null,
  };
}

/// Liste des livreurs avec l'état de leur dossier (photo, pièce, permis).
async function listCouriers(req, res, next) {
  try {
    const roleId = courierRoleId();
    const where = { deletedAt: null, roleId };
    const country = scopedCountry(await adminContext(req), req.query?.country);
    if (country) where.country = country;
    const users = await prisma.user.findMany({ where, orderBy: { createdAt: 'desc' }, take: 500 });
    const ids = users.map((u) => u.userId);
    const files = ids.length
      ? await prisma.identity.findMany({
          where: { userId: { in: ids }, deletedAt: null },
          orderBy: { createdAt: 'desc' },
        })
      : [];
    const latestByUser = new Map();
    for (const file of files) if (!latestByUser.has(file.userId)) latestByUser.set(file.userId, file);
    return res.status(200).json({ data: users.map((u) => courierRow(u, latestByUser.get(u.userId))) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Fiche d'un livreur : profil, dernier dossier et activité.
async function getCourier(req, res, next) {
  try {
    const userId = Number.parseInt(req.params.userId, 10);
    if (!Number.isInteger(userId)) throw badRequest('userId invalide.');
    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    if (!user) throw notFound('Livreur');
    const [latestFile, delivered, active] = await Promise.all([
      prisma.identity.findFirst({ where: { userId, deletedAt: null }, orderBy: { createdAt: 'desc' } }),
      prisma.order.aggregate({
        where: { delivererId: userId, deletedAt: null, status: { in: ['DELIVERED', 'LIVREE'] } },
        _count: { _all: true },
        _sum: { deliveryFee: true },
      }),
      prisma.order.count({
        where: {
          delivererId: userId,
          deletedAt: null,
          status: { notIn: ['DELIVERED', 'LIVREE', 'CANCELLED', 'REFUSED'] },
        },
      }),
    ]);
    return res.status(200).json({
      data: {
        ...courierRow(user, latestFile),
        stats: {
          deliveredCount: delivered._count._all,
          deliveryFees: Number(delivered._sum.deliveryFee || 0),
          activeCount: active,
        },
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  createAdmin,
  getSuperAdminStats,
  listCouriers,
  getCourier,
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
