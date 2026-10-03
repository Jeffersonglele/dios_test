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

// Fallback rates by country (base currency is the country's default)
const COUNTRY_FALLBACK_RATES = {
  'BJ': { // Base: XOF
    'XOF': 1,
    'USD': 0.00167,
    'EUR': 0.00152,
    'CDF': 4.17,
    'NGN': 2.5,
    'CAD': 0.00227,
    'CHF': 0.00148,
  },
  'CD': { // Base: CDF
    'CDF': 1,
    'XOF': 0.24,
    'USD': 0.0004,
    'EUR': 0.000365,
    'NGN': 0.6,
    'CAD': 0.000544,
    'CHF': 0.000356,
  },
};

let ratesCache = null;
let lastCacheTime = null;

async function getExchangeRates(countryCode = 'BJ') {
  const now = Date.now();
  // Refresh cache every 12 hours
  if (ratesCache && lastCacheTime && (now - lastCacheTime < 12 * 60 * 60 * 1000)) {
    return ratesCache;
  }

  try {
    const apiKey = process.env.EXCHANGE_RATE_API_KEY;
    if (apiKey) {
      const baseCurrency = COUNTRY_TO_CURRENCY[countryCode] || 'XOF';
      const res = await axios.get(`https://v6.exchangerate-api.com/v6/${apiKey}/latest/${baseCurrency}`);
      if (res.data && res.data.conversion_rates) {
        ratesCache = res.data.conversion_rates;
        lastCacheTime = now;
        return ratesCache;
      }
    } else {
      console.warn("EXCHANGE_RATE_API_KEY not set in .env. Using fallback rates.");
    }
  } catch (err) {
    console.error("Failed to fetch exchange rates from v6.exchangerate-api.com:", err.message);
  }

  // Use country-specific fallback rates
  ratesCache = COUNTRY_FALLBACK_RATES[countryCode] || COUNTRY_FALLBACK_RATES['BJ'];
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
