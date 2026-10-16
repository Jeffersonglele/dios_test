const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { randomInt } = require('crypto');

const prisma = require('../config/prisma');
const { canonicalCountry, resolveCityId } = require('../services/country.service');
const { normalizeVehicleType } = require('../services/courier.service');
const {
  sendPasswordResetCodeEmail,
  sendVerificationCodeEmail,
} = require('../services/email.service');
const {
  badRequest,
  conflict,
  handleControllerError,
  notFound,
  pick,
} = require('./controller.utils');

const REGISTRATION_FIELDS = [
  'firstname', 'lastname', 'telephone', 'telephoneLocal', 'telephoneE164',
  'country', 'cityId', 'accountType', 'ageConfirmed', 'vehicleType',
];

const ME_PATCH_FIELDS = [
  'firstname', 'lastname', 'telephone', 'telephoneLocal', 'telephoneE164',
  'image', 'maxDeliveryDistance',
];

function serializeUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  const courierStatus = String(safeUser.courierStatus || '').toUpperCase();
  // BUSY = en course : le livreur reste en ligne (sinon l'app le passe hors ligne).
  const isOnline = ['ACTIVE', 'ONLINE', 'AVAILABLE', 'BUSY'].includes(courierStatus);
  return { ...safeUser, isOnline };
}

function issueToken(user) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET doit être défini dans les variables d’environnement.');
  return jwt.sign(
    { sub: user.id, userId: user.userId, roleId: user.roleId },
    secret,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
  );
}

function courierRoleId() {
  const configured = Number.parseInt(process.env.COURIER_ROLE_ID || '5', 10);
  return Number.isInteger(configured) ? configured : 5;
}

function restaurateurRoleId() {
  const configured = Number.parseInt(process.env.RESTAURATEUR_ROLE_ID || '3', 10);
  return Number.isInteger(configured) ? configured : 3;
}

function defaultUserRoleId() {
  const configured = Number.parseInt(process.env.DEFAULT_USER_ROLE_ID || '2', 10);
  return Number.isInteger(configured) ? configured : 2;
}

function resolveRegistrationRole(accountTypeInput) {
  const type = String(accountTypeInput || '').trim().toUpperCase();
  if (type === 'LIVREUR' || type === 'COURIER' || type === 'DELIVERY' || type === 'DELIVERER') {
    return { roleId: courierRoleId(), accountType: 'LIVREUR' };
  }
  if (type === 'RESTAURATEUR' || type === 'RESTAURANT') {
    return { roleId: restaurateurRoleId(), accountType: 'RESTAURATEUR' };
  }
  return { roleId: defaultUserRoleId(), accountType: 'CLIENT' };
}

/// Profil d'inscription nettoyé : pays canonique (« RDC », « Bénin ») et
/// ville rattachée quand elle peut être déduite sans ambiguïté.
async function registrationProfile(body, tx) {
  const profileData = pick(body, REGISTRATION_FIELDS);
  const { roleId, accountType } = resolveRegistrationRole(profileData.accountType);
  profileData.accountType = accountType;
  // Le véhicule ne concerne que les livreurs (moto par défaut).
  if (accountType === 'LIVREUR') {
    profileData.vehicleType = normalizeVehicleType(profileData.vehicleType) || 'moto';
  } else {
    delete profileData.vehicleType;
  }

  if (profileData.country !== undefined && profileData.country !== null && profileData.country !== '') {
    const country = canonicalCountry(profileData.country);
    if (!country) throw badRequest('Ce pays n’est pas encore ouvert sur Dios Délices.');
    profileData.country = country;
  }
  profileData.cityId = await resolveCityId(tx, profileData.country, profileData.cityId);
  return { profileData, roleId };
}

