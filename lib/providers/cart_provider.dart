import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../utils/toast.dart';

class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]);

  double total = 0.0;

  Future<void> addToCart(String name, double price, String image, int quantity, int maxServings, String country, int user_id, int restau_id) async {
    final existingIndex = state.indexWhere((item) => item['meal']['meal_name'] == name);

    // Récupérer les utilisateurs et les restaurants depuis la base de données
    List<Users> usersList = await Users.fetchUsersFromDB(); // À implémenter pour récupérer les utilisateurs
    List<Restaurant> restaurantsList = await Restaurant.fetchRestaurantsFromDB(); // À implémenter pour récupérer les restaurants

    // Récupérer l'utilisateur actuel
    Users? currentUser = Users.getUsersByUserId(usersList, user_id);
    print("currentUser " + currentUser!.email);
    if (currentUser == null) {
      //Toast(context, "Utilisateur non trouvé", false);
      return;
    }

    // Récupérer le restaurant
    Restaurant? restaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, restau_id);
    print("restaurant " + restaurant!.name);
    if (restaurant == null) {
      // Toast(context, "Restaurant non trouvé", false);
      return;
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
            "meal_name": name,
            "price": price,
            "image": image,
            "number_of_servings": maxServings,
            "country": country
          },
          "order": {
            "quantity": quantity,
          },
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
    total += price * quantity;
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

    // Update the item's quantity
    state[index]['order']['quantity'] = newQuantity;

    // Recalculate the total
    total += price * (newQuantity - oldQuantity);

    // Notify listeners
    state = List.from(state); // Create a new list to trigger the UI update
  }

}

final cartStateProvider = StateNotifierProvider<CartNotifier, List<Map<String, dynamic>>>((ref) {
  return CartNotifier();
});
