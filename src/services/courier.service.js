// Dossier livreur : statut d'identité, type de véhicule et contrôle d'accès
// aux courses. Un livreur ne peut travailler qu'une fois son dossier (photo,
// pièce d'identité, permis) validé par l'administration.

const prisma = require('../config/prisma');

/// Valeurs écrites dans users.identity (lues telles quelles par l'app).
const IDENTITY = Object.freeze({
  VERIFIED: 'Verified',
  PENDING: 'En attente',
  REJECTED: 'Rejected',
});

/// Anciennes valeurs encore présentes en base (Parse, ancien admin).
const VERIFIED_IDENTITY_VALUES = ['Verified', 'Vérifiée', 'verified', 'approved'];

function normalized(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim()
    .toLowerCase();
}

function isIdentityVerified(value) {
  return ['verified', 'verifiee', 'approved', 'validated'].includes(normalized(value));
}

const VEHICLE_TYPES = Object.freeze(['moto', 'velo', 'voiture']);

/// « Vélo », « bike », « MOTO »… → moto | velo | voiture, ou null.
function normalizeVehicleType(value) {
  const v = normalized(value);
  if (!v) return null;
  if (v === 'moto' || v === 'motorcycle' || v === 'scooter') return 'moto';
  if (v === 'velo' || v === 'bike' || v === 'bicycle') return 'velo';
  if (v === 'voiture' || v === 'car' || v === 'auto') return 'voiture';
  return null;
}

/// « ab-123 cd » → « AB-123 CD » ; null si vide ou invalide.
function normalizePlate(value) {
  const plate = String(value || '').trim().toUpperCase().replace(/\s+/g, ' ');
  if (!plate) return null;
  return /^[A-Z0-9][A-Z0-9 -]{1,14}$/.test(plate) ? plate : null;
}

/// Profil public d'un livreur pour une commande : ce que le client et le
/// restaurant voient (jamais l'email ni les documents).
function courierPublicProfile(user, { includePhone = false } = {}) {
  if (!user) return null;
  const firstname = String(user.firstname || '').trim();
  const lastname = String(user.lastname || '').trim();
  return {
    userId: user.userId,
    firstname,
    lastname,
    displayName: [firstname, lastname].filter(Boolean).join(' ') || user.username || `Livreur ${user.userId}`,
    photoUrl: user.image || null,
    vehicleType: user.vehicleType || null,
    vehiclePlate: user.vehiclePlate || null,
    ...(includePhone ? { phone: user.telephoneE164 || user.telephone || null } : {}),
  };
}

/// Le permis n'est pas exigé à vélo.
function vehicleNeedsLicense(vehicleType) {
  return normalizeVehicleType(vehicleType) !== 'velo';
}

/// Middleware : refuse les actions de travail (se mettre en ligne, voir ou
/// accepter des courses) tant que le dossier n'est pas validé. Se mettre
/// hors ligne reste toujours possible.
function requireVerifiedCourier({ allowGoingOffline = false } = {}) {
  return async (req, res, next) => {
    try {
      if (allowGoingOffline) {
        const raw = String(req.body?.status ?? '').trim().toUpperCase();
        if (['', 'FALSE', '0', 'OFFLINE', 'INACTIVE', 'UNAVAILABLE'].includes(raw)) return next();
      }
      const user = await prisma.user.findFirst({
        where: { userId: Number(req.auth?.userId), deletedAt: null },
        select: { identity: true },
      });
      if (user && isIdentityVerified(user.identity)) return next();
      const error = new Error(
        normalized(user?.identity) === normalized(IDENTITY.PENDING)
          ? 'Votre dossier livreur est en cours de vérification.'
          : 'Envoyez votre photo et vos documents pour pouvoir livrer.',
      );
      error.statusCode = 403;
      error.code = 'COURIER_NOT_VERIFIED';
      return next(error);
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = {
  courierPublicProfile,
  normalizePlate,
  IDENTITY,
  VEHICLE_TYPES,
  VERIFIED_IDENTITY_VALUES,
  isIdentityVerified,
  normalizeVehicleType,
  requireVerifiedCourier,
  vehicleNeedsLicense,
};
