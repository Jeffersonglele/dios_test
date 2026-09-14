const prisma = require('../config/prisma');
const { createCrudController } = require('./crud.controller');
const { handleControllerError, notFound, pick } = require('./controller.utils');
const { serializeUser } = require('./auth.controller');

const USER_FIELDS = [
  'firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal',
  'telephoneE164', 'roleId', 'country', 'status', 'identity', 'addressId',
  'image', 'parrain', 'cityId', 'phoneVerified', 'accountType', 'otpPhone',
  'ageConfirmed',
];

const crud = createCrudController({
  delegate: 'user', resource: 'Utilisateur', fields: USER_FIELDS,
  filterFields: ['country', 'status', 'roleId', 'cityId', 'accountType'],
});

async function updateProfile(req, res, next) {
  try {
    const user = await prisma.user.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    const data = pick(req.body, USER_FIELDS);
    const updated = await prisma.user.update({ where: { id: user.id }, data });

    await prisma.authUser.updateMany({
      where: { legacyUserId: user.userId },
      data: pick(data, ['firstname', 'lastname', 'username', 'email', 'telephone', 'telephoneLocal', 'telephoneE164', 'image']),
    });
    return res.status(200).json({ data: serializeUser(updated) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setIdentityStatus(req, res, next) {
  try {
    const user = await prisma.user.findFirst({ where: { id: req.params.id, deletedAt: null } });
    if (!user) throw notFound('Utilisateur');
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { identity: req.body.identity, status: req.body.status },
    });
    return res.status(200).json({ data: serializeUser(updated) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = { ...crud, updateProfile, setIdentityStatus, USER_FIELDS };
