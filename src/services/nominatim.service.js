const crypto = require('crypto');

const axios = require('axios');
const axiosRetryModule = require('axios-retry');
const axiosRetry = axiosRetryModule.default || axiosRetryModule;
const { isNetworkOrIdempotentRequestError, exponentialDelay } = axiosRetryModule;

const prisma = require('../config/prisma');
const { badRequest } = require('../controllers/controller.utils');

const NOMINATIM_BASE_URL = String(process.env.NOMINATIM_BASE_URL || 'https://nominatim.openstreetmap.org')
  .replace(/\/+$/, '');
const NOMINATIM_DEFAULT_USER_AGENT = 'DiosDelicesApp/1.0 (contact@diosdelices.local)';
const CACHE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
let nextPublicRequestAt = 0;

function userAgent() {
  const env = String(process.env.NOMINATIM_USER_AGENT || '').trim();
  if (env) return env;
  return NOMINATIM_DEFAULT_USER_AGENT;
}

const nominatimClient = axios.create({
  baseURL: NOMINATIM_BASE_URL,
  timeout: 15000,
  headers: {
    Accept: 'application/json',
    'User-Agent': userAgent(),
  },
});

axiosRetry(nominatimClient, {
  retries: 3,
  retryDelay: exponentialDelay,
  retryCondition: (error) => {
    if (isNetworkOrIdempotentRequestError(error)) return true;
    const code = error.code;
    if (code === 'ECONNABORTED' || code === 'ETIMEDOUT' || code === 'ECONNRESET') return true;
    const status = error.response?.status;
    if (status === 429 || status === 502 || status === 503 || status === 504) return true;
    return false;
  },
  onRetry: (retryCount, error) => {
    const status = error.response?.status || 'N/A';
    const after = error.response?.headers?.['retry-after'];
    console.warn(
      `[nominatim] retry #${retryCount} (status=${status}) ${error.config?.url || ''}${
        after ? `; Retry-After: ${after}s` : ''
      }`,
    );
  },
});

function cacheKey(kind, payload) {
  return crypto.createHash('sha256').update(`${kind}:${JSON.stringify(payload)}`).digest('hex');
}

async function waitForPublicRequestSlot() {
  const waitMs = Math.max(0, nextPublicRequestAt - Date.now());
  nextPublicRequestAt = Math.max(Date.now(), nextPublicRequestAt) + 1000;
  if (waitMs > 0) await new Promise((resolve) => setTimeout(resolve, waitMs));
}

function normalizeResult(result) {
  const latitude = Number(result.lat);
  const longitude = Number(result.lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  return {
    placeId: result.place_id ? String(result.place_id) : null,
    displayName: result.display_name || null,
    latitude,
    longitude,
    address: result.address || {},
    type: result.type || null,
    class: result.class || null,
  };
}

async function cachedOrFetch(kind, payload, request) {
  const key = cacheKey(kind, payload);
  const cached = await prisma.geocodingCache.findFirst({ where: { cacheKey: key, expiresAt: { gt: new Date() } } });
  if (cached) return { result: cached.raw, cached: true };

  const agent = userAgent();
  if (!agent) {
    const error = new Error('NOMINATIM_USER_AGENT doit être configuré avant d’interroger Nominatim.');
    error.statusCode = 503;
    throw error;
  }
  await waitForPublicRequestSlot();
  const response = await nominatimClient.get(request.path, {
    params: request.params,
    headers: { 'User-Agent': agent, Accept: 'application/json' },
  });
  const raw = response.data;
  const first = Array.isArray(raw) ? raw[0] : raw;
  const normalized = first ? normalizeResult(first) : null;
  await prisma.geocodingCache.upsert({
    where: { cacheKey: key },
    create: {
      cacheKey: key,
      provider: 'nominatim',
      query: payload,
      displayName: normalized?.displayName || null,
      latitude: normalized?.latitude || null,
      longitude: normalized?.longitude || null,
      raw,
      expiresAt: new Date(Date.now() + CACHE_TTL_MS),
    },
    update: {
      displayName: normalized?.displayName || null,
      latitude: normalized?.latitude || null,
      longitude: normalized?.longitude || null,
      raw,
      expiresAt: new Date(Date.now() + CACHE_TTL_MS),
    },
  });
  return { result: raw, cached: false };
}

function normalizeCountryCodes(countryCodes) {
  if (countryCodes == null) return null;
  if (Array.isArray(countryCodes)) {
    const codes = countryCodes
      .map((c) => String(c || '').trim())
      .filter(Boolean)
      .map((c) => c.toLowerCase());
    return codes.length > 0 ? codes : null;
  }
  const codes = String(countryCodes)
    .split(/[,\s]+/)
    .map((c) => c.trim())
    .filter(Boolean)
    .map((c) => c.toLowerCase());
  return codes.length > 0 ? codes : null;
}

async function searchAddress(query, { limit = 5, countryCodes } = {}) {
  const term = String(query || '').trim();
  if (term.length < 3 || term.length > 200) throw badRequest('La recherche d’adresse doit contenir entre 3 et 200 caractères.');
  const safeLimit = Math.min(10, Math.max(1, Number.parseInt(limit, 10) || 5));
  const codes = normalizeCountryCodes(countryCodes);
  const params = { q: term, format: 'jsonv2', addressdetails: 1, limit: safeLimit };
  if (codes && codes.length > 0) params.countrycodes = codes.join(',');
  const response = await cachedOrFetch(
    'search',
    { query: term, limit: safeLimit, countryCode: codes?.join(',') || null },
    { path: '/search', params },
  );
  const records = Array.isArray(response.result) ? response.result : [];
  return { cached: response.cached, results: records.map(normalizeResult).filter(Boolean) };
}

async function reverseGeocode(latitude, longitude, { countryCodes } = {}) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw badRequest('Les coordonnées GPS sont invalides.');
  }
  const codes = normalizeCountryCodes(countryCodes);
  const params = { lat, lon: lng, format: 'jsonv2', addressdetails: 1, zoom: 18 };
  const response = await cachedOrFetch(
    'reverse',
    { latitude: lat, longitude: lng, countryCode: codes?.join(',') || null },
    { path: '/reverse', params },
  );
  const normalized = response.result ? normalizeResult(response.result) : null;
  return { cached: response.cached, result: normalized };
}

async function searchRdc(query, limit = 5) {
  return searchAddress(query, { limit, countryCodes: ['cd'] });
}

async function reverseRdc(latitude, longitude) {
  const res = await reverseGeocode(latitude, longitude, { countryCodes: ['cd'] });
  const countryCode = String(res.result?.address?.country_code || '').toLowerCase();
  if (res.result && countryCode && countryCode !== 'cd') {
    throw badRequest('Cette position ne se trouve pas en République démocratique du Congo.');
  }
  return res;
}

module.exports = {
  reverseGeocode,
  searchAddress,
  reverseRdc,
  searchRdc,
};
