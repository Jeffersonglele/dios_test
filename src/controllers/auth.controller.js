const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { randomUUID } = require('crypto');

const prisma = require('../config/prisma');
const {
  badRequest,
  conflict,
  handleControllerError,
  notFound,
  pick,
} = require('./controller.utils');

const PROFILE_FIELDS = [
  'firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal',
  'telephoneE164', 'roleId', 'country', 'status', 'identity', 'addressId',
  'image', 'parrain', 'cityId', 'phoneVerified', 'accountType', 'otpPhone',
  'ageConfirmed',
];

function serializeUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  return safeUser;
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

async function nextLegacyUserId(tx) {
  const lastUser = await tx.user.findFirst({
    where: { userId: { not: null } },
    orderBy: { userId: 'desc' },
    select: { userId: true },
  });
  return (lastUser?.userId || 0) + 1;
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
    if (existing) throw conflict('Un compte utilise déjà cet email ou ce nom d’utilisateur.');

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.$transaction(async (tx) => {
      const userId = await nextLegacyUserId(tx);
      const profileData = pick(req.body, PROFILE_FIELDS);

      await tx.authUser.create({
        data: {
          username: normalizedUsername,
          email: normalizedEmail,
          password: passwordHash,
          legacyUserId: userId,
          firstname: profileData.firstname,
          lastname: profileData.lastname,
          telephone: profileData.telephone,
          telephoneLocal: profileData.telephoneLocal,
          telephoneE164: profileData.telephoneE164,
          image: profileData.image,
        },
      });

      return tx.user.create({
        data: {
          ...profileData,
          userId,
          username: normalizedUsername,
          email: normalizedEmail,
          password: passwordHash,
        },
      });
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

async function requestPasswordReset(req, res, next) {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    if (!email) throw badRequest('L’email est obligatoire.');

    const user = await prisma.authUser.findUnique({ where: { email } });
    // The response stays identical to avoid disclosing existing accounts.
    if (user && !user.deletedAt) {
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await prisma.verificationCode.create({
        data: { email, code, purpose: 'password_reset', expiresAt: new Date(Date.now() + 15 * 60 * 1000) },
      });
      // Email delivery is intentionally delegated to a future notification service.
    }
    return res.status(200).json({ data: { message: 'Si ce compte existe, un code a été envoyé.' } });
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
    const authUser = await prisma.authUser.findUnique({ where: { email: verification.email } });
    if (!authUser) throw notFound('Utilisateur');

    await prisma.$transaction([
      prisma.authUser.update({ where: { id: authUser.id }, data: { password: passwordHash } }),
      prisma.user.updateMany({ where: { userId: authUser.legacyUserId }, data: { password: passwordHash } }),
      prisma.verificationCode.update({ where: { id: verification.id }, data: { verified: true } }),
    ]);
    return res.status(200).json({ data: { message: 'Mot de passe mis à jour.' } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { login, me, register, requestPasswordReset, resetPassword, serializeUser };
