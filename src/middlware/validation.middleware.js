const Joi = require('joi');

function validate(schema) {
  return (req, res, next) => {
    const validation = schema.validate(
      { body: req.body, params: req.params, query: req.query },
      { abortEarly: false, allowUnknown: false, stripUnknown: true },
    );
    if (validation.error) {
      const error = new Error(validation.error.details.map((detail) => detail.message).join(', '));
      error.statusCode = 422;
      return next(error);
    }
    req.body = validation.value.body;
    req.params = validation.value.params;
    req.query = validation.value.query;
    return next();
  };
}

const uuidParam = Joi.object({ id: Joi.string().guid({ version: 'uuidv4' }).required() });
const paginationQuery = Joi.object({
  page: Joi.number().integer().min(1),
  pageSize: Joi.number().integer().min(1).max(100),
  limit: Joi.number().integer().min(1).max(100),
  includeDeleted: Joi.boolean(),
}).unknown(true);

const validators = {
  id: Joi.object({ params: uuidParam, query: Joi.object().unknown(true), body: Joi.object().unknown(true) }),
  pagination: Joi.object({ params: Joi.object().unknown(true), query: paginationQuery, body: Joi.object().unknown(true) }),
  login: Joi.object({
    body: Joi.object({
      identifier: Joi.string().trim(), email: Joi.string().email(), username: Joi.string().trim(),
      password: Joi.string().min(8).required(),
    }).or('identifier', 'email', 'username'),
    params: Joi.object(), query: Joi.object(),
  }),
  register: Joi.object({
    body: Joi.object({
      username: Joi.string().trim().min(3).max(80).required(), email: Joi.string().email().required(),
      password: Joi.string().min(8).max(128).required(), firstname: Joi.string().trim().max(100),
      lastname: Joi.string().trim().max(100), telephone: Joi.string().trim().max(32),
      telephoneLocal: Joi.string().trim().max(32), telephoneE164: Joi.string().trim().max(32),
      country: Joi.string().trim().max(100), cityId: Joi.number().integer(), roleId: Joi.number().integer(),
      accountType: Joi.string().trim().max(50), ageConfirmed: Joi.boolean(),
    }).required(), params: Joi.object(), query: Joi.object(),
  }),
  resetRequest: Joi.object({ body: Joi.object({ email: Joi.string().email().required() }), params: Joi.object(), query: Joi.object() }),
  resetPassword: Joi.object({
    body: Joi.object({ email: Joi.string().email().required(), code: Joi.string().trim().required(), password: Joi.string().min(8).max(128).required() }),
    params: Joi.object(), query: Joi.object(),
  }),
  createOrder: Joi.object({
    body: Joi.object({
      order: Joi.object().unknown(true), lines: Joi.array().items(Joi.object().unknown(true)).min(1),
      orderLines: Joi.array().items(Joi.object().unknown(true)).min(1), userId: Joi.number().integer(),
      restaurantId: Joi.number().integer(),
    }).or('lines', 'orderLines'), params: Joi.object(), query: Joi.object(),
  }),
};

module.exports = { validate, validators };
