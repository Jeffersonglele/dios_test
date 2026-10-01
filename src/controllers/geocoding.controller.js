const { handleControllerError } = require('./controller.utils');
const { reverseGeocode, searchAddress } = require('../services/nominatim.service');

async function search(req, res, next) {
  try {
    const { q, limit, countryCodes } = req.query;
    return res.status(200).json({
      data: await searchAddress(q, { limit, countryCodes }),
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function reverse(req, res, next) {
  try {
    const { latitude, longitude, countryCodes } = req.query;
    return res.status(200).json({
      data: await reverseGeocode(latitude, longitude, { countryCodes }),
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { reverse, search };