async function recoverOrphanedRegistration(existing, req, normalizedUsername, normalizedEmail, password) {
  const sameUsername = existing.username?.trim().toLowerCase() === normalizedUsername.toLowerCase();
  const sameEmail = existing.email?.trim().toLowerCase() === normalizedEmail;
  if (!sameUsername || !sameEmail || !(await bcrypt.compare(password, existing.password))) {
    return null;
  }

  const linkedProfile = existing.legacyUserId == null
    ? null
    : await prisma.user.findFirst({ where: { userId: existing.legacyUserId } });

  // Un compte complet existe déjà : le 409 est le comportement attendu.
  if (linkedProfile && !linkedProfile.deletedAt) return null;

  return prisma.$transaction(async (tx) => {
    const { profileData, roleId } = await registrationProfile(req.body, tx);
    const data = {
      ...profileData,
      roleId,
      username: normalizedUsername,
      email: normalizedEmail,
      // Le mot de passe existant a déjà été vérifié ci-dessus.
      password: existing.password,
      deletedAt: null,
    };

    // Nouveau profil : son userId vient de la séquence de « users », puis le
    // compte d'authentification est explicitement relié à ce userId.
    const user = linkedProfile
      ? await tx.user.update({ where: { id: linkedProfile.id }, data })
      : await tx.user.create({ data });

    await tx.authUser.update({
      where: { id: existing.id },
      data: {
        username: normalizedUsername,
        email: normalizedEmail,
        legacyUserId: user.userId,
        deletedAt: null,
        firstname: profileData.firstname,
        lastname: profileData.lastname,
        telephone: profileData.telephone,
        telephoneLocal: profileData.telephoneLocal,
        telephoneE164: profileData.telephoneE164,
      },
    });

    return user;
  });
}

