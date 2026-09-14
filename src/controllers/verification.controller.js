const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { badRequest, handleControllerError, notFound } = require('./controller.utils');

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

async function reviewIdentity(req, res, next) {
  try {
    const identityRecord = await prisma.identity.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!identityRecord) throw notFound('Vérification d’identité');
    if (!['approved', 'rejected', 'pending'].includes(req.body.status)) {
      throw badRequest('Le statut doit être approved, rejected ou pending.');
    }
    const updated = await prisma.$transaction(async (tx) => {
      const record = await tx.identity.update({
        where: { id: identityRecord.id }, data: { status: req.body.status, remark: req.body.remark },
      });
      await tx.user.updateMany({
        where: { userId: identityRecord.userId },
        data: { identity: req.body.status === 'approved' ? 'Vérifiée' : req.body.status },
      });
      return record;
    });
    return res.status(200).json({ data: updated });
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
    const updated = await prisma.proDocument.update({
      where: { id: document.id }, data: { status: req.body.status, remark: req.body.remark },
    });
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
