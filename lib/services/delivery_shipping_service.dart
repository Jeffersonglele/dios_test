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
      // Route obsolète : désactivée pour éviter les requêtes 404 superflues
      return null;
    } catch (e) {
      debugPrint('🚚 Shipping service exception: $e');
      return null;
    }
  }
}
