const { Prisma } = require('@prisma/client');

function notFoundHandler(req, res) {
  return res.status(404).json({ error: { message: `Route introuvable : ${req.method} ${req.originalUrl}` } });
}

function errorHandler(error, req, res, next) { // eslint-disable-line no-unused-vars
  let statusCode = error.statusCode || 500;
  let message = error.message || 'Une erreur interne est survenue.';

  if (error instanceof SyntaxError && error.status === 400 && error.type === 'entity.parse.failed') {
    statusCode = 400;
    message = 'Le corps JSON est invalide.';
  } else if (error.type === 'entity.too.large') {
    statusCode = 413;
    message = 'La requête est trop volumineuse.';
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    console.error('[Prisma Request Error]', { code: error.code, message: error.message, meta: error.meta });
    if (error.code === 'P2002') {
      statusCode = 409;
      message = 'Cette valeur existe déjà.';
    } else if (error.code === 'P2025') {
      statusCode = 404;
      message = 'Ressource introuvable.';
    } else {
      statusCode = 400;
      message = `La requête ne respecte pas les contraintes de données. (${error.code}${error.meta?.target ? `: ${error.meta.target}` : ''})`;
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
