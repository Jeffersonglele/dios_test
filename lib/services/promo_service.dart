import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

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
      final cloudFunction = ParseCloudFunction('validatePromoCode');
      final response = await cloudFunction.execute(parameters: {
        'code': code,
        'subtotal': subtotal,
        'orderAmount': subtotal,
        'deliveryFee': deliveryFee,
      });

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == true) {
          final serverDiscount =
              (result['discountAmount'] ?? result['discount']) as num?;
          final percent =
              (result['discountPercent'] as num?)?.toDouble() ?? 0.0;
          final fixed =
              (result['discountFixed'] as num?)?.toDouble() ?? 0.0;
          final discountAmount = (serverDiscount?.toDouble() ??
                  (percent > 0 ? subtotal * percent / 100 : fixed)
                      .clamp(0.0, subtotal))
              .toDouble();
          if (discountAmount <= 0) return null;
          return PromoApplication(
            code: result['code']?.toString() ?? code,
            description: result['description']?.toString() ?? 'Promotion',
            discountAmount: discountAmount,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllPromoCodes() async {
    try {
      final cloudFunction = ParseCloudFunction('getAllPromoCodes');
      final response = await cloudFunction.execute();

      if (response.success && response.result != null) {
        final result = response.result as List<dynamic>;
        return result.cast<Map<String, dynamic>>();
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
      final cloudFunction = ParseCloudFunction('createPromoCode');
      final params = <String, dynamic>{
        'code': code.toUpperCase(),
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'description': description,
        'minOrder': minOrder,
        'maxUses': maxUses,
      };

      if (validFrom != null) {
        params['validFrom'] = {
          '__type': 'Date',
          'iso': validFrom.toIso8601String(),
        };
      }

      if (validUntil != null) {
        params['validUntil'] = {
          '__type': 'Date',
          'iso': validUntil.toIso8601String(),
        };
      }

      final response = await cloudFunction.execute(parameters: params);

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == false) {
          return "Erreur : ${result['error']}";
        }
        notifyDataChanged();
        return "success";
      }
      return "Erreur lors de l'appel de la fonction cloud";
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> togglePromoActive(String code) async {
    try {
      final cloudFunction = ParseCloudFunction('togglePromoCode');
      final response = await cloudFunction.execute(parameters: {'code': code});
      if (response.success && response.result != null) {
        final result = response.result as Map<dynamic, dynamic>;
        if (result['success'] == true) {
          notifyDataChanged();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePromoCode(String code) async {
    try {
      final cloudFunction = ParseCloudFunction('deletePromoCode');
      final response = await cloudFunction.execute(parameters: {'code': code});
      if (response.success && response.result != null) {
        notifyDataChanged();
        return true;
      }
      return false;
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
      final cloudFunction = ParseCloudFunction('updatePromoCode');
      final params = <String, dynamic>{
        'code': code.toUpperCase(),
        'discountPercent': discountPercent,
        'discountFixed': discountFixed,
        'description': description,
        'minOrder': minOrder,
        'maxUses': maxUses,
      };

      if (validFrom != null) {
        params['validFrom'] = {
          '__type': 'Date',
          'iso': validFrom.toIso8601String(),
        };
      }

      if (validUntil != null) {
        params['validUntil'] = {
          '__type': 'Date',
          'iso': validUntil.toIso8601String(),
        };
      }

      final response = await cloudFunction.execute(parameters: params);

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == false) {
          return "Erreur : ${result['error']}";
        }
        notifyDataChanged();
        return "success";
      }
      return "Erreur lors de l'appel de la fonction cloud";
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<dynamic> createReferralCode(int userID) async {
    try {
      final cloudFunction = ParseCloudFunction('createReferralCode');
      final response = await cloudFunction.execute(parameters: {
        'userID': userID,
      });

      if (response.success && response.result != null) {
        return response.result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<dynamic> applyReferralCode(String code, int newUserID) async {
    try {
      final cloudFunction = ParseCloudFunction('applyReferralCode');
      final response = await cloudFunction.execute(parameters: {
        'code': code,
        'newUserID': newUserID,
      });

      if (response.success && response.result != null) {
        return response.result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
