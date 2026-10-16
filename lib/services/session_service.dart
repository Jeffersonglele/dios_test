import 'package:shared_preferences/shared_preferences.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/app_role.dart';
import 'livreur_api.dart';
import 'node_auth_service.dart';

class UserSession {
  const UserSession({
    required this.userId,
    required this.role,
    required this.country,
    this.email,
    this.restaurantId,
    this.isLoggedIn = false,
  });

  final int userId;
  final AppRole role;
  final String country;
  final String? email;
  final int? restaurantId;
  final bool isLoggedIn;

  bool get hasRestaurant => (restaurantId ?? 0) > 0;

  UserSession copyWith({
    int? userId,
    AppRole? role,
    String? country,
    String? email,
    int? restaurantId,
    bool? isLoggedIn,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      country: country ?? this.country,
      email: email ?? this.email,
      restaurantId: restaurantId ?? this.restaurantId,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class ServerAccountState {
  const ServerAccountState({
    required this.userId,
    required this.roleId,
    required this.country,
    required this.restaurantId,
    required this.restaurantValid,
    required this.restaurantRemark,
    this.restaurantIsPro = false,
    this.proRequestStatus = '',
    this.proRequestRemark = '',
    this.identity = '',
    this.identityRemark = '',
    this.vehicleType = '',
    this.vehiclePlate = '',
    this.image = '',
  });

  final int userId;
  final int roleId;
  final String country;
  final int restaurantId;

  /// -1 : aucun restaurant ; 0 : en attente ; 1 : validé ; 2 : refusé.
  final int restaurantValid;
  final String restaurantRemark;
  final bool restaurantIsPro;

  /// Dernière demande « Devenir Pro » : '', 'pending', 'approved', 'rejected'.
  final String proRequestStatus;
  final String proRequestRemark;

  /// Dossier livreur : 'Verified', 'En attente', 'Rejected' ou vide.
  final String identity;
  final String identityRemark;
  final String vehicleType;
  final String vehiclePlate;

  /// Photo de profil (pour un livreur : la photo du dossier).
  final String image;

  factory ServerAccountState.fromMap(Map<String, dynamic> map) {
    int number(Object? value, [int fallback = 0]) =>
        int.tryParse(value?.toString() ?? '') ?? fallback;

    return ServerAccountState(
      userId: number(map['userID']),
      roleId: number(map['roleID']),
      country: map['country']?.toString() ?? '',
      restaurantId: number(map['restaurantID']),
      restaurantValid: number(map['restaurantValid'], -1),
      restaurantRemark: map['restaurantRemark']?.toString() ?? '',
      restaurantIsPro: map['restaurantIsPro'] == true,
      proRequestStatus: map['proRequestStatus']?.toString() ?? '',
      proRequestRemark: map['proRequestRemark']?.toString() ?? '',
      identity: map['identity']?.toString() ?? '',
      identityRemark: map['identityRemark']?.toString() ?? '',
      vehicleType: map['vehicleType']?.toString() ?? '',
      vehiclePlate: map['vehiclePlate']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
    );
  }
}

class SessionService {
  const SessionService._();

  static const _isLoggedInKey = 'isLoggedIn';
  static const _loggedUserIdKey = 'loggedUserID';
  static const _currentUserRoleKey = 'currentUser_role';
  static const _currentUserCountryKey = 'currentUser_country';
  static const _currentUserEmailKey = 'currentUser_email';
  static const _currentUserRestaurantKey = 'currentUser_restau';
  static const _nodeTokenKey = 'node_auth_token';

  static Future<UserSession> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final prefLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    return UserSession(
      userId: prefs.getInt(_loggedUserIdKey) ?? 0,
      role: AppRole.fromId(prefs.getInt(_currentUserRoleKey)),
      country: prefs.getString(_currentUserCountryKey) ?? 'RDC',
      email: prefs.getString(_currentUserEmailKey),
      restaurantId: prefs.getInt(_currentUserRestaurantKey),
      isLoggedIn: prefLoggedIn &&
          (await hasNodeSession() || await hasParseSession()),
    );
  }

  static Future<void> saveUserSession({
    required int userId,
    required AppRole role,
    required String country,
    String? email,
    int? restaurantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_loggedUserIdKey, userId);
    await prefs.setInt(_currentUserRoleKey, role.id);
    await prefs.setString(_currentUserCountryKey, country);
    if (email != null) {
      await prefs.setString(_currentUserEmailKey, email);
    } else {
      await prefs.remove(_currentUserEmailKey);
    }

    if (restaurantId != null) {
      await prefs.setInt(_currentUserRestaurantKey, restaurantId);
    } else {
      await prefs.remove(_currentUserRestaurantKey);
    }
  }

  /// Adopte la session Parse créée par `loginUser` côté Cloud Code.
  ///
  /// Les préférences gardent uniquement les informations d'affichage et de
  /// navigation ; l'autorisation réelle est portée par le sessionToken Parse.
  static Future<bool> adoptParseSession(String sessionToken) async {
    if (sessionToken.trim().isEmpty) return false;
    try {
      final response = await ParseUser.getCurrentUserFromServer(sessionToken);
      if (!(response?.success ?? false) || response?.result == null) {
        return false;
      }

      final parseUser = response!.result as ParseUser;
      parseUser.sessionToken = sessionToken;
      await parseUser.saveInStorage(keyParseStoreUser);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Enregistre la session JWT renvoyée par le backend Node.js.
  ///
  /// Le profil est conservé dans les mêmes préférences que l'ancien flux
  /// Parse afin que les écrans de navigation existants restent compatibles.
  static Future<void> saveNodeSession({
    required String token,
    required int userId,
    required AppRole role,
    required String country,
    String? email,
    int? restaurantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nodeTokenKey, token);
    await saveUserSession(
      userId: userId,
      role: role,
      country: country,
      email: email,
      restaurantId: restaurantId,
    );
  }

  static Future<String?> readNodeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_nodeTokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  static Future<bool> hasNodeSession() async =>
      (await readNodeToken())?.isNotEmpty == true;

  /// Ouvre une session avec le système d'authentification natif de Parse.
  ///
  /// Le backend Parse historique authentifie encore certains profils dans la
  /// classe métier `Users`. Quand son Cloud Function ne renvoie pas encore de
  /// sessionToken, on utilise le compte `_User` correspondant s'il existe.
  /// Cela évite de faire dépendre l'application de la configuration JWT du
  /// backend Node.js.
  static Future<bool> loginParseUser(String username, String password) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) return false;

    try {
      final parseUser = ParseUser(normalizedUsername, password, null);
      final response = await parseUser.login();
      return response.success &&
          (parseUser.sessionToken?.isNotEmpty == true ||
              (response.result is ParseUser &&
                  (response.result as ParseUser).sessionToken?.isNotEmpty ==
                      true));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasParseSession() async {
    try {
      final parseUser = await ParseUser.currentUser();
      return parseUser.sessionToken?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  /// Lit le rôle et l'état des demandes vendeur / Pro sur le serveur.
  /// Cette vérification permet à chaque appareil de réagir à une validation
  /// faite par l'administrateur sans révoquer les sessions des autres appareils.
  /// Node d'abord (la connexion par email ferme la session Parse), Parse
  /// pour les comptes encore connectés par téléphone.
  static Future<ServerAccountState?> fetchServerAccountState() async {
    final token = await readNodeToken();
    if (token != null) {
      try {
        final response =
            await NodeAuthService.getJson('/auth/account-state', token: token);
        final data = response['data'];
        if (data is Map) {
          return ServerAccountState.fromMap(Map<String, dynamic>.from(data));
        }
      } catch (_) {
        // Hors ligne ou backend pas encore déployé : on tente Parse.
      }
    }
    if (!await hasParseSession()) return null;
    try {
      final response = await ParseCloudFunction('getMyAccountState').execute();
      if (!response.success || response.result is! Map) return null;
      return ServerAccountState.fromMap(
          Map<String, dynamic>.from(response.result as Map));
    } catch (_) {
      return null;
    }
  }

  /// Supprime uniquement la session Parse locale périmée.
  ///
  /// Cette méthode ne fait pas de logout réseau : elle ne touche donc pas
  /// aux sessions ouvertes sur les autres appareils du même compte.
  static Future<void> clearLocalParseSession() async {
    try {
      final parseUser = await ParseUser.currentUser();
      if (parseUser != null) {
        parseUser.forgetLocalSession();
        await parseUser.deleteLocalUserData();
      }
    } catch (_) {
      // Le nettoyage des préférences métier doit tout de même être effectué.
    } finally {
      await markLoggedOut();
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final role = AppRole.fromId(prefs.getInt(_currentUserRoleKey));
    final userId = prefs.getInt(_loggedUserIdKey) ?? 0;
    try {
      if (role.isDelivery && userId > 0) {
        // Toutes les sorties de session rendent le livreur invisible côté Parse.
        await LivreurApi.toggleOnlineStatus(userId, false);
      }
      final parseUser = await ParseUser.currentUser();
      if (parseUser.sessionToken?.isNotEmpty == true) {
        await parseUser.logout();
      }
    } catch (_) {
      // La session locale doit être supprimée même si le réseau est absent.
    } finally {
      await markLoggedOut();
    }
  }

  static Future<void> setRestaurantId(int restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserRestaurantKey, restaurantId);
  }

  static Future<void> markLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_loggedUserIdKey);
    await prefs.remove(_currentUserRoleKey);
    await prefs.remove(_currentUserCountryKey);
    await prefs.remove(_currentUserEmailKey);
    await prefs.remove(_currentUserRestaurantKey);
    await prefs.remove(_nodeTokenKey);
  }

  static Future<void> clearAll() async {
    await logout();
    final prefs = await SharedPreferences.getInstance();
    final welcomeKeys = prefs.getKeys().where((k) => k.startsWith('has_seen_welcome_'));
    final welcomeValues = <String, bool>{};
    for (final k in welcomeKeys) {
      welcomeValues[k] = prefs.getBool(k) ?? false;
    }
    await prefs.clear();
    for (final e in welcomeValues.entries) {
      await prefs.setBool(e.key, e.value);
    }
  }
}
