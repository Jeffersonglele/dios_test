import 'dart:math';

import '../core/app_role.dart';
import '../models/address.dart';
import '../models/dish.dart';
import '../models/restaurant.dart';
import '../models/users.dart';
import 'session_service.dart';
import 'node_catalog_service.dart';
import 'node_home_service.dart';

class NearbyRestaurantResult {
  const NearbyRestaurantResult({
    required this.restaurant,
    required this.distanceKm,
    this.isOutOfRange = false,
  });

  final Restaurant restaurant;
  final double distanceKm;
  final bool isOutOfRange;
}

class NearbyDishResult {
  const NearbyDishResult({
    required this.dish,
    required this.restaurant,
    required this.distanceKm,
  });

  final Dish dish;
  final Restaurant restaurant;
  final double distanceKm;
}

class NearbyService {
  static Future<List<NearbyRestaurantResult>> getNearbyRestaurants({
    double maxDistanceKm = 10,
    bool openOnly = false,
    bool ignoreDistance = false,
  }) async {
    final session = await SessionService.readSession();
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      try {
        final snapshot = await NodeHomeService.load(token: nodeToken);
        return _getNodeNearbyRestaurants(
          snapshot: snapshot,
          session: session,
          maxDistanceKm: maxDistanceKm,
          openOnly: openOnly,
          ignoreDistance: ignoreDistance,
        );
      } catch (_) {
        // Repli vers Hive/Parse pendant la migration ou en cas d'indisponibilité.
      }
    }

    final users = await Users.fetchUsersFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final addresses = await Address.fetchAddressesFromDB();

    final userAddress =
        Address.getAddressByObject(addresses, "User", session.userId) ??
            Address.getAddressByObject(addresses, "Livraison", session.userId);
    final userLat = double.tryParse(userAddress?.lat ?? '');
    final userLon = double.tryParse(userAddress?.long ?? '');

    final inRange = <NearbyRestaurantResult>[];
    final outOfRange = <NearbyRestaurantResult>[];

    for (final restaurant in restaurants) {
      final associatedUser = Users.getUsersByUserId(users, restaurant.userID);
      final associatedRole = AppRole.fromId(associatedUser?.roleID);
      final restaurantAddress =
          Address.getAddressByObject(addresses, "Restaurant", restaurant.userID) ??
              Address.getAddressByObject(addresses, "User", restaurant.userID);

      if (restaurant.valid != 1 ||
          associatedUser == null ||
          associatedRole.isIndividual ||
          restaurant.userID == session.userId) {
        continue;
      }

      if (openOnly && !restaurant.isCurrentlyOpen) {
        continue;
      }

      double distanceKm = 0;
      bool isOutOfRange = false;

      if (!ignoreDistance &&
          userAddress != null &&
          userLat != null &&
          userLon != null &&
          restaurantAddress != null) {
        final restaurantLat = double.tryParse(restaurantAddress.lat ?? '');
        final restaurantLon = double.tryParse(restaurantAddress.long ?? '');

        if (restaurantLat != null && restaurantLon != null) {
          distanceKm = _calculateDistanceKm(
            userLat,
            userLon,
            restaurantLat,
            restaurantLon,
          );
          final restaurantRadius = restaurant.deliveryRadius > 0
              ? restaurant.deliveryRadius
              : maxDistanceKm;
          isOutOfRange = distanceKm > maxDistanceKm ||
              distanceKm > restaurantRadius;
        }
      }

      final result = NearbyRestaurantResult(
        restaurant: restaurant,
        distanceKm: distanceKm,
        isOutOfRange: isOutOfRange,
      );
      if (isOutOfRange) {
        outOfRange.add(result);
      } else {
        inRange.add(result);
      }
    }

