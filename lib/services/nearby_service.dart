import 'dart:math';

import '../core/app_role.dart';
import '../models/address.dart';
import '../models/dish.dart';
import '../models/restaurant.dart';
import '../models/users.dart';
import 'session_service.dart';

class NearbyRestaurantResult {
  const NearbyRestaurantResult({
    required this.restaurant,
    required this.distanceKm,
  });

  final Restaurant restaurant;
  final double distanceKm;
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
    final users = await Users.fetchUsersFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final addresses = await Address.fetchAddressesFromDB();

    final userAddress =
        Address.getAddressByObject(addresses, "User", session.userId);
    final userLat = double.tryParse(userAddress?.lat ?? '');
    final userLon = double.tryParse(userAddress?.long ?? '');

    final results = <NearbyRestaurantResult>[];

    for (final restaurant in restaurants) {
      final associatedUser = Users.getUsersByUserId(users, restaurant.userID);
      final associatedRole = AppRole.fromId(associatedUser?.roleID);
      final restaurantAddress =
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
        }

        if (distanceKm > maxDistanceKm) {
          continue;
        }
      }

      results.add(
        NearbyRestaurantResult(
          restaurant: restaurant,
          distanceKm: distanceKm,
        ),
      );
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }

  static Future<List<NearbyDishResult>> getNearbyDishes({
    double maxDistanceKm = 10,
    bool openRestaurantsOnly = false,
  }) async {
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
