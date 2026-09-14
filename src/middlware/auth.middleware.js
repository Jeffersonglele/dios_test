const jwt = require('jsonwebtoken');

function getBearerToken(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return null;
  return header.slice('Bearer '.length).trim() || null;
}

function authenticate(req, res, next) {
  const token = getBearerToken(req);
  if (!token) {
    const error = new Error('Authentification requise.');
    error.statusCode = 401;
    return next(error);
  }

  try {
    if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET doit être défini.');
    req.auth = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (_) {
    const error = new Error('Jeton invalide ou expiré.');
    error.statusCode = 401;
    return next(error);
  }
}

function optionalAuthenticate(req, res, next) {
  const token = getBearerToken(req);
  if (!token) return next();
  try {
    if (process.env.JWT_SECRET) req.auth = jwt.verify(token, process.env.JWT_SECRET);
  } catch (_) {
    // A public endpoint should remain accessible when a stale token is sent.
  }
  return next();
}

module.exports = { authenticate, optionalAuthenticate };
