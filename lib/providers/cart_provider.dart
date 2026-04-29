import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modeles/restaurant.dart';
import '../modeles/users.dart';

class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]);

  double total = 0.0;

  List<Map<String, dynamic>> get items => List.unmodifiable(state);

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
    final existingIndex = state.indexWhere((item) => item['meal']['meal_name'] == name);

    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restaurantsList = await Restaurant.fetchRestaurantsFromDB();

    Users? currentUser = Users.getUsersByUserId(usersList, user_id);
    Restaurant? restaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, restau_id);

    if (currentUser == null || restaurant == null) return 'error';

    double finalPrice = price;

    if (state.isNotEmpty) {
      final existingRestaurantId = state.first['restaurant']['restau_id'];
      if (existingRestaurantId != restau_id) {
        return 'different_restaurant';
      }
    }

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
            "mealID": mealID,
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
            // 🔹 Récupère le titre de l’option (ex: "Toppings")
            String title = "";
            if (rawOptions != null && index < rawOptions.length && rawOptions[index] != null) {
              final parts = rawOptions[index]!.split(':');
              if (parts.isNotEmpty) title = parts.first.trim();
            }

            // 🔹 Extraire nom & prix depuis le choix formaté (ex: "Nutella (1.3 €)")
            //final priceMatch = RegExp(r'([\d.,]+)').firstMatch(value);
            //final nameMatch = RegExp(r'^(.*?)\s*\(').firstMatch(value);

            String priceStr = '';
            if (rawOptions != null && index < rawOptions.length && rawOptions[index] != null) {
              final parts = rawOptions[index]!.split(':');
              if (parts.length > 1) {
                final choixList = parts[1].split('/').map((e) => e.trim()).toList();
                if (choixList.isNotEmpty) {
                  priceStr = choixList.last.replaceAll(',', '.');
                }
              }
            }
            final price = double.tryParse(priceStr) ?? 0.0;
            final name = value; // juste le nom du choix

            return MapEntry(index, {
              'title': title,   // ✅ nom de l'option (Sucre, Toppings...)
              'name': name,     // ✅ choix fait (Nutella, 10%, Oui...)
              'price': price,   // ✅ prix numérique
            });
          })
              : {},
          "user": {
            "email": currentUser.email ?? "email inconnu",
            "firstname": currentUser.firstname ?? "Prénom inconnu",
            "user_id": user_id,
          },
          "restaurant": {
            "name": restaurant.name ?? "Restaurant inconnu",
            "restau_id": restau_id,
            "delivery_fee": restaurant.deliveryFee,
            "opening_hours": restaurant.openingHours,
            "is_open": restaurant.isOpen,
          },
        },
      ];
    }

    total += finalPrice * quantity;
    return 'success';
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