    inRange.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    outOfRange.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return [...inRange, ...outOfRange];
  }

  static Future<List<NearbyDishResult>> getNearbyDishes({
    double maxDistanceKm = 10,
    bool openRestaurantsOnly = false,
  }) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      try {
        final nearbyRestaurants = await getNearbyRestaurants(
          maxDistanceKm: maxDistanceKm,
          openOnly: openRestaurantsOnly,
        );
        final dishes = await NodeCatalogService.loadDishes(
          token: nodeToken,
          status: 1,
        );
        final restaurantById = {
          for (final result in nearbyRestaurants)
            result.restaurant.restaurantID: result,
        };
        final results = dishes
            .where((dish) => restaurantById.containsKey(dish.restauID))
            .map((dish) => NearbyDishResult(
                  dish: dish,
                  restaurant: restaurantById[dish.restauID]!.restaurant,
                  distanceKm: restaurantById[dish.restauID]!.distanceKm,
                ))
            .toList();
        results.sort((a, b) => b.dish.nb_orders.compareTo(a.dish.nb_orders));
        return results;
      } catch (_) {
        // Repli vers Hive/Parse pendant la migration ou en cas d'indisponibilité.
      }
    }

    final nearbyRestaurants = await getNearbyRestaurants(
      maxDistanceKm: maxDistanceKm,
      openOnly: openRestaurantsOnly,
    );
    final dishes = await Dish.fetchDishesFromDB();

    final restaurantById = {
      for (final result in nearbyRestaurants)
        result.restaurant.restaurantID: result,
    };

    final results = <NearbyDishResult>[];

    for (final dish in dishes) {
      final restaurantResult = restaurantById[dish.restauID];
      if (restaurantResult == null) {
        continue;
      }

      if ((dish.status ?? 0) != 1) {
        continue;
      }

      results.add(
        NearbyDishResult(
          dish: dish,
          restaurant: restaurantResult.restaurant,
          distanceKm: restaurantResult.distanceKm,
        ),
      );
    }

    results.sort((a, b) {
      final distanceComparison = a.distanceKm.compareTo(b.distanceKm);
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      return b.dish.nb_orders.compareTo(a.dish.nb_orders);
    });

    return results;
  }

  static List<NearbyRestaurantResult> _getNodeNearbyRestaurants({
    required NodeHomeSnapshot snapshot,
    required UserSession session,
    required double maxDistanceKm,
    required bool openOnly,
    required bool ignoreDistance,
  }) {
    final userAddress =
        Address.getAddressByObject(snapshot.addresses, 'User', session.userId);
    final userLat = double.tryParse(userAddress?.lat ?? '');
    final userLon = double.tryParse(userAddress?.long ?? '');
    final userCityID = userAddress?.cityID ?? 0;
    final userCity = _normalize(_firstNonEmpty([userAddress?.city]));
    final userCountry =
        _normalize(_firstNonEmpty([userAddress?.state, session.country]));
    final inRange = <NearbyRestaurantResult>[];
    final outOfRange = <NearbyRestaurantResult>[];

    for (final restaurant in snapshot.restaurants) {
      if (restaurant.valid != 1 || restaurant.userID == session.userId) {
        continue;
      }
      if (openOnly && !restaurant.isCurrentlyOpen) continue;

      var distanceKm = 0.0;
      var isOutOfRange = false;
      final restaurantAddress =
          Address.getAddressByObject(snapshot.addresses, 'Restaurant', restaurant.userID) ??
              Address.getAddressByObject(snapshot.addresses, 'User', restaurant.userID);
      final restaurantLat = restaurant.latitude ??
          (restaurantAddress != null
              ? double.tryParse(restaurantAddress.lat ?? '')
              : null);
      final restaurantLon = restaurant.longitude ??
          (restaurantAddress != null
              ? double.tryParse(restaurantAddress.long ?? '')
              : null);
      final restaurantCityID = restaurant.cityID > 0
          ? restaurant.cityID
          : (restaurantAddress?.cityID ?? 0);
      final restaurantCity = _normalize(
          _firstNonEmpty([restaurantAddress?.city, restaurant.location]));
      final restaurantCountry = _normalize(
          _firstNonEmpty([restaurantAddress?.state, restaurant.country]));

      // 1) cityID fiable des deux côtés
      if (!ignoreDistance && userCityID > 0 && restaurantCityID > 0) {
        if (userCityID != restaurantCityID) isOutOfRange = true;
      }
      // 2) Comparaison ville + pays (texte normalisé)
      if (!isOutOfRange &&
          !ignoreDistance &&
          ((userCity != null && userCountry != null) ||
           (restaurantCity != null && restaurantCountry != null))) {
        final sameCountry = userCountry != null &&
            restaurantCountry != null &&
            userCountry == restaurantCountry;
        final sameCity = sameCountry &&
            userCity != null &&
            restaurantCity != null &&
            userCity == restaurantCity;
        final differentCountry =
            userCountry != null && restaurantCountry != null && !sameCountry;
        if ((!sameCity && sameCountry) || differentCountry) {
          isOutOfRange = true;
        }
      }
      // 3) Distance à vol d'oiseau (si pas déjà hors zone)
      if (!isOutOfRange &&
          !ignoreDistance &&
          userLat != null &&
          userLon != null &&
          restaurantLat != null &&
          restaurantLon != null) {
        distanceKm = _calculateDistanceKm(
          userLat,
          userLon,
          restaurantLat,
          restaurantLon,
        );
        final restaurantRadius = restaurant.deliveryRadius > 0
            ? restaurant.deliveryRadius
            : maxDistanceKm;
        isOutOfRange = distanceKm > maxDistanceKm ||
            distanceKm > restaurantRadius;
      }

      final result = NearbyRestaurantResult(
        restaurant: restaurant,
        distanceKm: distanceKm,
        isOutOfRange: isOutOfRange,
      );
      (isOutOfRange ? outOfRange : inRange).add(result);
    }

    inRange.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    outOfRange.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return [...inRange, ...outOfRange];
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

  static double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);
}
