const crypto = require('crypto');

const axios = require('axios');

const prisma = require('../config/prisma');
const { badRequest } = require('../controllers/controller.utils');

const NOMINATIM_BASE_URL = 'https://nominatim.openstreetmap.org';
const CACHE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
let nextPublicRequestAt = 0;

function userAgent() {
  return String(process.env.NOMINATIM_USER_AGENT || '').trim();
}

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
  const response = await axios.get(`${NOMINATIM_BASE_URL}${request.path}`, {
    params: request.params,
    headers: { 'User-Agent': agent, Accept: 'application/json' },
    timeout: 15000,
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

async function searchRdc(query, limit = 5) {
  const term = String(query || '').trim();
  if (term.length < 3 || term.length > 200) throw badRequest('La recherche d’adresse doit contenir entre 3 et 200 caractères.');
  const safeLimit = Math.min(10, Math.max(1, Number.parseInt(limit, 10) || 5));
  const response = await cachedOrFetch('search', { query: term, limit: safeLimit, countryCode: 'cd' }, {
    path: '/search',
    params: { q: term, countrycodes: 'cd', format: 'jsonv2', addressdetails: 1, limit: safeLimit },
  });
  const records = Array.isArray(response.result) ? response.result : [];
  return { cached: response.cached, results: records.map(normalizeResult).filter(Boolean) };
}

async function reverseRdc(latitude, longitude) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw badRequest('Les coordonnées GPS sont invalides.');
  }
  const response = await cachedOrFetch('reverse', { latitude: lat, longitude: lng, countryCode: 'cd' }, {
    path: '/reverse',
    params: { lat, lon: lng, format: 'jsonv2', addressdetails: 1, zoom: 18 },
  });
  const normalized = response.result ? normalizeResult(response.result) : null;
  const countryCode = String(normalized?.address?.country_code || '').toLowerCase();
  if (normalized && countryCode && countryCode !== 'cd') {
    throw badRequest('Cette position ne se trouve pas en République démocratique du Congo.');
  }
  return { cached: response.cached, result: normalized };
}

module.exports = { reverseRdc, searchRdc };
