function configuredRoleIds(name) {
  const key = `${name.toUpperCase()}_ROLE_IDS`;
  return String(process.env[key] || '')
    .split(',')
    .map((value) => Number.parseInt(value.trim(), 10))
    .filter(Number.isInteger);
}

function authorize(...roleGroups) {
  const allowedRoleIds = roleGroups.flatMap(configuredRoleIds);
  return (req, res, next) => {
    if (!req.auth) {
      const error = new Error('Authentification requise.');
      error.statusCode = 401;
      return next(error);
    }
    if (allowedRoleIds.length === 0) {
      const error = new Error('Les rôles autorisés ne sont pas configurés.');
      error.statusCode = 503;
      return next(error);
    }
    if (!allowedRoleIds.includes(req.auth.roleId)) {
      const error = new Error('Vous n’avez pas les droits nécessaires.');
      error.statusCode = 403;
      return next(error);
    }
    return next();
  };
}

module.exports = { authorize };
