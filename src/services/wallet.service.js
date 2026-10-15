const prisma = require('../config/prisma');
const { currencyForCountry } = require('./country.service');

/// Portefeuille du client, créé au besoin dans la devise de son pays
/// (CDF pour la RDC, XOF pour le Bénin). Un portefeuille vide encore dans
/// une autre devise (créé avant cette règle) est réaligné sur le pays.
async function ensureWalletForUser(userId, db = prisma) {
  const user = await db.user.findFirst({
    where: { userId, deletedAt: null },
    select: { country: true },
  });
  const currency = currencyForCountry(user?.country);

  const wallet = await db.walletAccount.findUnique({ where: { userId } });
  if (!wallet) {
    return db.walletAccount.create({
      data: { userId, currency, balance: 0, status: 'ACTIVE' },
    });
  }
  if (Number(wallet.balance || 0) === 0
    && String(wallet.currency || '').toUpperCase() !== currency) {
    return db.walletAccount.update({ where: { id: wallet.id }, data: { currency } });
  }
  return wallet;
}

module.exports = { ensureWalletForUser };
