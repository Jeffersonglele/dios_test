const axios = require('axios');
const crypto = require('crypto');

const CINETPAY_WEBHOOK_FIELDS = [
  'cpm_site_id', 'cpm_trans_id', 'cpm_trans_date', 'cpm_amount', 'cpm_currency',
  'signature', 'payment_method', 'cel_phone_num', 'cpm_phone_prefixe', 'cpm_language',
  'cpm_version', 'cpm_payment_config', 'cpm_page_action', 'cpm_custom',
  'cpm_designation', 'cpm_error_message',
];

function configuration() {
  return {
    mode: String(process.env.CINETPAY_MODE || 'mock').trim().toLowerCase(),
    apiBaseUrl: String(process.env.CINETPAY_API_BASE_URL || 'https://api-checkout.cinetpay.com').replace(/\/$/, ''),
    apiKey: process.env.CINETPAY_API_KEY || '',
    siteId: process.env.CINETPAY_SITE_ID || '',
    secretKey: process.env.CINETPAY_SECRET_KEY || '',
    notifyUrl: process.env.CINETPAY_NOTIFY_URL || '',
    returnUrl: process.env.CINETPAY_RETURN_URL || '',
  };
}

function isMockMode() {
  return configuration().mode === 'mock';
}

function assertLiveConfiguration() {
  const config = configuration();
  const missing = ['apiKey', 'siteId', 'secretKey', 'notifyUrl', 'returnUrl']
    .filter((name) => !config[name] || String(config[name]).startsWith('mock_') || config[name] === '000000');
  if (missing.length > 0) {
    const error = new Error(`Configuration CinetPay production incomplète : ${missing.join(', ')}.`);
    error.statusCode = 503;
    throw error;
  }
  return config;
}

function amountAsInteger(amount) {
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0) {
    const error = new Error('Le montant de paiement doit être positif.');
    error.statusCode = 400;
    throw error;
  }
  return Math.round(value);
}

function cpmStatusIsSuccessful(status) {
  return ['ACCEPTED', 'SUCCESS', 'SUCCEEDED'].includes(String(status || '').trim().toUpperCase());
}

function cpmStatusIsFinalFailure(status) {
  return ['REFUSED', 'FAILED', 'CANCELLED', 'TRANSACTION_CANCEL'].includes(String(status || '').trim().toUpperCase());
}

function buildWebhookSignature(payload, secretKey = configuration().secretKey) {
  const source = CINETPAY_WEBHOOK_FIELDS.map((field) => String(payload?.[field] ?? '')).join('');
  return crypto.createHmac('sha256', secretKey).update(source).digest('hex');
}

function timingSafeEquals(left, right) {
  if (!left || !right) return false;
  const leftBuffer = Buffer.from(String(left), 'utf8');
  const rightBuffer = Buffer.from(String(right), 'utf8');
  return leftBuffer.length === rightBuffer.length && crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function verifyWebhookSignature(payload, receivedToken) {
  if (isMockMode()) return true;
  return timingSafeEquals(receivedToken, buildWebhookSignature(payload));
}

async function initiatePayment({ transactionId, amount, currency, customer, channels = 'ALL' }) {
  if (isMockMode()) {
    return { mode: 'mock', paymentUrl: null, providerRef: `MOCK-${transactionId}`, status: 'PENDING' };
  }

  const config = assertLiveConfiguration();
  const payload = {
    apikey: config.apiKey,
    site_id: config.siteId,
    transaction_id: transactionId,
    amount: amountAsInteger(amount),
    currency: String(currency || 'CDF').toUpperCase(),
    description: `Commande Dios Delices ${transactionId}`,
    customer_name: customer.name || 'Client Dios Delices',
    customer_email: customer.email || '',
    customer_phone_number: customer.phone || '',
    notify_url: config.notifyUrl,
    return_url: config.returnUrl,
    channels,
    lang: 'FR',
    metadata: transactionId,
  };
  const response = await axios.post(`${config.apiBaseUrl}/v2/payment`, payload, { timeout: 15000 });
  const result = response.data || {};
  if (String(result.code) !== '00' || !result.data?.payment_url) {
    const error = new Error(result.message || result.description || 'CinetPay a refusé l’initialisation du paiement.');
    error.statusCode = 502;
    throw error;
  }
  return {
    mode: 'live',
    paymentUrl: result.data.payment_url,
    providerRef: result.data.payment_token || null,
    status: 'PENDING',
  };
}

async function verifyPayment(transaction) {
  if (isMockMode()) {
    const mockStatus = transaction.providerData?.mockStatus || 'PENDING';
    return { status: mockStatus, amount: Number(transaction.amount), currency: transaction.currency, providerRef: transaction.providerRef, raw: { mode: 'mock', status: mockStatus } };
  }

  const config = assertLiveConfiguration();
  const response = await axios.post(`${config.apiBaseUrl}/v2/payment/check`, {
    apikey: config.apiKey,
    site_id: config.siteId,
    transaction_id: transaction.transactionId,
  }, { timeout: 15000 });
  const result = response.data || {};
  const data = result.data || {};
  return {
    status: data.status || result.status || '',
    amount: Number(data.amount),
    currency: data.currency,
    providerRef: data.payment_token || data.transaction_id || transaction.providerRef,
    raw: result,
  };
}

module.exports = {
  amountAsInteger,
  buildWebhookSignature,
  cpmStatusIsFinalFailure,
  cpmStatusIsSuccessful,
  initiatePayment,
  isMockMode,
  verifyPayment,
  verifyWebhookSignature,
};
