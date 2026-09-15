const prisma = require('../config/prisma');
const { badRequest, handleControllerError, notFound, pagination, pick, sendPage } = require('./controller.utils');

const fields = [
  'streetNumber', 'city', 'state', 'country', 'fullAddress',
];

async function nextAddressId(tx) {
  const last = await tx.address.findFirst({
    where: { addressId: { not: null } }, orderBy: { addressId: 'desc' }, select: { addressId: true },
  });
  return (last?.addressId || 0) + 1;
}

async function list(req, res, next) {
  try {
    const pageInfo = pagination(req.query);
    const where = { objectType: 'USER', objectId: req.auth.userId, deletedAt: null };
    const [data, total] = await prisma.$transaction([
      prisma.address.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { updatedAt: 'desc' } }),
      prisma.address.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function create(req, res, next) {
  try {
    if (!req.body.fullAddress) throw badRequest('Une adresse lisible est obligatoire.');
    const address = await prisma.$transaction(async (tx) => tx.address.create({
      data: {
        ...pick(req.body, fields),
        addressId: await nextAddressId(tx),
        objectType: 'USER',
        objectId: req.auth.userId,
        country: req.body.country || 'RDC',
      },
    }));
    return res.status(201).json({ data: address });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function getById(req, res, next) {
  try {
    const address = await prisma.address.findFirst({
      where: { id: req.params.id, objectType: 'USER', objectId: req.auth.userId, deletedAt: null },
    });
    if (!address) throw notFound('Adresse');
    return res.status(200).json({ data: address });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function update(req, res, next) {
  try {
    const address = await prisma.address.findFirst({
      where: { id: req.params.id, objectType: 'USER', objectId: req.auth.userId, deletedAt: null },
    });
    if (!address) throw notFound('Adresse');
    const updated = await prisma.address.update({ where: { id: address.id }, data: pick(req.body, fields) });
    return res.status(200).json({ data: updated });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function remove(req, res, next) {
  try {
    const address = await prisma.address.findFirst({
      where: { id: req.params.id, objectType: 'USER', objectId: req.auth.userId, deletedAt: null },
    });
    if (!address) throw notFound('Adresse');
    const removed = await prisma.address.update({ where: { id: address.id }, data: { deletedAt: new Date() } });
    return res.status(200).json({ data: removed });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { create, getById, list, remove, update };
