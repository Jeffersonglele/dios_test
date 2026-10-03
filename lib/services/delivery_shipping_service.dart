import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ShippingQuote {
  const ShippingQuote({
    required this.distanceKm,
    required this.shippingFee,
    required this.currency,
    this.pricingSource,
  });

  final double distanceKm;
  final double shippingFee;
  final String currency;
  final String? pricingSource;

  factory ShippingQuote.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return ShippingQuote(
      distanceKm: (data?['distanceKm'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (data?['shippingFee'] as num?)?.toDouble() ?? 0.0,
      currency: data?['currency'] as String? ?? 'XOF',
      pricingSource: data?['pricing']?['source'] as String?,
    );
  }
}

class DeliveryShippingService {
  DeliveryShippingService._();

  static Future<ShippingQuote?> calculateShipping({
    required int restaurantId,
    required double deliveryLat,
    required double deliveryLng,
  }) async {
    try {
      final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/catalog/cart/calculate-shipping');
      
      debugPrint('🚚 Shipping service URL: $uri');
      debugPrint('🚚 Request body: ${jsonEncode({
        'restaurantId': restaurantId,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
      })}');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'restaurantId': restaurantId,
          'deliveryLat': deliveryLat,
          'deliveryLng': deliveryLng,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('🚚 Response status: ${response.statusCode}');
      debugPrint('🚚 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ShippingQuote.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('🚚 Shipping service exception: $e');
      return null;
    }
  }
}
