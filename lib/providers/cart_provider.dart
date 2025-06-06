import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../utils/toast.dart';

class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]);

  double total = 0.0;

  Future<void> addToCart(
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
      }) async {
    final existingIndex = state.indexWhere((item) => item['meal']['meal_name'] == name);

    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restaurantsList = await Restaurant.fetchRestaurantsFromDB();

    Users? currentUser = Users.getUsersByUserId(usersList, user_id);
    Restaurant? restaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, restau_id);

    if (currentUser == null || restaurant == null) return;

    double finalPrice = price;

    if (existingIndex != -1) {
      state[existingIndex]['order']['quantity'] += quantity;
      if (state[existingIndex]['order']['quantity'] > maxServings) {
        state[existingIndex]['order']['quantity'] = maxServings;
      }
    } else {
      state = [
        ...state,
        {
          "meal": {
            "meal_name": name,
            "price": finalPrice,
            "image": image,
            "number_of_servings": maxServings,
            "country": country,
            "options": selectedChoices ?? {},
          },
          "order": {
            "quantity": quantity,
          },
          "optionPrice": optionPrice,
          "optionDetails": selectedChoices != null
              ? selectedChoices.map((index, value) {
                print("selectedChoices " + selectedChoices.toString());
            final match = RegExp(r'^(.*?)\s*\(([\d.,]+)\)$').firstMatch(value);
            final name = match?.group(1)?.trim() ?? value;
            final priceStr = match?.group(2)?.replaceAll(',', '.');
            return MapEntry(index, {
              'name': name,
              'price': priceStr != null ? double.tryParse(priceStr) ?? 0.0 : 0.0
            });
          })
              : {},
          "user": {
            "email": currentUser.email ?? "email inconnu",
            "firstname": currentUser.firstname ?? "Prénom inconnu",
          },
          "restaurant": {
            "name": restaurant.name ?? "Restaurant inconnu",
          },
        },
      ];
    }

    total += finalPrice * quantity;
  }

  void removeFromCart(int index) {
    total -= state[index]['meal']['price'] * state[index]['order']['quantity'];
    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
  }

  void clearCart() {
    state = [];
    total = 0.0;
  }

  void updateQuantity(int index, int newQuantity) {
    final item = state[index];
    final oldQuantity = item['order']['quantity'];
    final price = item['meal']['price'];

    final quantityDiff = newQuantity - oldQuantity;

    // On ne touche pas à optionPrice ici !
    total += price * quantityDiff;

    state[index]['order']['quantity'] = newQuantity;

    // Déclencher la mise à jour de l’UI
    state = List.from(state);
  }


}

final cartStateProvider = StateNotifierProvider<CartNotifier, List<Map<String, dynamic>>>((ref) {
  return CartNotifier();
});
