const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');
const {
  sendSellerApprovedEmail,
  sendSellerRejectedEmail,
  sendCourierApprovedEmail,
  sendCourierRejectedEmail,
} = require('../services/email.service');

const IDENTITY_FIELDS = ['identityId', 'userId', 'identityFileUrl', 'photoUrl', 'status', 'remark'];
const DOCUMENT_FIELDS = [
  'documentId', 'userId', 'restaurantId', 'siretUrl', 'kbisUrl', 'identityDocumentUrl',
  'description', 'status', 'remark',
];
const CODE_FIELDS = ['email', 'code', 'expiresAt', 'phone', 'purpose', 'attempts', 'blockedUntil', 'verified'];

const identity = createCrudController({
  delegate: 'identity', resource: 'Vérification d’identité', fields: IDENTITY_FIELDS,
  filterFields: ['status'],
});
const proDocument = createCrudController({
  delegate: 'proDocument', resource: 'Document professionnel', fields: DOCUMENT_FIELDS,
  filterFields: ['status'],
});
const verificationCode = createCrudController({
  delegate: 'verificationCode', resource: 'Code de vérification', fields: CODE_FIELDS,
  hasSoftDelete: false, filterFields: ['email', 'phone', 'purpose', 'verified'],
});

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
      console.error('[verification] Échec envoi email notification', {
        message: err?.message,
        cause: err?.cause?.message,
      });
    });
  });
}

async function reviewIdentity(req, res, next) {
  try {
    const identityRecord = await prisma.identity.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!identityRecord) throw notFound('Vérification d’identité');
    if (!['approved', 'rejected', 'pending'].includes(req.body.status)) {
      throw badRequest('Le statut doit être approved, rejected ou pending.');
    }
    const normalizedStatus = String(req.body.status || '').trim();
    const isApproved = normalizedStatus === 'approved';
    const isRejected = normalizedStatus === 'rejected';

    const result = await prisma.$transaction(async (tx) => {
      const record = await tx.identity.update({
        where: { id: identityRecord.id },
        data: { status: normalizedStatus, remark: req.body.remark ?? identityRecord.remark },
      });

      let targetUser = null;
      if (identityRecord.userId !== null && identityRecord.userId !== undefined) {
        targetUser = await tx.user.findFirst({ where: { userId: identityRecord.userId, deletedAt: null } });
      }

      if (targetUser) {
        const userPatch = {};
        if (isApproved) userPatch.identity = 'Vérifiée';
        else if (isRejected) userPatch.identity = normalizedStatus;

        if (isApproved) {
          const newRole = courierRoleId();
          const adminIds = adminRoleIds();
          if (targetUser.roleId !== newRole && !adminIds.includes(Number(targetUser.roleId))) {
            userPatch.roleId = newRole;
            userPatch.accountType = 'LIVREUR';
          }
        }

        if (Object.keys(userPatch).length > 0) {
          targetUser = await tx.user.update({ where: { id: targetUser.id }, data: userPatch });
        }
      }

      return { record, targetUser, isApproved, isRejected };
    });

    const { record, targetUser, isApproved: approved, isRejected: rejected } = result;
    const remark = req.body.remark ?? identityRecord.remark;

    if (targetUser?.email && (approved || rejected)) {
      _notifyAsync(() => approved
        ? sendCourierApprovedEmail({ to: targetUser.email, firstname: targetUser.firstname })
        : sendCourierRejectedEmail({ to: targetUser.email, firstname: targetUser.firstname, reason: remark })
      );
    } else if (!targetUser?.email && (approved || rejected)) {
      console.warn('[verification][reviewIdentity] Aucun email pour notifier l’utilisateur', {
        identityId: record.id,
        userId: identityRecord.userId,
      });
    }

    return res.status(200).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function reviewProDocument(req, res, next) {
  try {
    const document = await prisma.proDocument.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!document) throw notFound('Document professionnel');
    if (!['approved', 'rejected', 'pending'].includes(req.body.status)) {
      throw badRequest('Le statut doit être approved, rejected ou pending.');
    }
    const normalizedStatus = String(req.body.status || '').trim();
    const isApproved = normalizedStatus === 'approved';
    const isRejected = normalizedStatus === 'rejected';

    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.proDocument.update({
        where: { id: document.id },
        data: { status: normalizedStatus, remark: req.body.remark ?? document.remark },
      });

      let targetUser = null;
      let targetRestaurant = null;

      if (document.userId !== null && document.userId !== undefined) {
        targetUser = await tx.user.findFirst({ where: { userId: document.userId, deletedAt: null } });
      }
      if (!targetUser && document.restaurantId !== null && document.restaurantId !== undefined) {
        targetRestaurant = await tx.restaurant.findFirst({ where: { restaurantId: document.restaurantId } });
        if (targetRestaurant && targetRestaurant.userId !== null && targetRestaurant.userId !== undefined) {
          targetUser = await tx.user.findFirst({ where: { userId: targetRestaurant.userId, deletedAt: null } });
        }
      }

      if (isApproved) {
        const newRole = restaurateurRoleId();
        const adminIds = adminRoleIds();
        if (targetUser && targetUser.roleId !== newRole && !adminIds.includes(Number(targetUser.roleId))) {
          targetUser = await tx.user.update({
            where: { id: targetUser.id },
            data: { roleId: newRole, accountType: 'RESTAURATEUR' },
          });
        }
        if (targetRestaurant) {
          await tx.restaurant.update({
            where: { id: targetRestaurant.id },
            data: { isPro: true },
          });
        } else if (document.restaurantId !== null && document.restaurantId !== undefined) {
          const found = await tx.restaurant.findFirst({ where: { restaurantId: document.restaurantId } });
          if (found) {
            await tx.restaurant.update({ where: { id: found.id }, data: { isPro: true } });
            targetRestaurant = found;
          }
        }
      }

      return { updated, targetUser, isApproved, isRejected };
    });

    const { updated, targetUser, isApproved: approved, isRejected: rejected } = result;
    const remark = req.body.remark ?? document.remark;

    if (targetUser?.email && (approved || rejected)) {
      _notifyAsync(() => approved
        ? sendSellerApprovedEmail({ to: targetUser.email, firstname: targetUser.firstname })
        : sendSellerRejectedEmail({ to: targetUser.email, firstname: targetUser.firstname, reason: remark })
      );
    } else if (!targetUser?.email && (approved || rejected)) {
      console.warn('[verification][reviewProDocument] Aucun email pour notifier l’utilisateur', {
        documentId: updated.id,
        userId: document.userId,
        restaurantId: document.restaurantId,
      });
    }

    return res.status(200).json({ data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  identity: { ...identity, review: reviewIdentity },
  proDocument: { ...proDocument, review: reviewProDocument },
  verificationCode,
};
