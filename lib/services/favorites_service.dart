import 'package:shared_preferences/shared_preferences.dart';

import 'session_service.dart';

class FavoritesService {
  static const String _dishPrefix = 'favorite_dish_ids';
  static const String _restaurantPrefix = 'favorite_restaurant_ids';

  static Future<String> _scopedKey(String prefix) async {
    final session = await SessionService.readSession();
    return '${prefix}_${session.userId}';
  }

  static Future<Set<int>> _readIds(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(prefix);
    final values = prefs.getStringList(key) ?? <String>[];
    return values
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toSet();
  }

  static Future<void> _writeIds(String prefix, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(prefix);
    final values = ids.map((id) => id.toString()).toList()..sort();
    await prefs.setStringList(key, values);
  }

  static Future<Set<int>> getFavoriteDishIds() => _readIds(_dishPrefix);

  static Future<Set<int>> getFavoriteRestaurantIds() =>
      _readIds(_restaurantPrefix);

  static Future<bool> isDishFavorite(int dishId) async {
    final ids = await getFavoriteDishIds();
    return ids.contains(dishId);
  }

  static Future<bool> isRestaurantFavorite(int restaurantId) async {
    final ids = await getFavoriteRestaurantIds();
    return ids.contains(restaurantId);
  }

  static Future<bool> toggleDishFavorite(int dishId) async {
    final ids = await getFavoriteDishIds();
    if (ids.contains(dishId)) {
      ids.remove(dishId);
      await _writeIds(_dishPrefix, ids);
      return false;
    }

    ids.add(dishId);
    await _writeIds(_dishPrefix, ids);
    return true;
  }

  static Future<bool> toggleRestaurantFavorite(int restaurantId) async {
    final ids = await getFavoriteRestaurantIds();
    if (ids.contains(restaurantId)) {
      ids.remove(restaurantId);
      await _writeIds(_restaurantPrefix, ids);
      return false;
    }

    ids.add(restaurantId);
    await _writeIds(_restaurantPrefix, ids);
    return true;
  }
}
