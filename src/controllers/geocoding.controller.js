const { handleControllerError } = require('./controller.utils');
const { reverseRdc, searchRdc } = require('../services/nominatim.service');

async function search(req, res, next) {
  try {
    return res.status(200).json({ data: await searchRdc(req.query.q, req.query.limit) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function reverse(req, res, next) {
  try {
    return res.status(200).json({ data: await reverseRdc(req.query.latitude, req.query.longitude) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { reverse, search };
