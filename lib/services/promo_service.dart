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
        'deliveryFee': deliveryFee,
      });

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == true) {
          return PromoApplication(
            code: result['code'] as String,
            description: result['description'] as String,
            discountAmount: (result['discountAmount'] as num).toDouble(),
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
    required double discountAmount,
    required String description,
    int? usageLimit,
    DateTime? expiresAt,
  }) async {
    try {
      final cloudFunction = ParseCloudFunction('createPromoCode');
      final params = <String, dynamic>{
        'code': code,
        'discountAmount': discountAmount,
        'description': description,
        if (usageLimit != null) 'usageLimit': usageLimit,
        if (expiresAt != null)
          'expiresAt': {
            '__type': 'Date',
            'iso': expiresAt.toIso8601String(),
          },
      };
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
