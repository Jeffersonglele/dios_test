class PromoApplication {
  const PromoApplication({
    required this.code,
    required this.description,
    required this.discountAmount,
  });

  final String code;
  final String description;
  final double discountAmount;
}

class PromoService {
  static PromoApplication? applyCode({
    required String rawCode,
    required double subtotal,
    required double deliveryFee,
  }) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return null;
    }

    if (code == 'BIENVENUE10') {
      return PromoApplication(
        code: code,
        description: '10% de réduction de bienvenue',
        discountAmount: subtotal * 0.10,
      );
    }

    if (code == 'DELICES15') {
      return PromoApplication(
        code: code,
        description: '15% de réduction sur le panier',
        discountAmount: subtotal * 0.15,
      );
    }

    if (code == 'LIVRAISONOFFERTE') {
      return PromoApplication(
        code: code,
        description: 'Livraison offerte',
        discountAmount: deliveryFee,
      );
    }

    return null;
  }
}
