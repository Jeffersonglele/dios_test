import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/services/favorites_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Favorites extends StatefulWidget {
  const Favorites({super.key});

  @override
  State<Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<Favorites> {
  bool isLoading = true;
  List<Restaurant> favoriteRestaurants = [];
  List<Dish> favoriteDishes = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final restaurantIds = await FavoritesService.getFavoriteRestaurantIds();
    final dishIds = await FavoritesService.getFavoriteDishIds();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final dishes = await Dish.fetchDishesFromDB();

    if (!mounted) return;
    setState(() {
      favoriteRestaurants = restaurants
          .where((restaurant) => restaurantIds.contains(restaurant.restaurantID))
          .toList();
      favoriteDishes =
          dishes.where((dish) => dishIds.contains(dish.dishID)).toList();
      isLoading = false;
    });
  }

  Future<void> _removeRestaurant(int restaurantId) async {
    await FavoritesService.toggleRestaurantFavorite(restaurantId);
    await _loadFavorites();
  }

  Future<void> _removeDish(int dishId) async {
    await FavoritesService.toggleDishFavorite(dishId);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          onRefresh: _loadFavorites,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                  children: [
                    const Text(
                      'Mes favoris',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Retrouvez ici vos restaurants et plats préférés.',
                    ),
                    const SizedBox(height: 20),
                    _buildRestaurantSection(),
                    const SizedBox(height: 20),
                    _buildDishSection(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRestaurantSection() {
    return _FavoriteSection(
      title: 'Restaurants favoris',
      emptyMessage: "Aucun restaurant en favori pour l'instant.",
      children: favoriteRestaurants
          .map(
            (restaurant) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE1DC),
                  child: Icon(Icons.storefront, color: Colors.red),
                ),
                title: Text(restaurant.name),
                subtitle: Text(
                  '${restaurant.openingHours} | Livraison ${restaurant.deliveryFee.toStringAsFixed(2)}',
                ),
                trailing: IconButton(
                  onPressed: () => _removeRestaurant(restaurant.restaurantID),
                  icon: const Icon(Icons.favorite, color: Colors.pink),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => RestaurantDetails(
                        restaurant_id: restaurant.restaurantID,
                      ),
                    ),
                  ).then((_) => _loadFavorites());
                },
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDishSection() {
    return _FavoriteSection(
      title: 'Plats favoris',
      emptyMessage: "Aucun plat en favori pour l'instant.",
      children: favoriteDishes
          .map(
            (dish) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF2E6),
                  child: Icon(Icons.restaurant_menu, color: Colors.deepOrange),
                ),
                title: Text(dish.name ?? 'Plat'),
                subtitle: Text(
                  '${dish.price?.toStringAsFixed(2) ?? '0.00'} | ${dish.categories ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () => _removeDish(dish.dishID),
                  icon: const Icon(Icons.favorite, color: Colors.pink),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => DishDetails(
                        from_page: 5,
                        dish_id: dish.dishID,
                      ),
                    ),
                  ).then((_) => _loadFavorites());
                },
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FavoriteSection extends StatelessWidget {
  const _FavoriteSection({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(emptyMessage),
          )
        else
          ...children,
      ],
    );
  }
}
