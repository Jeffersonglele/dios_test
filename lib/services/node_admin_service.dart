import 'node_auth_service.dart';
import '../models/restaurant.dart';
import '../models/users.dart';

class NodeAdminService {
  const NodeAdminService._();

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Liste administrative provenant exclusivement de l'API Node.js.
  static Future<List<Users>> getUsers({
    required String token,
    String? country,
  }) async {
    final query = <String, String>{'pageSize': '100'};
    if (country?.trim().isNotEmpty == true) {
      query['country'] = country!.trim();
    }
    final response = await NodeAuthService.getJson(
      '/users',
      token: token,
      queryParameters: query,
    );
    return _rows(response)
        .map(Users.fromNodeAuth)
        .where((user) => user.userID > 0)
        .toList();
  }

  /// Liste administrative des restaurants, y compris les demandes en attente.
  /// Le filtre par pays est appliqué LOCALEMENT (restaurant.country + user.country)
  /// dans la page admin, car certains restaurants n'ont pas country renseigné
  /// (en base) contrairement à leur propriétaire User.
  static Future<List<Restaurant>> getRestaurants({
    required String token,
    String? country,
  }) async {
    final query = <String, String>{'pageSize': '100', 'showAll': 'true'};
    final response = await NodeAuthService.getJson(
      '/restaurants',
      token: token,
      queryParameters: query,
    );
    return _rows(response)
        .map((row) => Restaurant.fromMap(_restaurantMap(row)))
        .where((restaurant) => restaurant.restaurantID > 0)
        .toList();
  }

