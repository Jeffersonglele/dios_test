import 'dart:math';

import '../models/address.dart';
import '../models/restaurant.dart';
import '../services/session_service.dart';

/// Résultat du contrôle de livraison d'un restaurant pour le client connecté.
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

  /// Données insuffisantes pour afficher un vendeur comme hors zone.
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

    // Les adresses des restaurants sont créées avec object = Restaurant.
    // Le fallback User conserve la compatibilité avec les anciennes données.
    final restaurantAddress =
        Address.getAddressByObject(addresses, 'Restaurant', restaurant.userID) ??
            Address.getAddressByObject(addresses, 'User', restaurant.userID);
    final restaurantLat = double.tryParse(restaurantAddress?.lat ?? '');
    final restaurantLng = double.tryParse(restaurantAddress?.long ?? '');

    if (customerLat == null ||
        customerLng == null ||
        restaurantLat == null ||
        restaurantLng == null) {
      return DeliveryAvailability(
        // Sans coordonnées, on ne peut pas conclure que le vendeur est hors
        // zone. Le contrôle de l'adresse reste effectué au passage de la
        // commande, comme avant.
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

    // Si les deux côtés portent un cityID fiable, une ville différente est
    // toujours hors zone, même si les coordonnées sont exceptionnellement
    // proches de la frontière.
    final differentCity = resolvedCustomerAddress != null &&
        restaurantAddress != null &&
        resolvedCustomerAddress.cityID > 0 &&
        restaurant.cityID > 0 &&
        resolvedCustomerAddress.cityID != restaurant.cityID;
    final isOutOfRange = differentCity || distanceKm > radiusKm;

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
}
