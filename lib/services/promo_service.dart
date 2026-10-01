import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';

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
  static Future<PromoApplication?> applyCode({
    required String rawCode,
    required double subtotal,
    required double deliveryFee,
  }) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return null;

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
      if (data != null && data is Map) {
        final discountAmount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
        if (discountAmount <= 0) return null;

        return PromoApplication(
          code: data['code']?.toString() ?? code,
          description: data['description']?.toString() ?? 'Promotion',
          discountAmount: discountAmount,
        );
      }
      return null;
    } catch (e) {
      return null;
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
