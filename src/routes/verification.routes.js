const express = require('express');

const { verification } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();
const adminOnly = [authenticate, authorize('ADMIN')];

router.patch('/identities/:id/review', ...adminOnly, validate(validators.id), verification.identity.review);
router.patch('/pro-documents/:id/review', ...adminOnly, validate(validators.id), verification.proDocument.review);
router.use('/identities', createResourceRouter(verification.identity, { readMiddlewares: [authenticate] }));
router.use('/pro-documents', createResourceRouter(verification.proDocument, { readMiddlewares: [authenticate] }));
router.use('/verification-codes', createResourceRouter(verification.verificationCode, { readMiddlewares: adminOnly, writeMiddlewares: adminOnly }));

module.exports = router;
