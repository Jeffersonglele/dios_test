import 'package:flutter/foundation.dart' hide Category;
import '../db/database_helper.dart';
import '../models/address.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../models/users.dart';
import 'node_auth_service.dart';

/// Données nécessaires au rendu de l'accueil client.
class NodeHomeSnapshot {
  const NodeHomeSnapshot({
    this.user,
    required this.restaurants,
    required this.addresses,
    required this.categories,
  });

  final Users? user;
  final List<Restaurant> restaurants;
  final List<Address> addresses;
  final List<Category> categories;
}

class NodeHomeService {
  const NodeHomeService._();

  /// Charge les restaurants et catégories depuis Node.js même sans JWT.
  /// Si un [token] est fourni, le profil utilisateur et ses adresses sont
  /// également récupérés. La session JWT n'est donc plus un prérequis pour
  /// afficher le catalogue ; elle ne sert qu'aux données privées.
  static Future<NodeHomeSnapshot> load({String? token}) async {
    // 1. Appels publics (pas d'authentification requise)
    final restaurantResponse = await NodeAuthService.getJson(
      '/restaurants',
      queryParameters: const {'pageSize': '100'},
    );
    final optionalResponses = await Future.wait<Map<String, dynamic>>([
      _optionalGet(
        '/categories',
        queryParameters: const {'pageSize': '100'},
      ),
      _optionalGet(
        '/addresses',
        token: token,
        queryParameters: const {'pageSize': '100'},
      ),
    ]);

    // 2. Profil privé (seulement si token)
    Users? user;
    if (token?.trim().isNotEmpty == true) {
      try {
        final userResponse = await NodeAuthService.me(token!);
        user = Users.fromNodeAuth(userResponse['data'] as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }

    final restaurantRows = _pageRows(restaurantResponse);
    final categoryRows = _pageRows(optionalResponses[0]);
    final addressRows = _pageRows(optionalResponses[1]);

    if (kDebugMode) {
      final countByObject = <String, int>{};
      for (final r in addressRows) {
        final key =
            (r['objectType'] ?? r['object'] ?? '?').toString().toLowerCase();
        countByObject[key] = (countByObject[key] ?? 0) + 1;
      }
      debugPrint('[NodeHomeService] ${restaurantRows.length} restaurants, '
          '${addressRows.length} addresses (${countByObject.entries.map((e) => '${e.key}=${e.value}').join(', ')})');
    }

    final restaurants = restaurantRows
        .map((row) => Restaurant.fromMap(_restaurantMap(row)))
        .where((r) => r.valid == 1)
        .toList();
    final categories =
        categoryRows.map((row) => Category.fromMap(_categoryMap(row))).toList();
    final addresses = addressRows
        .map((row) => Address.fromMap(_addressMap(row, user?.userID ?? 0)))
        .toList();

    // Persister le catalogue reçu en local pour que le fallback Hive affiche
    // du Node.js même en cas d'indisponibilité serveur (et non du Parse).
    await _persistInHive(restaurants: restaurants, categories: categories);

    return NodeHomeSnapshot(
      user: user,
      restaurants: restaurants,
      addresses: addresses,
      categories: categories,
    );
  }

  static Future<void> _persistInHive({
    required List<Restaurant> restaurants,
    required List<Category> categories,
  }) async {
    try {
      for (final r in restaurants) {
        try {
          await DatabaseHelper.updateRestaurant(r);
        } catch (_) {
          await DatabaseHelper.createRestaurant(r);
        }
      }
      // Categories n'ont pas de helper dans DatabaseHelper pour l'instant.
      // On s'en tient à Restaurants qui est la source principale.
    } catch (_) {
      // Non bloquant : même en cas d'erreur Hive, on continue.
    }
  }

  static Future<Map<String, dynamic>> _optionalGet(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    try {
      return await NodeAuthService.getJson(
        path,
        token: token,
        queryParameters: queryParameters,
      );
    } catch (_) {
      return const {'data': <dynamic>[]};
    }
  }

  static List<Map<String, dynamic>> _pageRows(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Map<String, dynamic> _restaurantMap(Map<String, dynamic> row) {
    final dateCreation = row['dateCreation'];
    String? cityFromAddress;
    String? countryFromAddress;
    final adr = row['address']?.toString();
    if (adr != null && adr.isNotEmpty) {
      // Exemple : "43 Tombalbaye, Kinshasa" → ville = "Kinshasa"
      final commaIdx = adr.lastIndexOf(',');
      if (commaIdx >= 0 && commaIdx < adr.length - 1) {
        final token = adr.substring(commaIdx + 1).trim();
        if (token.isNotEmpty) cityFromAddress = token;
      } else {
        cityFromAddress = adr;
      }
    }
    return {
      'restaurantID': row['restaurantId'],
      'userID': row['userId'],
      'categories': row['categories'],
      'description': row['description'],
      'adress': row['address'],
      'name': row['name'],
      'note': row['rating'],
      'nb_orders': row['orderCount'],
      'image': row['image'],
      'valid': row['valid'],
      'date_creation': dateCreation == null ? null : {'iso': dateCreation},
      'openingHours': row['openingHours'],
      'deliveryFee': row['deliveryFee'],
      'isOpen': row['isOpen'],
      'professionalType': row['professionalType'],
      'trainingCompleted': row['trainingCompleted'],
      'reviewRemark': row['reviewRemark'],
      'currency': row['currency'],
      'country': (row['country']?.toString()?.trim().isNotEmpty == true)
          ? row['country']?.toString()
          : (countryFromAddress ?? ''),
      'cityText': cityFromAddress ?? '',
      'openingDays': row['openingDays'],
      'minOrderAmount': row['minOrderAmount'],
      'deliveryRadius': row['deliveryRadius'],
      'closedDates': row['closedDates'],
      'recoveryMode': row['recoveryMode'],
      'cityID': row['cityId'],
      'paymentMethod': row['paymentMethod'],
      'mobileMoneyPhone': row['mobileMoneyPhone'],
      'iban': row['iban'],
      'bankName': row['bankName'],
      'accountHolder': row['accountHolder'],
      'rccm': row['rccm'],
      'isPro': row['isPro'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    };
  }

  static Map<String, dynamic> _addressMap(
    Map<String, dynamic> row,
    int userId,
  ) {
    return {
      'addressID': row['addressId'],
      'object': 'User',
      'objectID': row['objectId'] ?? userId,
      'numero': row['streetNumber'],
      'city': row['city'],
      'state': row['state'],
      'fullAddress': row['fullAddress'],
      'lat': row['latitude'],
      'long': row['longitude'],
      'cityID': row['cityId'],
    };
  }

  static Map<String, dynamic> _categoryMap(Map<String, dynamic> row) {
    return {
      'categoryID': row['categoryId'],
      'name': row['name'],
    };
  }
}
