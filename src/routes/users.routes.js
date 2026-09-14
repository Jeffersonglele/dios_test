const express = require('express');

const { users } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { authorize } = require('../middlware/authorization.middleware');
const { userOwnerOrAdmin } = require('../middlware/ownership.middleware');
const { validate, validators } = require('../middlware/validation.middleware');
const { createResourceRouter } = require('./resource.routes');

const router = express.Router();

router.patch('/:id/profile', authenticate, validate(validators.id), userOwnerOrAdmin, users.updateProfile);
router.patch('/:id/identity-status', authenticate, authorize('ADMIN'), validate(validators.id), users.setIdentityStatus);
router.use('/', createResourceRouter(users, {
  readMiddlewares: [authenticate, authorize('ADMIN')],
  writeMiddlewares: [authenticate, authorize('ADMIN')],
}));

module.exports = router;
