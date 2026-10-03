const currencyService = require('../services/currency.service');

async function getConfig(req, res, next) {
  try {
    const country = req.userCountry || 'BJ';
    const currency = currencyService.getCurrencyForCountry(country);
    const rates = await currencyService.getExchangeRates();

    res.json({
      success: true,
      data: {
        country,
        currency,
        rates
      }
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getConfig
};
