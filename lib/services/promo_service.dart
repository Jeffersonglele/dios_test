import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';

class PromoApplication {
  const PromoApplication({
    required this.code,
    required this.description,
    required this.discountAmount,
    this.discountPercent,
    this.discountFixed,
    this.minOrder,
  });

  final String code;
  final String description;

  /// Réduction calculée par le serveur pour le panier vérifié.
  final double discountAmount;
  final double? discountPercent;
  final double? discountFixed;
  final double? minOrder;

  /// Réduction pour un autre sous-total (le panier a changé). Même règle que
  /// le serveur, qui recalcule de toute façon à la commande.
  double discountFor(double subtotal) {
    if (subtotal <= 0) return 0;
    if (minOrder != null && subtotal < minOrder!) return 0;
    double discount;
    if ((discountPercent ?? 0) > 0) {
      discount = subtotal * discountPercent! / 100;
    } else if ((discountFixed ?? 0) > 0) {
      discount = discountFixed!;
    } else {
      return discountAmount;
    }
    final rounded = discount.roundToDouble();
    final cap = subtotal.floorToDouble();
    return rounded > cap ? cap : rounded;
  }
}

/// Résultat de la vérification : le code appliqué, ou le message du serveur
/// (expiré, minimum non atteint, déjà utilisé…).
class PromoCheck {
  const PromoCheck({this.promo, this.error});
  final PromoApplication? promo;
  final String? error;
}

class PromoService {
  /// Vérifie un code pour le panier. [subtotal] = plats, hors livraison.
  static Future<PromoCheck> applyCode({
    required String rawCode,
    required double subtotal,
    required double deliveryFee,
  }) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return const PromoCheck();

    try {
      final token = await SessionService.readNodeToken();
      if (token == null) {
        return const PromoCheck(
            error: 'Connectez-vous pour utiliser un code promo.');
      }

      final response = await NodeAuthService.postJson(
        '/promo-codes/validate',
        token: token,
        body: {
          'code': code,
          'subtotal': subtotal,
          'deliveryFee': deliveryFee,
        },
      );

      final data = response['data'];
      if (data is Map) {
        double? num0(Object? v) => double.tryParse('${v ?? ''}');
        final discountAmount = num0(data['discountAmount']) ?? 0.0;
        if (discountAmount <= 0) return const PromoCheck();
        final description = data['description']?.toString().trim() ?? '';
        return PromoCheck(
          promo: PromoApplication(
            code: data['code']?.toString() ?? code,
            description: description.isEmpty ? 'Promotion' : description,
            discountAmount: discountAmount,
            discountPercent: num0(data['discountPercent']),
            discountFixed: num0(data['discountFixed']),
            minOrder: num0(data['minOrder']),
          ),
        );
      }
      return const PromoCheck();
    } on NodeAuthException catch (e) {
      return PromoCheck(error: e.message);
    } catch (_) {
      return const PromoCheck();
    }
  }

  static Future<List<Map<String, dynamic>>> getAllPromoCodes() async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return [];

      final response = await NodeAuthService.getJson(
        '/promo-codes',
        token: token,
      );

      final data = response['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<String> createPromoCode({
    required String code,
    required double discountPercent,
    required double discountFixed,
    required String description,
    required int minOrder,
    required int maxUses,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return "Erreur : Non authentifié";

      final body = <String, dynamic>{
        'code': code.toUpperCase(),
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'description': description,
        'minOrder': minOrder,
        'maxUses': maxUses,
        if (validFrom != null) 'validFrom': validFrom.toIso8601String(),
        if (validUntil != null) 'validUntil': validUntil.toIso8601String(),
      };

      await NodeAuthService.postJson(
        '/promo-codes',
        token: token,
        body: body,
      );

      notifyDataChanged();
      return "success";
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> togglePromoActive(String code) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return false;

      // Chercher d'abord le promo-code pour l'ID (CRUD REST)
      final all = await getAllPromoCodes();
      final promo = all.firstWhere((p) => p['code'] == code, orElse: () => {});
      if (promo.isEmpty || promo['id'] == null) return false;

      final currentActive = promo['active'] == true;

      await NodeAuthService.patchJson(
        '/promo-codes/${promo['id']}',
        token: token,
        body: {'active': !currentActive},
      );

      notifyDataChanged();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePromoCode(String code) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return false;

      final all = await getAllPromoCodes();
      final promo = all.firstWhere((p) => p['code'] == code, orElse: () => {});
      if (promo.isEmpty || promo['id'] == null) return false;

      await NodeAuthService.deleteJson(
        '/promo-codes/${promo['id']}',
        token: token,
      );

      notifyDataChanged();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String> updatePromoCode({
    required String code,
    required double discountPercent,
    required double discountFixed,
    required String description,
    required int minOrder,
    required int maxUses,
    DateTime? validFrom,
    DateTime? validUntil,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return "Erreur : Non authentifié";

      final all = await getAllPromoCodes();
      final promo = all.firstWhere((p) => p['code'] == code, orElse: () => {});
      if (promo.isEmpty || promo['id'] == null) return "Code promo introuvable";

      final body = <String, dynamic>{
        'code': code.toUpperCase(),
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'description': description,
        'minOrder': minOrder,
        'maxUses': maxUses,
        if (validFrom != null) 'validFrom': validFrom.toIso8601String(),
        if (validUntil != null) 'validUntil': validUntil.toIso8601String(),
      };

      await NodeAuthService.patchJson(
        '/promo-codes/${promo['id']}',
        token: token,
        body: body,
      );

      notifyDataChanged();
      return "success";
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<dynamic> createReferralCode(int userID) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return null;

      final response = await NodeAuthService.postJson(
        '/promo-codes/referral/create',
        token: token,
        body: {'userID': userID},
      );
      
      return response['data'];
    } catch (e) {
      return null;
    }
  }

  static Future<dynamic> applyReferralCode(String code, int newUserID) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return null;

      final response = await NodeAuthService.postJson(
        '/promo-codes/referral/apply',
        token: token,
        body: {
          'code': code,
          'newUserID': newUserID,
        },
      );

      return response['data'];
    } catch (e) {
      return null;
    }
  }
}
