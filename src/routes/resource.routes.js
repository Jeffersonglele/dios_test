const express = require('express');

const { authenticate } = require('../middlware/auth.middleware');
const { validate, validators } = require('../middlware/validation.middleware');

/** Mountable REST router for controller objects exposing list/get/create/update/remove. */
function createResourceRouter(controller, options = {}) {
  const router = express.Router();
  const {
    readMiddlewares = [],
    writeMiddlewares = [authenticate],
    removeMiddlewares = writeMiddlewares,
    createValidator,
  } = options;

  router.route('/')
    .get(...readMiddlewares, validate(validators.pagination), controller.list)
    .post(...writeMiddlewares, ...(createValidator ? [createValidator] : []), controller.create);

  router.route('/:id')
    .get(...readMiddlewares, validate(validators.id), controller.getById)
    .patch(...writeMiddlewares, validate(validators.id), controller.update)
    .delete(...removeMiddlewares, validate(validators.id), controller.remove);

  return router;
}

module.exports = { createResourceRouter };
