const { Prisma } = require('@prisma/client');

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;

function pagination(query = {}) {
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const requestedSize = Number.parseInt(query.pageSize || query.limit, 10);
  const pageSize = Math.min(
    MAX_PAGE_SIZE,
    Math.max(1, requestedSize || DEFAULT_PAGE_SIZE),
  );

  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}

function canonicalCountry(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (
    normalized === 'rdc' ||
    normalized === 'cd' ||
    normalized.includes('république démocratique') ||
    normalized.includes('republique democratique') ||
    normalized.includes('democratic republic') ||
    normalized === 'congo' ||
    normalized === 'cod'
  ) {
    return 'RDC';
  }
  if (normalized === 'bénin' || normalized === 'benin' || normalized === 'bj') {
    return 'Bénin';
  }
  return value || '';
}

function pick(source = {}, allowedFields = []) {
  return allowedFields.reduce((data, field) => {
    if (source[field] !== undefined) data[field] = source[field];
    return data;
  }, {});
}

function sendPage(res, records, total, pageInfo) {
  return res.status(200).json({
    data: records,
    meta: {
      page: pageInfo.page,
      pageSize: pageInfo.pageSize,
      total,
      totalPages: Math.ceil(total / pageInfo.pageSize),
    },
  });
}

function notFound(resource) {
  const error = new Error(`${resource} introuvable.`);
  error.statusCode = 404;
  return error;
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

function conflict(message) {
  const error = new Error(message);
  error.statusCode = 409;
  return error;
}

function isPrismaUniqueError(error) {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

function handleControllerError(error, next) {
  if (isPrismaUniqueError(error)) {
    return next(conflict('Cette valeur existe déjà.'));
  }
  return next(error);
}

function isValidUUID(str) {
  return typeof str === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(str.trim());
}

module.exports = {
  badRequest,
  canonicalCountry,
  conflict,
  handleControllerError,
  isValidUUID,
  notFound,
  pagination,
  pick,
  sendPage,
};
