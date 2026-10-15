// Codes promo : une seule règle de calcul pour la vérification dans le panier
// et pour la commande. Le serveur recalcule toujours la réduction ; le
// montant envoyé par l'app n'est jamais utilisé.

const { badRequest, conflict } = require('../controllers/controller.utils');

/// Commandes qui « consomment » un code (une annulée le libère).
const RELEASED_STATUSES = ['CANCELLED', 'REFUSED'];

function normalizeCode(value) {
  return String(value || '').trim().toUpperCase();
}

/// Vérifie le code pour ce client et ce sous-total (plats, hors livraison).
/// Renvoie { promo, discount } ou lève une erreur lisible.
async function evaluatePromo(db, { code: rawCode, subtotal, userId }) {
  const code = normalizeCode(rawCode);
  if (!code) throw badRequest('Saisissez un code promo.');
  const orderAmount = Number(subtotal);
  if (!Number.isFinite(orderAmount) || orderAmount <= 0) {
    throw badRequest('Le panier est vide.');
  }

  const promo = await db.promoCode.findFirst({ where: { code, deletedAt: null } });
  const now = new Date();
  if (!promo || !promo.active) throw badRequest('Ce code promo n’existe pas ou n’est plus actif.');
  if (promo.validFrom && promo.validFrom > now) throw badRequest('Ce code promo n’est pas encore valable.');
  if (promo.validUntil && promo.validUntil < now) throw badRequest('Ce code promo a expiré.');
  if (promo.maxUses !== null && promo.maxUses !== undefined && promo.usedCount >= promo.maxUses) {
    throw badRequest('Ce code promo a atteint son nombre maximal d’utilisations.');
  }
  if (promo.minOrder !== null && promo.minOrder !== undefined && orderAmount < Number(promo.minOrder)) {
    throw badRequest(`Ce code est valable à partir de ${Number(promo.minOrder)} de commande (hors livraison).`);
  }

  // Un même client ne profite qu'une fois d'un code.
  const numericUserId = Number(userId);
  if (Number.isInteger(numericUserId)) {
    const alreadyUsed = await db.order.count({
      where: {
        userId: numericUserId,
        promoCode: code,
        deletedAt: null,
        status: { notIn: RELEASED_STATUSES },
      },
    });
    if (alreadyUsed > 0) throw badRequest('Vous avez déjà utilisé ce code promo.');
  }

  let discount = 0;
  if (promo.discountPercent && Number(promo.discountPercent) > 0) {
    discount = (orderAmount * Number(promo.discountPercent)) / 100;
  } else if (promo.discountFixed && Number(promo.discountFixed) > 0) {
    discount = Number(promo.discountFixed);
  }
  // Montants entiers (CDF, XOF) et jamais plus que les plats.
  discount = Math.min(Math.round(discount), Math.floor(orderAmount));
  if (discount <= 0) throw badRequest('Ce code promo ne donne aucune réduction sur ce panier.');
  return { promo, discount };
}

/// Réserve une utilisation du code dans la transaction de commande. Échoue
/// si la limite vient d'être atteinte par une autre commande.
async function consumePromo(tx, promo) {
  const claimed = await tx.promoCode.updateMany({
    where: {
      id: promo.id,
      active: true,
      deletedAt: null,
      ...(promo.maxUses !== null && promo.maxUses !== undefined
        ? { usedCount: { lt: promo.maxUses } }
        : {}),
    },
    data: { usedCount: { increment: 1 } },
  });
  if (claimed.count !== 1) {
    throw conflict('Ce code promo vient d’atteindre sa limite. Retirez-le pour commander.');
  }
}

/// Commande annulée ou refusée : l'utilisation du code est rendue.
async function releasePromo(tx, order) {
  const code = normalizeCode(order?.promoCode);
  if (!code) return;
  await tx.promoCode.updateMany({
    where: { code, usedCount: { gt: 0 } },
    data: { usedCount: { decrement: 1 } },
  });
}

module.exports = { consumePromo, evaluatePromo, normalizeCode, releasePromo };
