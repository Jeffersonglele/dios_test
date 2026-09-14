const prisma = require('../config/prisma');
const {
  handleControllerError,
  notFound,
  pagination,
  pick,
  sendPage,
} = require('./controller.utils');

/**
 * Creates conventional list/get/create/update/delete actions for a Prisma
 * delegate. The `fields` whitelist prevents request bodies from changing
 * technical fields such as `id`, `createdAt` or `deletedAt`.
 */
function createCrudController({
  delegate,
  resource,
  fields,
  defaultOrderBy = { createdAt: 'desc' },
  hasSoftDelete = true,
  filterFields = [],
}) {
  const repository = prisma[delegate];

  function buildWhere(query = {}) {
    const where = {};
    if (hasSoftDelete && query.includeDeleted !== 'true') where.deletedAt = null;

    for (const field of filterFields) {
      if (query[field] !== undefined && query[field] !== '') {
        where[field] = query[field];
      }
    }
    return where;
  }

  return {
    async list(req, res, next) {
      try {
        const pageInfo = pagination(req.query);
        const where = buildWhere(req.query);
        const [data, total] = await prisma.$transaction([
          repository.findMany({
            where,
            skip: pageInfo.skip,
            take: pageInfo.take,
            orderBy: defaultOrderBy,
          }),
          repository.count({ where }),
        ]);
        return sendPage(res, data, total, pageInfo);
      } catch (error) {
        return handleControllerError(error, next);
      }
    },

    async getById(req, res, next) {
      try {
        const where = { id: req.params.id };
        if (hasSoftDelete) where.deletedAt = null;
        const record = await repository.findFirst({ where });
        if (!record) throw notFound(resource);
        return res.status(200).json({ data: record });
      } catch (error) {
        return handleControllerError(error, next);
      }
    },

    async create(req, res, next) {
      try {
        const record = await repository.create({ data: pick(req.body, fields) });
        return res.status(201).json({ data: record });
      } catch (error) {
        return handleControllerError(error, next);
      }
    },

    async update(req, res, next) {
      try {
        const existing = await repository.findUnique({ where: { id: req.params.id } });
        if (!existing || (hasSoftDelete && existing.deletedAt)) throw notFound(resource);

        const record = await repository.update({
          where: { id: req.params.id },
          data: pick(req.body, fields),
        });
        return res.status(200).json({ data: record });
      } catch (error) {
        return handleControllerError(error, next);
      }
    },

    async remove(req, res, next) {
      try {
        const existing = await repository.findUnique({ where: { id: req.params.id } });
        if (!existing || (hasSoftDelete && existing.deletedAt)) throw notFound(resource);

        const record = hasSoftDelete
          ? await repository.update({
              where: { id: req.params.id },
              data: { deletedAt: new Date() },
            })
          : await repository.delete({ where: { id: req.params.id } });

        return res.status(200).json({ data: record });
      } catch (error) {
        return handleControllerError(error, next);
      }
    },
  };
}

module.exports = { createCrudController };
