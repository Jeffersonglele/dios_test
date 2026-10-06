const prisma = require('../config/prisma');
const { badRequest, handleControllerError, notFound, pagination, sendPage } = require('./controller.utils');

const SUPPORTED_OPERATORS = new Set(['MPESA', 'ORANGE_MONEY', 'AIRTEL_MONEY']);

function normalizeRdcPhone(value) {
  const phone = String(value || '').replace(/[\s().-]/g, '');
  if (!/^\+243\d{9}$/.test(phone)) {
    throw badRequest('Le numéro Mobile Money doit être au format RDC +243XXXXXXXXX.');
  }
  return phone;
}

function normalizeOperator(value) {
  const operator = String(value || '').trim().toUpperCase();
  if (!SUPPORTED_OPERATORS.has(operator)) {
    throw badRequest('Opérateur invalide. Utilisez MPESA, ORANGE_MONEY ou AIRTEL_MONEY.');
  }
  return operator;
}

async function walletSummary(req, res, next) {
  try {
    let wallet = await prisma.walletAccount.findUnique({ where: { userId: req.auth.userId } });

    if (!wallet) {
      wallet = await prisma.walletAccount.create({
        data: {
          userId: req.auth.userId,
          currency: 'CDF',
          balance: 0,
          status: 'ACTIVE',
        },
      });
    }

    const ledgerEntries = await prisma.walletLedgerEntry.findMany({
      where: { walletAccountId: wallet.id },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    return res.status(200).json({
      data: {
        id: wallet.id,
        userId: wallet.userId,
        currency: wallet.currency,
        balance: Number(wallet.balance),
        status: wallet.status,
        ledgerEntries,
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function walletLedger(req, res, next) {
  try {
    const wallet = await prisma.walletAccount.findUnique({ where: { userId: req.auth.userId } });
    if (!wallet) return sendPage(res, [], 0, pagination(req.query));
    const pageInfo = pagination(req.query);
    const where = { walletAccountId: wallet.id };
    const [data, total] = await prisma.$transaction([
      prisma.walletLedgerEntry.findMany({ where, skip: pageInfo.skip, take: pageInfo.take, orderBy: { createdAt: 'desc' } }),
      prisma.walletLedgerEntry.count({ where }),
    ]);
    return sendPage(res, data, total, pageInfo);
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function requestTopUp(req, res, next) {
  const error = new Error('Le portefeuille Dios Delices est désactivé tant que le partenaire de paiement et le cadre RDC ne sont pas validés.');
  error.statusCode = 503;
  return next(error);
}

async function topUpWallet(req, res, next) {
  try {
    const { amount, referenceId } = req.body;
    const userId = req.auth.userId;

    if (!amount || !Number.isFinite(amount) || amount <= 0) {
      throw badRequest('Le montant doit être strictement positif');
    }
    if (!referenceId || typeof referenceId !== 'string' || referenceId.trim() === '') {
      throw badRequest('referenceId est obligatoire');
    }

    const result = await prisma.$transaction(async (tx) => {
      let wallet = await tx.walletAccount.findUnique({ where: { userId } });

      if (!wallet) {
        wallet = await tx.walletAccount.create({
          data: {
            userId,
            currency: 'CDF',
            balance: 0,
            status: 'ACTIVE',
          },
        });
      }

      const ledgerEntry = await tx.walletLedgerEntry.create({
        data: {
          walletAccountId: wallet.id,
          direction: 'CREDIT',
          amount: Number(amount),
          currency: wallet.currency,
          status: 'COMPLETED',
          referenceType: 'TOP_UP',
          referenceId: referenceId.trim(),
          description: 'Recharge de portefeuille',
          postedAt: new Date(),
        },
      });

      const updatedWallet = await tx.walletAccount.update({
        where: { id: wallet.id },
        data: {
          balance: {
            increment: Number(amount),
          },
        },
      });

      return { wallet: updatedWallet, ledgerEntry };
    });

    return res.status(200).json({
      data: {
        wallet: result.wallet,
        ledgerEntry: result.ledgerEntry,
        newBalance: Number(result.wallet.balance),
      },
    });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function listMobileMoneyAccounts(req, res, next) {
  try {
    const data = await prisma.mobileMoneyAccount.findMany({
      where: { userId: req.auth.userId }, orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
    return res.status(200).json({ data });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function createMobileMoneyAccount(req, res, next) {
  try {
    const operator = normalizeOperator(req.body.operator);
    const phoneE164 = normalizeRdcPhone(req.body.phoneE164);
    const count = await prisma.mobileMoneyAccount.count({ where: { userId: req.auth.userId } });
    const account = await prisma.mobileMoneyAccount.create({
      data: {
        userId: req.auth.userId,
        operator,
        phoneE164,
        label: req.body.label ? String(req.body.label).trim().slice(0, 60) : null,
        isDefault: req.body.isDefault === true || count === 0,
      },
    });
    if (account.isDefault) {
      await prisma.mobileMoneyAccount.updateMany({
        where: { userId: req.auth.userId, id: { not: account.id } }, data: { isDefault: false },
      });
    }
    return res.status(201).json({ data: account });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function setDefaultMobileMoneyAccount(req, res, next) {
  try {
    const account = await prisma.mobileMoneyAccount.findFirst({ where: { id: req.params.id, userId: req.auth.userId } });
    if (!account) throw notFound('Numéro Mobile Money');
    await prisma.$transaction([
      prisma.mobileMoneyAccount.updateMany({ where: { userId: req.auth.userId }, data: { isDefault: false } }),
      prisma.mobileMoneyAccount.update({ where: { id: account.id }, data: { isDefault: true } }),
    ]);
    return res.status(200).json({ data: await prisma.mobileMoneyAccount.findUnique({ where: { id: account.id } }) });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

async function removeMobileMoneyAccount(req, res, next) {
  try {
    const account = await prisma.mobileMoneyAccount.findFirst({ where: { id: req.params.id, userId: req.auth.userId } });
    if (!account) throw notFound('Numéro Mobile Money');
    await prisma.mobileMoneyAccount.delete({ where: { id: account.id } });
    return res.status(200).json({ data: { id: account.id, deleted: true } });
  } catch (error) {
    return handleControllerError(error, next);
  }
}

module.exports = {
  createMobileMoneyAccount,
  listMobileMoneyAccounts,
  removeMobileMoneyAccount,
  requestTopUp,
  setDefaultMobileMoneyAccount,
  topUpWallet,
  walletLedger,
  walletSummary,
};
