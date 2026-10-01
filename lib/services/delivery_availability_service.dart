import 'dart:math';

import '../models/address.dart';
import '../models/restaurant.dart';
import '../services/session_service.dart';

class DeliveryAvailability {
  const DeliveryAvailability({
    required this.canOrder,
    this.isOutOfRange = false,
    this.hasCustomerAddress = true,
    this.distanceKm,
    this.deliveryRadiusKm,
  });

  final bool canOrder;
  final bool isOutOfRange;
  final bool hasCustomerAddress;
  final double? distanceKm;
  final double? deliveryRadiusKm;

  bool get isUnknown => !hasCustomerAddress || distanceKm == null;
}

class DeliveryAvailabilityService {
  const DeliveryAvailabilityService._();

  static Future<DeliveryAvailability> forRestaurant(
    Restaurant restaurant, {
    int? userId,
    Address? customerAddress,
  }) async {
    final session = await SessionService.readSession();
    final customerId = userId ?? session.userId;
    final addresses = await Address.fetchAddressesFromDB();

    final resolvedCustomerAddress = customerAddress ??
        Address.getAddressByObject(addresses, 'User', customerId) ??
        Address.getAddressByObject(addresses, 'Livraison', customerId);
    final customerLat = double.tryParse(resolvedCustomerAddress?.lat ?? '');
    final customerLng = double.tryParse(resolvedCustomerAddress?.long ?? '');

    final restaurantAddress =
        Address.getAddressByObject(addresses, 'Restaurant', restaurant.userID) ??
            Address.getAddressByObject(addresses, 'User', restaurant.userID);
    final restaurantLat = restaurant.latitude ??
        double.tryParse(restaurantAddress?.lat ?? '');
    final restaurantLng = restaurant.longitude ??
        double.tryParse(restaurantAddress?.long ?? '');

    // ── 1) Comparaison cityID ──────────────────────────────────────────
    final customerCityID = resolvedCustomerAddress?.cityID ?? 0;
    final restaurantCityID =
        restaurant.cityID > 0 ? restaurant.cityID : (restaurantAddress?.cityID ?? 0);
    if (customerCityID > 0 && restaurantCityID > 0) {
      final differentCity = customerCityID != restaurantCityID;
      return DeliveryAvailability(
        canOrder: !differentCity,
        isOutOfRange: differentCity,
        hasCustomerAddress: true,
        distanceKm: customerLat != null &&
                    customerLng != null &&
                    restaurantLat != null &&
                    restaurantLng != null
            ? _distanceKm(customerLat, customerLng, restaurantLat, restaurantLng)
            : null,
        deliveryRadiusKm:
            restaurant.deliveryRadius > 0 ? restaurant.deliveryRadius : 10.0,
      );
    }

    // ── 2) Comparaison ville + pays (texte normalisé) ──────────────────
    final customerCity =
        _normalize(_firstNonEmpty([resolvedCustomerAddress?.city]));
    final customerCountry =
        _normalize(_firstNonEmpty([resolvedCustomerAddress?.state, session.country]));
    final restaurantCity = _normalize(
        _firstNonEmpty([restaurantAddress?.city, restaurant.location]));
    final restaurantCountry = _normalize(
        _firstNonEmpty([restaurantAddress?.state, restaurant.country]));

    if ((customerCity != null && customerCountry != null) ||
        (restaurantCity != null && restaurantCountry != null)) {
      final sameCountry = customerCountry != null &&
          restaurantCountry != null &&
          customerCountry == restaurantCountry;
      final sameCity = sameCountry &&
          customerCity != null &&
          restaurantCity != null &&
          customerCity == restaurantCity;
      final differentCountry =
          customerCountry != null && restaurantCountry != null && !sameCountry;

      final outByLocation = (!sameCity && sameCountry) || differentCountry;

      final distanceKm = customerLat != null &&
              customerLng != null &&
              restaurantLat != null &&
              restaurantLng != null
          ? _distanceKm(customerLat, customerLng, restaurantLat, restaurantLng)
          : null;
      final radiusKm =
          restaurant.deliveryRadius > 0 ? restaurant.deliveryRadius : 10.0;
      final outByDistance = distanceKm != null && distanceKm > radiusKm;

      final isOutOfRange = outByLocation || outByDistance;

      return DeliveryAvailability(
        canOrder: !isOutOfRange,
        isOutOfRange: isOutOfRange,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }

    // ── 3) Fallback : uniquement distance ──────────────────────────────
    if (customerLat == null ||
        customerLng == null ||
        restaurantLat == null ||
        restaurantLng == null) {
      return DeliveryAvailability(
        canOrder: true,
        hasCustomerAddress: customerLat != null && customerLng != null,
      );
    }

    final distanceKm = _distanceKm(
      customerLat,
      customerLng,
      restaurantLat,
      restaurantLng,
    );
    final radiusKm = restaurant.deliveryRadius > 0
        ? restaurant.deliveryRadius
        : 10.0;
    final isOutOfRange = distanceKm > radiusKm;

    return DeliveryAvailability(
      canOrder: !isOutOfRange,
      isOutOfRange: isOutOfRange,
      hasCustomerAddress: true,
      distanceKm: distanceKm,
      deliveryRadiusKm: radiusKm,
    );
  }

  static double distanceKmBetween(double lat1, double lng1, double lat2,
      double lng2) {
    return _distanceKm(lat1, lng1, lat2, lng2);
  }

  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    const accents = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ý': 'y', 'ÿ': 'y',
      'ç': 'c', 'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in v.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
