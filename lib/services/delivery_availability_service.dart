import 'dart:math';

import '../models/address.dart';
import '../models/restaurant.dart';
import '../services/session_service.dart';
import '../utils/country_util.dart';

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

  static double? parseDouble(dynamic value) => _parseDouble(value);

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.replaceAll(',', '.').replaceAll(' ', '');
    return double.tryParse(normalized);
  }

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
    final customerLat = _parseDouble(resolvedCustomerAddress?.lat);
    final customerLng = _parseDouble(resolvedCustomerAddress?.long);

    final restaurantAddress = Address.getAddressByObject(
            addresses, 'Restaurant', restaurant.userID) ??
        Address.getAddressByObject(addresses, 'User', restaurant.userID);
    final restaurantLat =
        _parseDouble(restaurant.latitude) ??
        _parseDouble(restaurantAddress?.lat);
    final restaurantLng =
        _parseDouble(restaurant.longitude) ??
        _parseDouble(restaurantAddress?.long);
    final radiusKm =
        restaurant.deliveryRadius > 0 ? restaurant.deliveryRadius : 10.0;

    final hasCoords = customerLat != null &&
        customerLng != null &&
        restaurantLat != null &&
        restaurantLng != null;

    final distanceKm = hasCoords
        ? _distanceKm(
            customerLat, customerLng, restaurantLat, restaurantLng)
        : null;

    if (hasCoords) {
      final withinRadius = distanceKm! <= radiusKm;
      return DeliveryAvailability(
        canOrder: withinRadius,
        isOutOfRange: !withinRadius,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }

    final customerCityID = resolvedCustomerAddress?.cityID ?? 0;
    final restaurantCityID = restaurant.cityID > 0
        ? restaurant.cityID
        : (restaurantAddress?.cityID ?? 0);
    if (customerCityID > 0 && restaurantCityID > 0) {
      final differentCity = customerCityID != restaurantCityID;
      return DeliveryAvailability(
        canOrder: !differentCity,
        isOutOfRange: differentCity,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }

    final customerCity =
        _normalize(_firstNonEmpty([resolvedCustomerAddress?.city]));
    final customerCountryRaw = _firstNonEmpty([
      resolvedCustomerAddress?.state,
      session.country,
    ]);
    final customerCountry = CountryUtil.canonical(customerCountryRaw).isNotEmpty
        ? CountryUtil.canonical(customerCountryRaw)
        : _normalize(customerCountryRaw);
    final restaurantCity = _normalize(
        _firstNonEmpty([restaurantAddress?.city, restaurant.location]));
    final restaurantCountryRaw = _firstNonEmpty([
      restaurant.country,
      restaurantAddress?.state,
    ]);
    final restaurantCountry =
        CountryUtil.canonical(restaurantCountryRaw).isNotEmpty
            ? CountryUtil.canonical(restaurantCountryRaw)
            : _normalize(restaurantCountryRaw);

    final countriesKnown = customerCountry != null && restaurantCountry != null;
    final sameCountry = countriesKnown && customerCountry == restaurantCountry;
    final differentCountry = countriesKnown && !sameCountry;

    final citiesKnown = customerCity != null && restaurantCity != null;
    final citiesMatch = citiesKnown && _citiesOverlap(customerCity, restaurantCity);
    final differentCity = citiesKnown && !citiesMatch;

    if (differentCountry) {
      return DeliveryAvailability(
        canOrder: false,
        isOutOfRange: true,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }
    if (differentCity && sameCountry) {
      return DeliveryAvailability(
        canOrder: false,
        isOutOfRange: true,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }
    if (sameCountry && (citiesMatch || !citiesKnown)) {
      return DeliveryAvailability(
        canOrder: true,
        isOutOfRange: false,
        hasCustomerAddress: true,
        distanceKm: distanceKm,
        deliveryRadiusKm: radiusKm,
      );
    }

    if (customerLat == null ||
        customerLng == null ||
        restaurantLat == null ||
        restaurantLng == null) {
      return DeliveryAvailability(
        canOrder: true,
        hasCustomerAddress: customerLat != null && customerLng != null,
      );
    }

    final isOutOfRangeFallback = distanceKm! > radiusKm;
    return DeliveryAvailability(
      canOrder: !isOutOfRangeFallback,
      isOutOfRange: isOutOfRangeFallback,
      hasCustomerAddress: true,
      distanceKm: distanceKm,
      deliveryRadiusKm: radiusKm,
    );
  }

  static double distanceKmBetween(
      double lat1, double lng1, double lat2, double lng2) {
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

  static bool _citiesOverlap(String a, String b) {
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;
    if (a.contains(b) || b.contains(a)) return true;
    final tokensA = a.split(RegExp(r'[,\s]+')).where((t) => t.length >= 3).toSet();
    final tokensB = b.split(RegExp(r'[,\s]+')).where((t) => t.length >= 3).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return false;
    return tokensA.intersection(tokensB).isNotEmpty;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    const accents = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ç': 'c',
      'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in v.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
