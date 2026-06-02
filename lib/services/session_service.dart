import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_role.dart';

class UserSession {
  const UserSession({
    required this.userId,
    required this.role,
    required this.country,
    this.restaurantId,
    this.isLoggedIn = false,
  });

  final int userId;
  final AppRole role;
  final String country;
  final int? restaurantId;
  final bool isLoggedIn;

  bool get hasRestaurant => (restaurantId ?? 0) > 0;

  UserSession copyWith({
    int? userId,
    AppRole? role,
    String? country,
    int? restaurantId,
    bool? isLoggedIn,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      country: country ?? this.country,
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
  static const _currentUserRestaurantKey = 'currentUser_restau';

  static Future<UserSession> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    return UserSession(
      userId: prefs.getInt(_loggedUserIdKey) ?? 0,
      role: AppRole.fromId(prefs.getInt(_currentUserRoleKey)),
      country: prefs.getString(_currentUserCountryKey) ?? "France",
      restaurantId: prefs.getInt(_currentUserRestaurantKey),
      isLoggedIn: prefs.getBool(_isLoggedInKey) ?? false,
    );
  }

  static Future<void> saveUserSession({
    required int userId,
    required AppRole role,
    required String country,
    int? restaurantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_loggedUserIdKey, userId);
    await prefs.setInt(_currentUserRoleKey, role.id);
    await prefs.setString(_currentUserCountryKey, country);

    if (restaurantId != null) {
      await prefs.setInt(_currentUserRestaurantKey, restaurantId);
    } else {
      await prefs.remove(_currentUserRestaurantKey);
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
    await prefs.remove(_currentUserRestaurantKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final welcomeKeys = prefs.getKeys().where((k) => k.startsWith('has_seen_welcome_'));
    final welcomeValues = <String, bool>{};
    for (final k in welcomeKeys) {
      welcomeValues[k] = prefs.getBool(k) ?? false;
    }
    await prefs.clear();
    // Restaurer les clés welcome pour ne pas les réafficher
    for (final e in welcomeValues.entries) {
      await prefs.setBool(e.key, e.value);
    }
  }
}
