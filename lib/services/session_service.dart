import 'package:shared_preferences/shared_preferences.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/app_role.dart';

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

class SessionService {
  const SessionService._();

  static const _isLoggedInKey = 'isLoggedIn';
  static const _loggedUserIdKey = 'loggedUserID';
  static const _currentUserRoleKey = 'currentUser_role';
  static const _currentUserCountryKey = 'currentUser_country';
  static const _currentUserEmailKey = 'currentUser_email';
  static const _currentUserRestaurantKey = 'currentUser_restau';

  static Future<UserSession> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final prefLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    return UserSession(
      userId: prefs.getInt(_loggedUserIdKey) ?? 0,
      role: AppRole.fromId(prefs.getInt(_currentUserRoleKey)),
      country: prefs.getString(_currentUserCountryKey) ?? "France",
      email: prefs.getString(_currentUserEmailKey),
      restaurantId: prefs.getInt(_currentUserRestaurantKey),
      isLoggedIn: prefLoggedIn && await hasParseSession(),
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

  static Future<bool> hasParseSession() async {
    try {
      final parseUser = await ParseUser.currentUser();
      return parseUser.sessionToken?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    try {
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
