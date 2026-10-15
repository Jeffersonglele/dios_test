const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, conflict, handleControllerError, notFound, pagination, sendPage } = require('./controller.utils');
const {
  sendSellerApprovedEmail,
  sendSellerRejectedEmail,
  sendCourierApprovedEmail,
  sendCourierRejectedEmail,
} = require('../services/email.service');

const {
  IDENTITY, isIdentityVerified, normalizePlate, normalizeVehicleType, vehicleNeedsLicense,
} = require('../services/courier.service');
const { sendAdminNotification } = require('../services/email.service');

const IDENTITY_FIELDS = [
  'identityId', 'userId', 'identityFileUrl', 'photoUrl', 'licenseUrl', 'vehicleType', 'vehiclePlate',
  'status', 'remark',
];
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
        if (isApproved) userPatch.identity = IDENTITY.VERIFIED;
        else if (isRejected) userPatch.identity = IDENTITY.REJECTED;

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

function isAdmin(req) {
  return adminRoleIds().includes(Number(req.auth?.roleId));
}

function isHttpUrl(value) {
  return typeof value === 'string' && /^https?:\/\/\S+$/i.test(value.trim());
}

/// Liste des demandes Pro : toutes pour l'admin, les siennes pour un
/// restaurateur (les pièces d'identité ne sont pas publiques).
async function listProDocuments(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { deletedAt: null };
    if (!isAdmin(req)) where.userId = Number(req.auth?.userId);
    if (req.query.status) where.status = String(req.query.status);
    const [data, total] = await prisma.$transaction([
      prisma.proDocument.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.proDocument.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getProDocument(req, res, next) {
  try {
    const document = await prisma.proDocument.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!document || (!isAdmin(req) && Number(document.userId) !== Number(req.auth?.userId))) {
      throw notFound('Document professionnel');
    }
    return res.status(200).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Demande « Devenir Pro » : réservée au propriétaire d'un restaurant validé,
/// une seule demande en attente à la fois. L'examen reste côté admin.
async function createProRequest(req, res, next) {
  try {
    const userId = Number(req.auth?.userId);
    const restaurant = await prisma.restaurant.findFirst({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'asc' },
    });
    if (!restaurant || Number(restaurant.valid) !== 1) {
      throw badRequest('Votre restaurant doit être validé avant une demande Pro.');
    }
    if (restaurant.isPro) throw conflict('Votre restaurant a déjà le statut Pro.');
    const pending = await prisma.proDocument.findFirst({
      where: { userId, status: 'pending', deletedAt: null },
    });
    if (pending) throw conflict('Une demande Pro est déjà en cours d’examen.');

    const identityDocumentUrl = req.body.identityDocumentUrl;
    const kbisUrl = req.body.kbisUrl;
    if (!isHttpUrl(identityDocumentUrl)) throw badRequest('La pièce d’identité est obligatoire.');
    if (!isHttpUrl(kbisUrl)) throw badRequest('Le document professionnel (RCCM) est obligatoire.');
    const description = String(req.body.description || '').trim().slice(0, 1000);
    if (!description) throw badRequest('Décrivez votre activité.');

    const document = await prisma.proDocument.create({
      data: {
        userId,
        restaurantId: restaurant.restaurantId,
        identityDocumentUrl: identityDocumentUrl.trim(),
        kbisUrl: kbisUrl.trim(),
        ...(isHttpUrl(req.body.siretUrl) ? { siretUrl: req.body.siretUrl.trim() } : {}),
        description,
        status: 'pending',
      },
    });
    return res.status(201).json({ data: document });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Dossiers livreur : tous pour l'admin, le sien pour le livreur (photo et
/// pièce d'identité ne sont pas publiques).
async function listIdentities(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { deletedAt: null };
    if (!isAdmin(req)) where.userId = Number(req.auth?.userId);
    if (req.query.status) where.status = String(req.query.status);
    const [data, total] = await prisma.$transaction([
      prisma.identity.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.identity.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getIdentity(req, res, next) {
  try {
    const record = await prisma.identity.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!record || (!isAdmin(req) && Number(record.userId) !== Number(req.auth?.userId))) {
      throw notFound('Vérification d’identité');
    }
    return res.status(200).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// Dossier livreur : photo du visage (obligatoire, elle devient la photo de
/// profil), pièce d'identité et permis (sauf à vélo). Un seul dossier en
/// attente à la fois ; après un refus, le livreur peut en renvoyer un.
async function submitCourierApplication(req, res, next) {
  try {
    const userId = Number(req.auth?.userId);
    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    if (isIdentityVerified(user.identity)) throw conflict('Votre dossier livreur est déjà validé.');
    const pending = await prisma.identity.findFirst({
      where: { userId, status: 'pending', deletedAt: null },
    });
    if (pending) throw conflict('Votre dossier est déjà en cours de vérification.');

    const vehicleType = normalizeVehicleType(req.body.vehicleType) || normalizeVehicleType(user.vehicleType) || 'moto';
    const photoUrl = req.body.photoUrl;
    const identityFileUrl = req.body.identityFileUrl;
    const licenseUrl = req.body.licenseUrl;
    if (!isHttpUrl(photoUrl)) throw badRequest('La photo de vous est obligatoire.');
    if (!isHttpUrl(identityFileUrl)) throw badRequest('La pièce d’identité est obligatoire.');
    if (vehicleNeedsLicense(vehicleType) && !isHttpUrl(licenseUrl)) {
      throw badRequest('Le permis de conduire est obligatoire pour une moto ou une voiture.');
    }
    // La plaque permet au client et au restaurant de reconnaître le livreur.
    const vehiclePlate = normalizePlate(req.body.vehiclePlate);
    if (vehicleNeedsLicense(vehicleType) && !vehiclePlate) {
      throw badRequest('La plaque d’immatriculation est obligatoire pour une moto ou une voiture.');
    }

    const record = await prisma.$transaction(async (tx) => {
      const created = await tx.identity.create({
        data: {
          userId,
          photoUrl: photoUrl.trim(),
          identityFileUrl: identityFileUrl.trim(),
          ...(isHttpUrl(licenseUrl) ? { licenseUrl: licenseUrl.trim() } : {}),
          vehicleType,
          vehiclePlate,
          status: 'pending',
        },
      });
      await tx.user.update({
        where: { id: user.id },
        data: { identity: IDENTITY.PENDING, image: photoUrl.trim(), vehicleType, vehiclePlate },
      });
      return created;
    });

    const name = [user.firstname, user.lastname].filter(Boolean).join(' ') || user.username || '—';
    sendAdminNotification({
      subject: 'Dios Délices — Dossier livreur à valider',
      text: [
        'Un livreur a envoyé son dossier (photo, pièce d’identité, permis).',
        '',
        `Livreur : ${name} (n° ${user.userId})`,
        `Pays : ${user.country || '—'}`,
        `Véhicule : ${vehicleType}${vehiclePlate ? ` (${vehiclePlate})` : ''}`,
        `Téléphone : ${user.telephone || '—'}`,
        `Email : ${user.email || '—'}`,
      ].join('\n'),
    });

    return res.status(201).json({ data: record });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  identity: {
    ...identity,
    list: listIdentities,
    getById: getIdentity,
    review: reviewIdentity,
    submitCourierApplication,
  },
  proDocument: {
    ...proDocument,
    list: listProDocuments,
    getById: getProDocument,
    create: createProRequest,
    review: reviewProDocument,
  },
  verificationCode,
};
