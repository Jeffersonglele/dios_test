const axios = require('axios');

const COUNTRY_TO_CURRENCY = {
  'BJ': 'XOF',
  'CI': 'XOF',
  'SN': 'XOF',
  'TG': 'XOF',
  'BF': 'XOF',
  'ML': 'XOF',
  'NE': 'XOF',
  'GW': 'XOF',
  'CD': 'CDF',
  'FR': 'EUR',
  'BE': 'EUR',
  'CH': 'CHF',
  'US': 'USD',
  'CA': 'CAD',
  'NG': 'NGN',
};

let ratesCache = null;
let lastCacheTime = null;

async function getExchangeRates() {
  const now = Date.now();
  // Refresh cache every 12 hours
  if (ratesCache && lastCacheTime && (now - lastCacheTime < 12 * 60 * 60 * 1000)) {
    return ratesCache;
  }

  try {
    const apiKey = process.env.EXCHANGE_RATE_API_KEY;
    if (apiKey) {
      const res = await axios.get(`https://v6.exchangerate-api.com/v6/${apiKey}/latest/XOF`);
      if (res.data && res.data.conversion_rates) {
        ratesCache = res.data.conversion_rates;
        lastCacheTime = now;
        return ratesCache;
      }
    } else {
      console.warn("EXCHANGE_RATE_API_KEY not set in .env. Using fallback rates (base XOF).");
    }
  } catch (err) {
    console.error("Failed to fetch exchange rates from v6.exchangerate-api.com:", err.message);
  }

  ratesCache = {
    'XOF': 1,
    'USD': (1 / 600),
    'CDF': (2500 / 600),
    'EUR': (0.92 / 600),
    'NGN': (1500 / 600),
    'CAD': (1.36 / 600),
    'CHF': (0.89 / 600)
  };
  lastCacheTime = now;
  return ratesCache;
}

function getCurrencyForCountry(countryCode) {
  return COUNTRY_TO_CURRENCY[countryCode] || 'USD';
}

module.exports = {
  getExchangeRates,
  getCurrencyForCountry
};
