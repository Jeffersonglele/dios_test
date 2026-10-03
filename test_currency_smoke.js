require('dotenv').config({ quiet: true });
const geoIpMiddleware = require('./src/middlware/geoip.middleware');
const currencyService = require('./src/services/currency.service');

function makeReq(headers = {}, ip = '127.0.0.1') {
  return {
    headers,
    connection: { remoteAddress: ip },
    ip,
  };
}

function makeRes() { return {}; }

function run(label, fn) {
  try {
    fn();
    console.log('  ✓', label);
  } catch (e) {
    console.log('  ✗', label, '-', e.message);
    process.exitCode = 1;
  }
}

(async function main() {
  console.log('\n== Phase 1 Backend : validation rapide ==');

  console.log('\n1. GeoIP Middleware');

  run('localhost sans header → BJ', () => {
    const req = makeReq({}, '127.0.0.1');
    let nextCalled = false;
    geoIpMiddleware(req, makeRes(), () => { nextCalled = true; });
    if (!nextCalled) throw new Error('next() non appelé');
    if (req.userCountry !== 'BJ') throw new Error('attendu BJ, got: ' + req.userCountry);
  });

  run('header cf-ipcountry: FR → FR', () => {
    const req = makeReq({ 'cf-ipcountry': 'FR' }, '10.0.0.1');
    geoIpMiddleware(req, makeRes(), () => {});
    if (req.userCountry !== 'FR') throw new Error('attendu FR, got: ' + req.userCountry);
  });

  run('header x-country-code: US (fallback cascade) → US', () => {
    const req = makeReq({ 'x-country-code': 'US' }, '10.0.0.1');
    geoIpMiddleware(req, makeRes(), () => {});
    if (req.userCountry !== 'US') throw new Error('attendu US, got: ' + req.userCountry);
  });

  run('header cf-ipcountry en minuscule → majuscules (BJ)', () => {
    const req = makeReq({ 'cf-ipcountry': 'bj' }, '10.0.0.1');
    geoIpMiddleware(req, makeRes(), () => {});
    if (req.userCountry !== 'BJ') throw new Error('attendu BJ, got: ' + req.userCountry);
  });

  console.log('\n2. Mapping COUNTRY → devise');
  const tests = [
    ['BJ', 'XOF'], ['CI', 'XOF'], ['SN', 'XOF'], ['TG', 'XOF'],
    ['BF', 'XOF'], ['ML', 'XOF'], ['NE', 'XOF'], ['GW', 'XOF'],
    ['CD', 'CDF'],
    ['FR', 'EUR'], ['BE', 'EUR'],
    ['CH', 'CHF'],
    ['US', 'USD'],
    ['CA', 'CAD'],
    ['NG', 'NGN'],
    ['ZZ', 'USD'], // pays inconnu → USD (défaut)
  ];
  for (const [country, expected] of tests) {
    run(`getCurrencyForCountry('${country}') → ${expected}`, () => {
      const got = currencyService.getCurrencyForCountry(country);
      if (got !== expected) throw new Error('got: ' + got);
    });
  }

  console.log('\n3. Taux de change (base XOF, cache 12h, fallback si pas de clé)');
  const rates = await currencyService.getExchangeRates();
  const needKeys = ['USD', 'XOF', 'EUR', 'CDF', 'NGN', 'CAD', 'CHF'];
  for (const k of needKeys) {
    run(`rates contient ${k} > 0`, () => {
      if (!(k in rates)) throw new Error('clé absente: ' + k);
      if (typeof rates[k] !== 'number' || rates[k] <= 0) throw new Error('valeur invalide: ' + rates[k]);
    });
  }
  run('XOF est la devise pivot (rates.XOF === 1)', () => {
    if (Math.abs(rates.XOF - 1.0) > 1e-9) throw new Error('attendu XOF=1, got: ' + rates.XOF);
  });

  console.log('\n4. Invariant conversion pivot (fromRate/toRate via XOF base)');
  const convertBetween = (amount, from, to) => (amount / rates[from]) * rates[to];
  const near = (a, b, eps = 0.01) => Math.abs(a - b) < eps;

  run('6000 XOF → ~10 USD', () => {
    const v = convertBetween(6000, 'XOF', 'USD');
    if (!near(v, 10)) throw new Error('got: ' + v);
  });
  run('6000 XOF → ~9.20 EUR', () => {
    const v = convertBetween(6000, 'XOF', 'EUR');
    if (!near(v, 9.20)) throw new Error('got: ' + v);
  });
  run('10 USD → ~9.20 EUR via pivot', () => {
    const v = convertBetween(10, 'USD', 'EUR');
    if (!near(v, 9.20)) throw new Error('got: ' + v);
  });
  run('1 USD → ~600 XOF (cross-check inverse)', () => {
    const v = convertBetween(1, 'USD', 'XOF');
    if (!near(v, 600)) throw new Error('got: ' + v);
  });

  console.log('\n5. Format de réponse (simule controller.getConfig)');
  const country = 'BJ';
  const currency = currencyService.getCurrencyForCountry(country);
  const finalRates = await currencyService.getExchangeRates();
  run('structure {success, data:{country,currency,rates}} conforme', () => {
    const payload = { success: true, data: { country, currency, rates: finalRates } };
    if (!payload.success) throw new Error('success=false');
    if (!payload.data.country) throw new Error('country manquant');
    if (!payload.data.currency) throw new Error('currency manquant');
    if (typeof payload.data.rates !== 'object') throw new Error('rates pas un objet');
    if (payload.data.country !== 'BJ') throw new Error('country != BJ');
    if (payload.data.currency !== 'XOF') throw new Error('currency != XOF');
  });

  console.log('\nTerminé. exitCode =', process.exitCode || 0);
})();
