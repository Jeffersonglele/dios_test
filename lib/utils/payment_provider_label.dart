import 'package:flutter/material.dart';

/// Helper universel pour formater et afficher les modes de paiement sur TOUS les écrans :
/// Panier, Confirmation, Détails commande, Suivi, Dashboard Livreur, Admin & Restaurateur.

/// 1. Libellé lisible pour le mode de paiement
String? paymentProviderLabel(String? provider, {int? moyenPaiementID}) {
  final p = provider?.trim().toLowerCase();
  if (p != null && p.isNotEmpty) {
    switch (p) {
      case 'cash':
      case 'confirmed_cash':
      case 'espaces':
      case 'espèces':
      case 'cod':
        return 'Espèces (À la livraison)';

      case 'nyole':
      case 'awaiting_payment':
      case 'mobile_money':
      case 'mobile money':
        return 'Mobile Money';

      case 'wallet':
      case 'portefeuille':
        return 'Portefeuille Numérique';

      case 'fedapay':
        return 'FedaPay (En ligne)';

      case 'cinetpay':
        return 'CinetPay (Mobile Money)';

      case 'bank_transfer':
      case 'bank':
      case 'virement':
        return 'Virement bancaire';

      default:
        // Si c'est un code brut avec _ ou - (ex: CONFIRMED_CASH -> Confirmed Cash)
        final formatted = p.replaceAll('_', ' ').replaceAll('-', ' ');
        return formatted[0].toUpperCase() + formatted.substring(1);
    }
  }

  // Fallback sur le moyenPaiementID legacy s'il est fourni
  if (moyenPaiementID != null) {
    switch (moyenPaiementID) {
      case 1:
        return 'Espèces (À la livraison)';
      case 2:
        return 'Mobile Money';
      default:
        return 'Paiement en ligne';
    }
  }

  return null;
}

/// 2. Icône associée au mode de paiement
IconData paymentProviderIcon(String? provider, {int? moyenPaiementID}) {
  final p = provider?.trim().toLowerCase();
  if (p != null && p.isNotEmpty) {
    switch (p) {
      case 'cash':
      case 'confirmed_cash':
      case 'espaces':
      case 'espèces':
      case 'cod':
        return Icons.payments_rounded;

      case 'nyole':
      case 'awaiting_payment':
      case 'mobile_money':
      case 'mobile money':
      case 'cinetpay':
        return Icons.phone_android_rounded;

      case 'wallet':
      case 'portefeuille':
        return Icons.account_balance_wallet_rounded;

      case 'bank_transfer':
      case 'bank':
      case 'virement':
        return Icons.account_balance_rounded;

      case 'fedapay':
      default:
        return Icons.credit_card_rounded;
    }
  }

  if (moyenPaiementID == 1) return Icons.payments_rounded;
  if (moyenPaiementID == 2) return Icons.phone_android_rounded;
  return Icons.credit_card_rounded;
}

/// 3. Couleur principale associée au mode de paiement
Color paymentProviderColor(String? provider, {int? moyenPaiementID}) {
  final p = provider?.trim().toLowerCase();
  if (p != null && p.isNotEmpty) {
    switch (p) {
      case 'cash':
      case 'confirmed_cash':
        return const Color(0xFF2E7D32); // Vert profond pour cash

      case 'nyole':
      case 'awaiting_payment':
      case 'mobile_money':
      case 'cinetpay':
        return const Color(0xFFE65100); // Orange Mobile Money

      case 'wallet':
      case 'portefeuille':
        return const Color(0xFF1565C0); // Bleu Portefeuille

      case 'fedapay':
      case 'bank_transfer':
      default:
        return const Color(0xFF6A1B9A); // Violet paiement carte/banque
    }
  }

  if (moyenPaiementID == 1) return const Color(0xFF2E7D32);
  if (moyenPaiementID == 2) return const Color(0xFFE65100);
  return const Color(0xFF1565C0);
}

/// 4. Badge UI réutilisable pour afficher le mode de paiement avec icône et fond teinté
class PaymentProviderBadge extends StatelessWidget {
  const PaymentProviderBadge({
    super.key,
    this.provider,
    this.moyenPaiementID,
    this.showIcon = true,
    this.dense = false,
  });

  final String? provider;
  final int? moyenPaiementID;
  final bool showIcon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final label = paymentProviderLabel(provider, moyenPaiementID: moyenPaiementID);
    if (label == null) return const SizedBox.shrink();

    final icon = paymentProviderIcon(provider, moyenPaiementID: moyenPaiementID);
    final color = paymentProviderColor(provider, moyenPaiementID: moyenPaiementID);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: dense ? 14 : 16, color: color),
            SizedBox(width: dense ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