async function register(req, res, next) {
  try {
    const { username, email, password } = req.body;
    if (!username || !email || !password) {
      throw badRequest('Les champs username, email et password sont obligatoires.');
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const normalizedUsername = String(username).trim();
    const existing = await prisma.authUser.findFirst({
      where: { OR: [{ username: normalizedUsername }, { email: normalizedEmail }] },
    });
    if (existing) {
      // Répare un compte d'authentification créé lors d'une tentative
      // interrompue, sans jamais reprendre un compte dont un seul identifiant
      // correspond ou dont le mot de passe est différent.
      const recovered = await recoverOrphanedRegistration(
        existing,
        req,
        normalizedUsername,
        normalizedEmail,
        password,
      );
      if (recovered) {
        return res.status(201).json({
          data: { user: serializeUser(recovered), token: issueToken(recovered) },
        });
      }
      throw conflict('Un compte utilise déjà cet email ou ce nom d’utilisateur.');
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.$transaction(async (tx) => {
      // Role, verification and account status are server-controlled fields.
      const { profileData, roleId } = await registrationProfile(req.body, tx);

      // Le profil est créé d'abord : le compte d'authentification reçoit
      // ensuite SON userId. Auparavant les deux tables comptaient chacune de
      // leur côté et un seul décalage reliait un compte au profil d'un autre.
      const created = await tx.user.create({
        data: {
          ...profileData,
          roleId,
          username: normalizedUsername,
          email: normalizedEmail,
          password: passwordHash,
        },
      });

      await tx.authUser.create({
        data: {
          username: normalizedUsername,
          email: normalizedEmail,
          password: passwordHash,
          firstname: profileData.firstname,
          lastname: profileData.lastname,
          telephone: profileData.telephone,
          telephoneLocal: profileData.telephoneLocal,
          telephoneE164: profileData.telephoneE164,
          image: profileData.image,
          legacyUserId: created.userId,
        },
      });

      return created;
    });

    return res.status(201).json({ data: { user: serializeUser(user), token: issueToken(user) } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function login(req, res, next) {
  try {
    const identifier = String(req.body.identifier || req.body.email || req.body.username || '').trim();
    const password = req.body.password;
    if (!identifier || !password) throw badRequest('Identifiant et mot de passe sont obligatoires.');

    const authUser = await prisma.authUser.findFirst({
      where: { OR: [{ email: identifier.toLowerCase() }, { username: identifier }] },
    });
    if (!authUser || authUser.deletedAt || !(await bcrypt.compare(password, authUser.password))) {
      const error = new Error('Identifiants incorrects.');
      error.statusCode = 401;
      throw error;
    }

    const user = await prisma.user.findFirst({ where: { userId: authUser.legacyUserId, deletedAt: null } });
    if (!user) throw notFound('Profil utilisateur');

    await Promise.all([
      prisma.authUser.update({ where: { id: authUser.id }, data: { updatedAt: new Date() } }),
      prisma.user.update({ where: { id: user.id }, data: { lastLogin: new Date() } }),
      prisma.userLogin.create({ data: { userId: user.userId, username: user.username, loginAt: new Date() } }),
    ]);

    return res.status(200).json({ data: { user: serializeUser(user), token: issueToken(user) } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function me(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) throw notFound('Utilisateur authentifié');
    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    return res.status(200).json({ data: serializeUser(user) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

/// État du compte lu sur Node : rôle à jour (une validation admin peut
/// l'avoir changé depuis la connexion), demande vendeur et demande Pro.
async function accountState(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) throw notFound('Utilisateur authentifié');
    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    const [restaurant, proRequest, courierFile] = await Promise.all([
      prisma.restaurant.findFirst({
        where: { userId, deletedAt: null },
        orderBy: { createdAt: 'asc' },
        select: { restaurantId: true, valid: true, reviewRemark: true, isPro: true },
      }),
      prisma.proDocument.findFirst({
        where: { userId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: { status: true, remark: true },
      }),
      prisma.identity.findFirst({
        where: { userId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: { status: true, remark: true },
      }),
    ]);
    return res.status(200).json({
      data: {
        userID: user.userId,
        roleID: user.roleId,
        country: user.country || '',
        restaurantID: restaurant?.restaurantId ?? 0,
        restaurantValid: restaurant ? Number(restaurant.valid ?? 0) : -1,
        restaurantRemark: restaurant?.reviewRemark || '',
        restaurantIsPro: restaurant?.isPro === true,
        proRequestStatus: proRequest?.status || '',
        proRequestRemark: proRequest?.remark || '',
        identity: user.identity || '',
        identityRemark: courierFile?.remark || '',
        vehicleType: user.vehicleType || '',
        vehiclePlate: user.vehiclePlate || '',
        image: user.image || '',
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function requestPasswordReset(req, res, next) {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    if (!email) throw badRequest('L’email est obligatoire.');

    const user = await prisma.authUser.findUnique({ where: { email } });
    // The response stays identical to avoid disclosing existing accounts.
    if (user && !user.deletedAt) {
      const code = String(randomInt(100000, 1000000));
      await prisma.verificationCode.create({
        data: { email, code, purpose: 'password_reset', expiresAt: new Date(Date.now() + 15 * 60 * 1000) },
      });
      // Envoi asynchrone (non bloquant) : la réponse HTTP ne dépend pas
      // de la disponibilité du serveur SMTP. Les erreurs sont journalisées.
      setImmediate(() => {
        sendPasswordResetCodeEmail({ to: email, code }).catch((err) => {
          console.error('[auth] Échec envoi email réinitialisation', {
            email,
            message: err?.message,
            cause: err?.cause?.message,
          });
        });
      });
    }
    return res.status(200).json({ data: { message: 'Si ce compte existe, un code a été envoyé.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function requestEmailVerification(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) throw notFound('Utilisateur authentifié');

    const user = await prisma.user.findFirst({
      where: { userId, deletedAt: null },
      select: { firstname: true, email: true },
    });
    if (!user?.email) throw badRequest('Aucune adresse e-mail associée à ce compte.');

    const code = String(randomInt(100000, 1000000));
    await prisma.verificationCode.create({
      data: {
        email: user.email.toLowerCase(),
        code,
        purpose: 'email_verification',
        expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      },
    });
    // Envoi asynchrone (non bloquant) : la réponse HTTP ne dépend pas
    // de la disponibilité du serveur SMTP. Les erreurs sont journalisées.
    setImmediate(() => {
      sendVerificationCodeEmail({ to: user.email, code, firstname: user.firstname }).catch((err) => {
        console.error('[auth] Échec envoi email vérification', {
          email: user.email,
          userId,
          message: err?.message,
          cause: err?.cause?.message,
        });
      });
    });
    return res.status(200).json({ data: { message: 'Code de vérification envoyé.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function confirmEmailVerification(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const code = String(req.body.code || '').trim();
    if (!userId || !code) throw badRequest('Le code de vérification est obligatoire.');

    const user = await prisma.user.findFirst({
      where: { userId, deletedAt: null },
      select: { userId: true, email: true },
    });
    if (!user?.email) throw badRequest('Aucune adresse e-mail associée à ce compte.');

    const verification = await prisma.verificationCode.findFirst({
      where: {
        email: user.email.toLowerCase(),
        code,
        purpose: 'email_verification',
        verified: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!verification) throw badRequest('Le code est invalide ou expiré.');

    await prisma.$transaction([
      prisma.verificationCode.update({ where: { id: verification.id }, data: { verified: true } }),
      prisma.authUser.updateMany({ where: { legacyUserId: user.userId }, data: { emailVerified: true } }),
      prisma.user.updateMany({ where: { userId: user.userId }, data: { status: 'Verified' } }),
    ]);
    return res.status(200).json({ data: { message: 'Adresse e-mail vérifiée.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function resetPassword(req, res, next) {
  try {
    const { email, code, password } = req.body;
    if (!email || !code || !password) throw badRequest('Email, code et nouveau mot de passe sont obligatoires.');

    const verification = await prisma.verificationCode.findFirst({
      where: {
        email: String(email).trim().toLowerCase(),
        code: String(code),
        purpose: 'password_reset',
        verified: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!verification) throw badRequest('Le code est invalide ou expiré.');

    const passwordHash = await bcrypt.hash(password, 12);
    const authUser = await prisma.authUser.findFirst({
      where: { email: verification.email, deletedAt: null },
    });
    if (!authUser) throw notFound('Utilisateur');

    await prisma.$transaction([
      prisma.authUser.updateMany({
        where: { email: verification.email, deletedAt: null },
        data: { password: passwordHash },
      }),
      prisma.user.updateMany({
        where: { userId: authUser.legacyUserId, deletedAt: null },
        // Un nouveau mot de passe satisfait le changement imposé (premier accès).
        data: { password: passwordHash, mustChangePassword: false },
      }),
      prisma.verificationCode.update({
        where: { id: verification.id },
        data: { verified: true },
      }),
    ]);
    return res.status(200).json({ data: { message: 'Mot de passe mis à jour.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function verifyPasswordResetCode(req, res, next) {
  try {
    const { email, code } = req.body;
    if (!email || !code) throw badRequest('Email et code sont obligatoires.');

    const verification = await prisma.verificationCode.findFirst({
      where: {
        email: String(email).trim().toLowerCase(),
        code: String(code).trim(),
        purpose: 'password_reset',
        verified: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!verification) throw badRequest('Le code est invalide ou expiré.');
    return res.status(200).json({ data: { valid: true, message: 'Code valide.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function updateMe(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) throw notFound('Utilisateur authentifié');
    const user = await prisma.user.findFirst({ where: { userId, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    const data = pick(req.body, ME_PATCH_FIELDS);
    const updated = await prisma.user.update({ where: { id: user.id }, data });
    if (Object.keys(pick(req.body, ['firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal', 'telephoneE164', 'image'])).length > 0) {
      await prisma.authUser.updateMany({
        where: { legacyUserId: userId },
        data: pick(req.body, ['firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal', 'telephoneE164', 'image']),
      });
    }
    return res.status(200).json({ data: serializeUser(updated) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function changePassword(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) throw notFound('Utilisateur authentifié');
    const { currentPassword, newPassword } = req.body;
    if (!newPassword || String(newPassword).length < 6) {
      throw badRequest('Le nouveau mot de passe doit comporter au moins 6 caractères.');
    }
    const authUser = await prisma.authUser.findFirst({
      where: { legacyUserId: userId, deletedAt: null },
    });
    if (!authUser) throw notFound('Compte d’authentification');
    if (currentPassword != null && String(currentPassword).trim().length > 0) {
      const matches = await bcrypt.compare(String(currentPassword), authUser.password);
      if (!matches) {
        const err = new Error('Le mot de passe actuel est incorrect.');
        err.statusCode = 401;
        throw err;
      }
    }
    const passwordHash = await bcrypt.hash(String(newPassword), 12);
    await prisma.$transaction([
      prisma.authUser.updateMany({
        where: { legacyUserId: userId, deletedAt: null },
        data: { password: passwordHash },
      }),
      prisma.user.updateMany({
        where: { userId: authUser.legacyUserId, deletedAt: null },
        // Un nouveau mot de passe satisfait le changement imposé (premier accès).
        data: { password: passwordHash, mustChangePassword: false },
      }),
    ]);
    return res.status(200).json({ data: { message: 'Mot de passe mis à jour.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  accountState,
  changePassword,
  confirmEmailVerification,
  login,
  issueToken,
  me,
  resetPassword,
  requestEmailVerification,
  requestPasswordReset,
  serializeUser,
  updateMe,
  verifyPasswordResetCode,
  register,
};
