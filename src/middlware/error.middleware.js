const { Prisma } = require('@prisma/client');

function notFoundHandler(req, res) {
  return res.status(404).json({ error: { message: `Route introuvable : ${req.method} ${req.originalUrl}` } });
}

function errorHandler(error, req, res, next) { // eslint-disable-line no-unused-vars
  let statusCode = error.statusCode || 500;
  let message = error.message || 'Une erreur interne est survenue.';

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') {
      statusCode = 409;
      message = 'Cette valeur existe déjà.';
    } else if (error.code === 'P2025') {
      statusCode = 404;
      message = 'Ressource introuvable.';
    } else {
      statusCode = 400;
      message = 'La requête ne respecte pas les contraintes de données.';
    }
  }

  if (statusCode >= 500) console.error(error);
  return res.status(statusCode).json({
    error: {
      message,
      ...(process.env.NODE_ENV === 'development' ? { stack: error.stack } : {}),
    },
  });
}

module.exports = { errorHandler, notFoundHandler };
