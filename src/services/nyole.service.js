const axios = require('axios');
const crypto = require('crypto');

function configuration() {
  const mode = String(process.env.NYOLE_MODE || 'test').trim().toLowerCase() === 'live' ? 'live' : 'test';
  const apiBaseUrl = String(process.env.NYOLE_API_BASE_URL || 'https://app.nyole.com/api').replace(/\/$/, '');
  const publicUrl = String(process.env.API_PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || process.env.API_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
  return {
    mode,
    apiBaseUrl,
    liveSecretKey: String(process.env.NYOLE_LIVE_SECRET_KEY || '').trim(),
    testSecretKey: String(process.env.NYOLE_TEST_SECRET_KEY || '').trim(),
    successUrl: process.env.NYOLE_SUCCESS_URL || `${publicUrl}/api/v1/payments/nyole/return?status=success`,
    cancelUrl: process.env.NYOLE_CANCEL_URL || `${publicUrl}/api/v1/payments/nyole/return?status=cancelled`,
  };
}

function secretForLivemode(livemode, required = true) {
  const config = configuration();
  const secret = livemode ? config.liveSecretKey : config.testSecretKey;
  if (!secret && required) {
    const mode = livemode ? 'production' : 'test';
    const error = new Error(`NYOLE_${livemode ? 'LIVE' : 'TEST'}_SECRET_KEY doit être configurée pour le mode ${mode}.`);
    error.statusCode = 503;
    throw error;
  }
  return secret;
}

function amountAsInteger(amount) {
  const value = Number(amount);
  if (!Number.isFinite(value) || value <= 0 || !Number.isInteger(value)) {
    const error = new Error('Le montant Nyole doit être un entier positif.');
    error.statusCode = 400;
    throw error;
  }
  return value;
}

function normalizeStatus(status) {
  return String(status || '').trim().toUpperCase();
}

function isSuccessful(status) {
  return normalizeStatus(status) === 'SUCCESS';
}

function isFinalFailure(status) {
  return ['FAILED', 'CANCELLED'].includes(normalizeStatus(status));
}

function apiHeaders(livemode = configuration().mode === 'live') {
  return {
    Authorization: `Bearer ${secretForLivemode(livemode)}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
}

function providerError(error, fallback) {
  if (error.statusCode) return error;
  const response = error.response?.data;
  const message = response?.error || response?.message || response?.description || fallback;
  const wrapped = new Error(message);
  wrapped.statusCode = 502;
  return wrapped;
}

async function initiatePayment({ transactionId, amount, currency, customer, metadata = {}, restaurant, delivery }) {
  const config = configuration();
  const livemode = config.mode === 'live';
  const customerPhone = String(customer?.phone || '').replace(/[^\d+]/g, '') || undefined;
  const payload = {
    amount: amountAsInteger(amount),
    currency: String(currency || 'CDF').toUpperCase(),
    customer_name: customer?.name || 'Client Dios Delices',
    customer_email: customer?.email || undefined,
    customer_phone: customerPhone,
    description: `Commande Dios Delices ${transactionId}`,
    success_url: config.successUrl,
    cancel_url: config.cancelUrl,
    metadata: {
      ...metadata,
      dios_transaction_id: transactionId,
      restaurant_id: restaurant?.restaurantId || null,
      restaurant_name: restaurant?.name || null,
      restaurant_latitude: restaurant?.latitude,
      restaurant_longitude: restaurant?.longitude,
      restaurant_city_id: restaurant?.cityId || null,
      delivery_mode: delivery?.deliveryMode || null,
      delivery_address_id: delivery?.deliveryAddressId || null,
      delivery_latitude: delivery?.latitude,
      delivery_longitude: delivery?.longitude,
    },
  };

  try {
    const response = await axios.post(`${config.apiBaseUrl}/v1/checkout/sessions`, payload, {
      headers: { ...apiHeaders(livemode), 'Idempotency-Key': transactionId },
      timeout: 15000,
    });
    const result = response.data || {};
    if (!result.id || !result.url) {
      const error = new Error('Nyole n’a pas retourné de session de paiement exploitable.');
      error.statusCode = 502;
      throw error;
    }
    return {
      mode: config.mode,
      livemode,
      paymentUrl: result.url,
      providerRef: result.id,
      providerOrderId: result.order_id || null,
      status: normalizeStatus(result.status) || 'PENDING',
      raw: result,
    };
  } catch (error) {
    const responseData = error.response?.data;
    const responseMessage = responseData?.error || responseData?.message || responseData?.description || '';
    const nyoleMessage = typeof responseMessage === 'string' ? responseMessage : '';
    const raw = JSON.stringify(responseData || '');
    const missingRestaurantLocation = !restaurant
      || !Number.isFinite(Number(restaurant?.latitude))
      || !Number.isFinite(Number(restaurant?.longitude));
    const hint = missingRestaurantLocation
      ? " — le restaurant n'a pas de coordonnées GPS valides dans la base (latitude/longitude)."
      : ` — coordonnées restaurant (${restaurant?.latitude}, ${restaurant?.longitude}) et livraison (${delivery?.latitude}, ${delivery?.longitude}) envoyées.`;
    const fallback = `Nyole a refusé la création de la session de paiement${hint}`;
    const wrapped = new Error(nyoleMessage ? `${nyoleMessage}${hint}` : fallback);
    wrapped.statusCode = error.statusCode || 502;
    wrapped.providerRaw = raw;
    wrapped.providerMessage = nyoleMessage;
    wrapped.missingRestaurantLocation = missingRestaurantLocation;
    throw wrapped;
  }
}

async function verifyPayment(transaction) {
  const config = configuration();
  const livemode = transaction.providerData?.livemode === true
    || transaction.providerData?.mode === 'live';
  const sessionId = transaction.providerRef;
  if (!sessionId) {
    const error = new Error('La transaction ne possède pas de référence de session Nyole.');
    error.statusCode = 502;
    throw error;
  }

  try {
    const response = await axios.get(`${config.apiBaseUrl}/v1/checkout/sessions/${encodeURIComponent(sessionId)}/status`, {
      headers: apiHeaders(livemode),
      // Nyole expects a webhook response within 10 seconds.
      timeout: 8000,
    });
    const result = response.data || {};
    return {
      status: normalizeStatus(result.status),
      amount: Number(result.amount),
      currency: result.currency,
      providerRef: result.id || sessionId,
      raw: result,
    };
  } catch (error) {
    throw providerError(error, 'Nyole n’a pas pu vérifier le statut du paiement.');
  }
}

async function confirmSandbox(sessionId, issue) {
  const config = configuration();
  if (config.mode !== 'test') {
    const error = new Error('La confirmation Nyole de test est désactivée en production.');
    error.statusCode = 404;
    throw error;
  }
  const normalizedIssue = String(issue || '').toLowerCase() === 'echec' ? 'echec' : 'succes';
  try {
    const response = await axios.post(`${config.apiBaseUrl}/checkout/sandbox`, {
      transactionId: sessionId,
      issue: normalizedIssue,
    }, { timeout: 15000 });
    return response.data;
  } catch (error) {
    throw providerError(error, 'Nyole n’a pas pu simuler le résultat du paiement.');
  }
}

function parseSignature(value) {
  const parts = String(value || '').split(',').map((part) => part.trim());
  return {
    timestamp: parts.find((part) => part.startsWith('t='))?.slice(2) || '',
    signature: parts.find((part) => part.startsWith('v1='))?.slice(3) || '',
  };
}

function verifyWebhookSignature(rawBody, headers, livemode) {
  const { timestamp, signature } = parseSignature(headers?.['x-afriflow-signature']);
  const secret = secretForLivemode(livemode, false);
  const numericTimestamp = Number(timestamp);
  if (!secret || !timestamp || !signature || !Number.isInteger(numericTimestamp)) return false;
  if (Math.abs(Math.floor(Date.now() / 1000) - numericTimestamp) > 300) return false;

  const expected = crypto.createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex');
  const receivedBuffer = Buffer.from(signature, 'utf8');
  const expectedBuffer = Buffer.from(expected, 'utf8');
  return receivedBuffer.length === expectedBuffer.length
    && crypto.timingSafeEqual(receivedBuffer, expectedBuffer);
}

module.exports = {
  amountAsInteger,
  configuration,
  confirmSandbox,
  initiatePayment,
  isFinalFailure,
  isSuccessful,
  normalizeStatus,
  parseSignature,
  secretForLivemode,
  verifyPayment,
  verifyWebhookSignature,
};
