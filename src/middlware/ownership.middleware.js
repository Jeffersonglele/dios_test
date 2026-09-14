const prisma = require('../config/prisma');

function configuredAdminRoleIds() {
  return String(process.env.ADMIN_ROLE_IDS || '')
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
}

async function userOwnerOrAdmin(req, res, next) {
  try {
    const user = await prisma.user.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!user) {
      const error = new Error('Utilisateur introuvable.');
      error.statusCode = 404;
      return next(error);
    }
    const isOwner = req.auth?.userId === user.userId;
    const isAdmin = configuredAdminRoleIds().includes(req.auth?.roleId);
    if (!isOwner && !isAdmin) {
      const error = new Error('Vous ne pouvez modifier que votre propre profil.');
      error.statusCode = 403;
      return next(error);
    }
    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = { userOwnerOrAdmin };
