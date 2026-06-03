import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modeles/restaurant.dart';
import '../modeles/users.dart';

class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]) {
    _loadCart();
  }

  double total = 0.0;

  List<Map<String, dynamic>> get items => List.unmodifiable(state);

  Future<String> addToCart(
    int mealID,
    String name,
    double basePrice,
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
      List<Users> usersList = await Users.fetchUsersFromDB();
      List<Restaurant> restaurantsList =
          await Restaurant.fetchRestaurantsFromDB();

      Users? currentUser = Users.getUsersByUserId(usersList, user_id);

      Restaurant? restaurant = Restaurant.getRestaurantByRestaurantId(
        restaurantsList,
        restau_id,
      );

      if (currentUser == null || restaurant == null) {
        return 'error';
      }

      // IMPORTANT:
      // - meal.price doit contenir UNIQUEMENT le prix de base (sans options)
      // - optionPrice est stocké séparément
      // Ainsi le panier fait (unitPrice + optionPrice) et évite la double addition.
      double finalPrice = basePrice;

      // Vérification restaurant unique
      if (state.isNotEmpty) {
        final existingRestaurantId = state.first['restaurant']['restau_id'];

        if (existingRestaurantId != restau_id) {
          return 'different_restaurant';
        }
      }

      // =========================
      // Construction des options
      // =========================

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

            // Format attendu :
            // Nutella|500

            final splitValue = value.split('|');

            final choiceName = splitValue[0].trim();

            double optionPriceValue = 0.0;

            if (splitValue.length > 1) {
              optionPriceValue = double.tryParse(
                    splitValue[1].replaceAll(',', '.'),
                  ) ??
                  0.0;
            }

            formattedOptions[optionTitle] = {
              'choice': choiceName,
              'price': optionPriceValue,
            };

            optionDetails[optionTitle] = {
              'name': choiceName,
              'price': optionPriceValue,
            };
          }
        });
      }

      // =====================================
      // Vérification si plat déjà dans panier
      // =====================================

      final existingIndex = state.indexWhere(
        (item) =>
            item['meal']['meal_name'] == name &&
            mapEquals(
              Map<String, dynamic>.from(item['options'] ?? {}),
              formattedOptions,
            ),
      );

      // =========================
      // Mise à jour quantité
      // =========================

      if (existingIndex != -1) {
        final currentQuantity = state[existingIndex]['order']['quantity'];

        final newQuantity = currentQuantity + quantity;

        if (newQuantity <= maxServings) {
          state[existingIndex]['order']['quantity'] = newQuantity;

          total += finalPrice * quantity;
        }
      } else {
        // =========================
        // Ajout nouvel article
        // =========================

        state = [
          ...state,
          {
            "meal": {
              "mealID": mealID,
              "meal_name": name,
              "base_price": basePrice,
              "price": finalPrice,
              "image": image,
              "number_of_servings": maxServings,
              "country": country,
            },
            "order": {
              "quantity": quantity,
            },
            "options": formattedOptions,
            "optionDetails": optionDetails,
            "optionPrice": optionPrice,
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
            },
          },
        ];

        total += finalPrice * quantity;
      }

      _saveCart();

      return 'success';
    } catch (e) {
      print('Erreur addToCart: $e');
      return 'error';
    }
  }

  // =========================
  // Supprimer article
  // =========================

  void removeFromCart(int index) {
    final item = state[index];

    total -= item['meal']['price'] * item['order']['quantity'];

    state = [
      ...state.sublist(0, index),
      ...state.sublist(index + 1),
    ];

    _saveCart();
  }

  // =========================
  // Sauvegarde locale
  // =========================

  void _saveCart() {
    SharedPreferences.getInstance().then((prefs) {
      final serialized = state.map((item) {
        final meal = item['meal'];
        final order = item['order'];
        final restaurant = item['restaurant'];
        final user = item['user'];

        return {
          'mealID': meal['mealID'],
          'meal_name': meal['meal_name'],
          'base_price': meal['base_price'],
          'price': meal['price'],
          'image': meal['image'],
          'country': meal['country'],
          'quantity': order['quantity'],
          'restau_id': restaurant['restau_id'],
          'user_id': user['user_id'],
          'options': item['options'],
          'optionDetails': item['optionDetails'],
          'optionPrice': item['optionPrice'],
        };
      }).toList();

      prefs.setString(
        'saved_cart',
        jsonEncode(serialized),
      );
    });
  }

  // =========================
  // Chargement panier
  // =========================

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString('saved_cart');

    if (saved == null) return;

    try {
      final List items = jsonDecode(saved);

      for (final i in items) {
        await addToCart(
          i['mealID'],
          i['meal_name'],

          // IMPORTANT :
          // on recharge le prix de base
          // PAS le prix final
          (i['base_price'] as num).toDouble(),

          i['image'] ?? '',

          i['quantity'],

          99,

          i['country'] ?? 'France',

          i['user_id'],

          i['restau_id'],

          optionPrice: (i['optionPrice'] as num?)?.toDouble() ?? 0.0,

          selectedChoices: {},

          rawOptions: [],
        );
      }
    } catch (e) {
      print('Erreur chargement panier: $e');
    }
  }

  // =========================
  // Vider panier
  // =========================

  void clearCart() {
    state = [];

    total = 0.0;

    _saveCart();
  }

  // =========================
  // Modifier quantité
  // =========================

  void updateQuantity(
    int index,
    int newQuantity,
  ) {
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
    StateNotifierProvider<CartNotifier, List<Map<String, dynamic>>>(
  (ref) {
    return CartNotifier();
  },
);