  static Map<String, dynamic> _restaurantMap(Map<String, dynamic> row) {
    final dateCreation = row['dateCreation'];
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
      'country': row['country'],
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

  static Future<Map<String, dynamic>> getDashboardStats({
    required String token,
    String? country,
  }) async {
    final query = <String, String>{};
    if (country != null && country.isNotEmpty) {
      query['country'] = country;
    }

    try {
      final response = await NodeAuthService.getJson(
        '/admin/dashboard-stats',
        token: token,
        queryParameters: query,
      );
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      throw NodeAuthException('Erreur lors du chargement des statistiques: $e');
    }
  }

  static Future<List<dynamic>> getProDocuments(String token,
      {String? country}) async {
    final query = <String, String>{};
    if (country?.trim().isNotEmpty == true) {
      query['country'] = country!.trim();
    }
    final response = await NodeAuthService.getJson(
      '/admin/pro-documents',
      token: token,
      queryParameters: query.isNotEmpty ? query : null,
    );
    return response['data'] as List<dynamic>;
  }

  static Future<void> validateProDocuments(
      String documentId, String status, String token) async {
    await NodeAuthService.patchJson(
      '/admin/pro-documents/validate',
      token: token,
      body: {'documentId': documentId, 'status': status},
    );
  }

  /// Livreurs avec l'état de leur dossier (photo, pièce, permis, plaque).
  static Future<List<Map<String, dynamic>>> getCouriers(String token,
      {String? country}) async {
    final response = await NodeAuthService.getJson(
      '/admin/couriers',
      token: token,
      queryParameters: country?.trim().isNotEmpty == true
          ? {'country': country!.trim()}
          : null,
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Fiche d'un livreur : profil, dernier dossier et activité.
  static Future<Map<String, dynamic>?> getCourier(
      String token, int userId) async {
    final response =
        await NodeAuthService.getJson('/admin/couriers/$userId', token: token);
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// Création d'un administrateur (super admin) : mot de passe temporaire
  /// envoyé par email, à changer à la première connexion.
  static Future<Map<String, dynamic>> createAdmin({
    required String token,
    required String email,
    required String username,
    String? firstname,
    String? lastname,
    required int roleId,
    String? country,
  }) async {
    final response = await NodeAuthService.postJson(
      '/admin/users',
      token: token,
      body: {
        'email': email.trim(),
        'username': username.trim(),
        if (firstname?.trim().isNotEmpty == true) 'firstname': firstname!.trim(),
        if (lastname?.trim().isNotEmpty == true) 'lastname': lastname!.trim(),
        'roleId': roleId,
        if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      },
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Indicateurs du super admin (paiements, commissions, litiges).
  static Future<Map<String, dynamic>> getSuperAdminStats(String token,
      {String? country}) async {
    final response = await NodeAuthService.getJson(
      '/admin/super-stats',
      token: token,
      queryParameters: country?.trim().isNotEmpty == true
          ? {'country': country!.trim()}
          : null,
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Journal d'audit (limité au pays de l'admin par le serveur).
  static Future<List<Map<String, dynamic>>> getAuditLogs(String token) async {
    final response = await NodeAuthService.getJson(
      '/audit-logs',
      token: token,
      queryParameters: const {'pageSize': '100'},
    );
    return _rows(response);
  }

  /// Villes ouvertes à la livraison.
  static Future<List<Map<String, dynamic>>> getCities(String token) async {
    final response = await NodeAuthService.getJson(
      '/cities',
      token: token,
      queryParameters: const {'pageSize': '100'},
    );
    return _rows(response);
  }

  /// Tarif réellement appliqué dans une ville (configuration de la ville ou
  /// grille par défaut du pays).
  static Future<Map<String, dynamic>> getCityTariff(
      String token, int cityId) async {
    final response = await NodeAuthService.getJson(
      '/delivery-configs/active',
      token: token,
      queryParameters: {'cityId': '$cityId'},
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Enregistre la grille d'une ville (crée la configuration si besoin).
  static Future<void> saveCityTariff({
    required String token,
    required int cityId,
    String? configUuid,
    required Map<String, dynamic> values,
  }) async {
    final body = {...values, 'cityId': cityId, 'active': true};
    if (configUuid != null && configUuid.isNotEmpty) {
      await NodeAuthService.patchJson('/delivery-configs/$configUuid',
          token: token, body: body);
    } else {
      await NodeAuthService.postJson('/delivery-configs',
          token: token, body: body);
    }
  }

  static Future<List<dynamic>> getDeliveryDocuments(String token,
      {String? country}) async {
    final query = <String, String>{};
    if (country?.trim().isNotEmpty == true) {
      query['country'] = country!.trim();
    }
    final response = await NodeAuthService.getJson(
      '/admin/delivery-documents',
      token: token,
      queryParameters: query.isNotEmpty ? query : null,
    );
    return response['data'] as List<dynamic>;
  }

  static Future<void> validateDeliveryDocuments(
      String documentId, String status, String token,
      {String? remark}) async {
    await NodeAuthService.patchJson(
      '/admin/delivery-documents/validate',
      token: token,
      body: {
        'documentId': documentId,
        'status': status,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
    );
  }

  static Future<List<dynamic>> getScheduledDeletions(String token,
      {String? country}) async {
    final query = <String, String>{};
    if (country?.trim().isNotEmpty == true) {
      query['country'] = country!.trim();
    }
    final response = await NodeAuthService.getJson(
      '/admin/scheduled-deletions',
      token: token,
      queryParameters: query.isNotEmpty ? query : null,
    );
    return response['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getReferralStats(String token) async {
    final response = await NodeAuthService.getJson(
      '/admin/referral-stats',
      token: token,
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Retourne la liste des pays présents dans la base de données.
  /// Seul le superAdmin doit appeler cette méthode.
  static Future<List<String>> getAvailableCountries(String token) async {
    try {
      final response = await NodeAuthService.getJson(
        '/admin/countries',
        token: token,
      );
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<String>()
            .where((c) => c.trim().isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String text,
    required String token,
  }) async {
    try {
      await NodeAuthService.postJson(
        '/admin/send-email',
        token: token,
        body: {'to': to, 'subject': subject, 'text': text},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> validateRestaurant(int restaurantId, String token) async {
    await NodeAuthService.patchJson(
      '/admin/restaurants/$restaurantId',
      token: token,
      body: {'valid': 1},
    );
  }

  static Future<void> rejectRestaurant(
      int restaurantId, String remark, String token) async {
    await NodeAuthService.patchJson(
      '/admin/restaurants/$restaurantId',
      token: token,
      body: {
        'valid': 2,
        'reviewRemark': remark,
      },
    );
  }

  static Future<void> setIdentityStatus(
      int userId, String status, String token) async {
    await NodeAuthService.patchJson(
      '/admin/users/$userId/identity-status',
      token: token,
      body: {'status': status},
    );
  }

  static Future<void> forceDeleteUser(int userId, String token) async {
    await NodeAuthService.deleteJson(
      '/admin/users/$userId/force',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> getUserDetails(
      int userId, String token) async {
    final response = await NodeAuthService.getJson(
      '/admin/users/$userId/details',
      token: token,
    );
    return response['data'] as Map<String, dynamic>;
  }

  static Future<Users> updateUserProfile({
    required int userId,
    required String token,
    String? firstname,
    String? lastname,
    String? email,
    String? telephone,
    String? image,
  }) async {
    final body = <String, dynamic>{};
    if (firstname != null) body['firstname'] = firstname;
    if (lastname != null) body['lastname'] = lastname;
    if (email != null) body['email'] = email;
    if (telephone != null) body['telephone'] = telephone;
    if (image != null) body['image'] = image;
    final response = await NodeAuthService.patchJson(
      '/admin/users/$userId/profile',
      token: token,
      body: body,
    );
    return Users.fromNodeAuth(response['data'] as Map<String, dynamic>);
  }
}
