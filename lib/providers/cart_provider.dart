// cart_provider.dart - Version corrigée

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/users.dart';
import '../models/address.dart' as addr;
import '../services/session_service.dart';

class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]) {
    _restoreCartForCurrentSession();
  }

  double total = 0.0;
  int? _activeUserId;
  int? _loadedUserId;
  int _activationVersion = 0;

  List<Map<String, dynamic>> get items => List.unmodifiable(state);

  String _storageKey(int userId) => 'saved_cart_user_$userId';

  Future<void> _restoreCartForCurrentSession() async {
    final session = await SessionService.readSession();
    await activateUser(session.userId);
  }

  /// Charge uniquement le panier du compte actif sur cet appareil.
  /// Les paniers restent privés même après déconnexion / reconnexion.
  Future<void> activateUser(int userId) async {
    final version = ++_activationVersion;
    if (userId <= 0) {
      _activeUserId = null;
      _loadedUserId = null;
      total = 0;
      state = [];
      return;
    }
    if (_activeUserId == userId && _loadedUserId == userId) return;

    await _saveCart();
    if (version != _activationVersion) return;

    _activeUserId = userId;
    _loadedUserId = null;
    total = 0;
    state = [];

    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString(_storageKey(userId));

    // Migration à usage unique de l'ancien panier global vers son propriétaire.
    if (saved == null) {
      final legacy = prefs.getString('saved_cart');
      if (legacy != null) {
        try {
          final legacyItems = List<dynamic>.from(jsonDecode(legacy));
          final ownedItems = legacyItems
              .whereType<Map>()
              .where((item) => item['user_id']?.toString() == userId.toString())
              .toList();
          if (ownedItems.isNotEmpty) {
            saved = jsonEncode(ownedItems);
            await prefs.setString(_storageKey(userId), saved);
          }
        } catch (_) {}
      }
    }

    if (version != _activationVersion) return;
    final restored = _deserializeCart(saved, userId);
    total = _calculateTotal(restored);
    _loadedUserId = userId;
    state = restored;
  }

  List<Map<String, dynamic>> _deserializeCart(String? saved, int userId) {
    if (saved == null) return [];
    try {
      final rawItems = List<dynamic>.from(jsonDecode(saved));
      return rawItems.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        if (item.containsKey('meal')) return item;

        // Compatibilité avec le format compact de l'ancien panier global.
        return <String, dynamic>{
          'meal': <String, dynamic>{
            'mealID': item['mealID'],
            'meal_name': item['meal_name'],
            'price': item['price'],
            'image': item['image'] ?? '',
            'country': item['country'] ?? 'France',
            'number_of_servings': 99,
          },
          'order': <String, dynamic>{'quantity': item['quantity'] ?? 1},
          'options': item['options'] ?? <String, dynamic>{},
          'optionDetails': item['optionDetails'] ?? <String, dynamic>{},
          'optionPrice': item['optionPrice'] ?? 0,
          'user': <String, dynamic>{'user_id': userId},
          'restaurant': <String, dynamic>{
            'restau_id': item['restau_id'],
            'delivery_fee': 0,
          },
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  double _calculateTotal(List<Map<String, dynamic>> cart) => cart.fold(
        0.0,
        (sum, item) =>
            sum +
            ((item['meal']['price'] as num?)?.toDouble() ?? 0) *
                ((item['order']['quantity'] as num?)?.toInt() ?? 0),
      );

  Future<String> addToCart(
    int mealID,
    String name,
    double price,
    String image,
    int quantity,
    int maxServings,
    String country,
    int user_id,
    int restau_id, {
    Map<int, String>? selectedChoices,
    double optionPrice = 0.0,
    List<String?>? rawOptions,
  }) async {
    try {
      await activateUser(user_id);
      final existingIndex =
          state.indexWhere((item) => item['meal']['meal_name'] == name);

      List<Users> usersList = await Users.fetchUsersFromDB();
      List<Restaurant> restaurantsList =
          await Restaurant.fetchRestaurantsFromDB();

      Users? currentUser = Users.getUsersByUserId(usersList, user_id);
      Restaurant? restaurant =
          Restaurant.getRestaurantByRestaurantId(restaurantsList, restau_id);

      if (currentUser == null || restaurant == null) return 'error';

      // Récupérer les coordonnées du restaurant depuis son adresse
      double? restauLat, restauLng;
      try {
        final addresses = await addr.Address.fetchAddressesFromDB();
        final restauAddr = addresses.cast<addr.Address?>().firstWhere(
          (a) => a?.object == 'Restaurant' && a?.objectID == restaurant.userID,
          orElse: () => null,
        );
        if (restauAddr != null) {
          restauLat = double.tryParse(restauAddr.lat ?? '');
          restauLng = double.tryParse(restauAddr.long ?? '');
        }
      } catch (_) {}

      double finalPrice = price + optionPrice;

      if (state.isNotEmpty) {
        final existingRestaurantId = state.first['restaurant']['restau_id'];
        if (existingRestaurantId != restau_id) {
          return 'different_restaurant';
        }
      }

      // Construction des options formatées
      Map<String, dynamic> formattedOptions = {};
      Map<String, dynamic> optionDetails = {};

      if (selectedChoices != null && selectedChoices.isNotEmpty) {
        selectedChoices.forEach((index, value) {
          if (rawOptions != null &&
              index < rawOptions.length &&
              rawOptions[index] != null) {
            final parts = rawOptions[index]!.split(':');
            final optionTitle =
                parts.isNotEmpty ? parts.first.trim() : 'Option ${index + 1}';

            // Extraire le prix de l'option
            double optionPriceValue = 0.0;
            if (parts.length > 1) {
              final priceMatch = RegExp(r'([\d.,]+)').firstMatch(parts[1]);
              if (priceMatch != null) {
                optionPriceValue = double.tryParse(
                        priceMatch.group(0)!.replaceAll(',', '.')) ??
                    0.0;
              }
            }

            formattedOptions[optionTitle] = {
              'choice': value,
              'price': optionPriceValue,
            };

            optionDetails[optionTitle] = {
              'name': value,
              'price': optionPriceValue,
            };
          }
        });
      }

      if (existingIndex != -1) {
        final newQuantity =
            state[existingIndex]['order']['quantity'] + quantity;
        if (newQuantity <= maxServings) {
          state[existingIndex]['order']['quantity'] = newQuantity;
          state = List<Map<String, dynamic>>.from(state);
        }
      } else {
        state = [
          ...state,
          {
            "meal": {
              "mealID": mealID,
              "meal_name": name,
              "price": finalPrice,
              "image": image,
              "number_of_servings": maxServings,
              "country": country,
            },
            "order": {
              "quantity": quantity,
            },
            "options": formattedOptions,
            "optionDetails": optionDetails, // ← AJOUTER CETTE LIGNE
            "optionPrice": optionPrice, // ← AJOUTER CETTE LIGNE
            "user": {
              "email": currentUser.email,
              "firstname": currentUser.firstname,
              "user_id": user_id,
            },
            "restaurant": {
              "name": restaurant.name,
              "restau_id": restau_id,
              "delivery_fee": restaurant.deliveryFee,
              "opening_hours": restaurant.openingHours,
              "is_open": restaurant.isOpen,
              "restau_lat": restauLat,
              "restau_lng": restauLng,
            },
          },
        ];
      }

      total += finalPrice * quantity;
      await _saveCart();
      return 'success';
    } catch (e) {
      return 'error';
    }
  }

  void removeFromCart(int index) {
    total -= state[index]['meal']['price'] * state[index]['order']['quantity'];
    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
    _saveCart();
  }

  Future<void> _saveCart() async {
    final userId = _activeUserId;
    if (userId == null || userId <= 0) return;
    final snapshot = List<Map<String, dynamic>>.from(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(userId), jsonEncode(snapshot));
  }

  void clearCart() {
    state = [];
    total = 0.0;
    _saveCart();
  }

  void updateQuantity(int index, int newQuantity) {
    final item = state[index];
    final oldQuantity = item['order']['quantity'];
    final price = item['meal']['price'];

    final quantityDiff = newQuantity - oldQuantity;
    total += price * quantityDiff;
    state[index]['order']['quantity'] = newQuantity;
    state = List.from(state);
    _saveCart();
  }
}

final cartStateProvider =
    StateNotifierProvider<CartNotifier, List<Map<String, dynamic>>>((ref) {
  return CartNotifier();
});
