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
}
