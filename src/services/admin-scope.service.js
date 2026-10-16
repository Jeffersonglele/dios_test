// Périmètre d'un administrateur : un admin gère uniquement son pays, le
// super admin gère tout. Les actions sensibles sont tracées dans audit_logs.

const prisma = require('../config/prisma');
const { canonicalCountry } = require('./country.service');

function roleIds(envName, fallback) {
  return String(process.env[envName] || fallback)
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
}

function isSuperAdminRole(roleId) {
  return roleIds('SUPER_ADMIN_ROLE_IDS', '4').includes(Number(roleId));
}

function forbidden(message) {
  const error = new Error(message);
  error.statusCode = 403;
  return error;
}

/// Admin connecté : { userId, isSuperAdmin, country, name }. Le pays est lu
/// en base (jamais dans la requête) pour qu'un admin ne puisse pas en changer.
async function adminContext(req) {
  if (req.adminContext) return req.adminContext;
  const userId = Number(req.auth?.userId);
  const user = Number.isInteger(userId)
    ? await prisma.user.findFirst({
        where: { userId, deletedAt: null },
        select: { firstname: true, lastname: true, username: true, email: true, country: true, roleId: true },
      })
    : null;
  const context = {
    userId,
    isSuperAdmin: isSuperAdminRole(user?.roleId ?? req.auth?.roleId),
    country: canonicalCountry(user?.country) || null,
    name: [user?.firstname, user?.lastname].filter(Boolean).join(' ') || user?.username || user?.email || `Admin ${userId}`,
  };
  req.adminContext = context;
  return context;
}

/// Lève 403 si un admin (non super admin) agit hors de son pays.
function assertCountryInScope(context, targetCountry) {
  if (context.isSuperAdmin) return;
  const target = canonicalCountry(targetCountry);
  if (!context.country || !target || target !== context.country) {
    throw forbidden('Cette action concerne un autre pays que le vôtre.');
  }
}

function requireSuperAdmin(context) {
  if (!context.isSuperAdmin) throw forbidden('Action réservée au super administrateur.');
}

/// Pays à appliquer à une liste : celui de l'admin, ou le filtre demandé
/// par le super admin (null = tous les pays).
function scopedCountry(context, requested) {
  if (!context.isSuperAdmin) return context.country;
  return requested ? canonicalCountry(requested) : null;
}

/// Middleware pour les listes génériques (?country=…) : un admin ne voit
/// que son pays, quel que soit le filtre envoyé.
async function scopeCountryQuery(req, res, next) {
  try {
    const context = await adminContext(req);
    if (!context.isSuperAdmin) {
      if (!context.country) throw forbidden('Aucun pays n’est rattaché à votre compte administrateur.');
      req.query.country = context.country;
    }
    return next();
  } catch (error) {
    return next(error);
  }
}

/// Trace une action d'administration (non bloquant si l'écriture échoue).
async function recordAudit(req, action, details, country) {
  try {
    const context = await adminContext(req);
    await prisma.auditLog.create({
      data: {
        action,
        details: typeof details === 'string' ? details : JSON.stringify(details),
        userName: context.name,
        country: canonicalCountry(country) || context.country || null,
      },
    });
  } catch (error) {
    console.error('[audit] écriture impossible', { action, message: error?.message });
  }
}

module.exports = {
  adminContext,
  assertCountryInScope,
  isSuperAdminRole,
  recordAudit,
  requireSuperAdmin,
  scopeCountryQuery,
  scopedCountry,
};
