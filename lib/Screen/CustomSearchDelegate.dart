import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomSearchDelegate extends SearchDelegate<void> {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<_SearchData>(
      future: _loadSearchData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final normalizedQuery = query.trim().toLowerCase();

        final matchingRestaurants = data.restaurants.where((restaurant) {
          final haystack =
              '${restaurant.name} ${restaurant.categories} ${restaurant.description}'
                  .toLowerCase();
          return normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
        }).toList();

        final matchingDishes = data.dishes.where((dish) {
          final haystack =
              '${dish.name} ${dish.categories} ${dish.description}'.toLowerCase();
          return normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
        }).toList();

        if (matchingRestaurants.isEmpty && matchingDishes.isEmpty) {
          return const Center(
            child: Text('Aucun restaurant ou plat trouvé.'),
          );
        }

        return ListView(
          children: [
            if (matchingRestaurants.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Restaurants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...matchingRestaurants.map(
                (restaurant) => ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE1DC),
                    child: Icon(Icons.storefront, color: Colors.red),
                  ),
                  title: Text(restaurant.name),
                  subtitle: Text(
                    restaurant.categories.isEmpty
                        ? restaurant.openingHours
                        : restaurant.categories,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => RestaurantDetails(
                          restaurant_id: restaurant.restaurantID,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (matchingDishes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Plats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...matchingDishes.map(
                (dish) => ListTile(
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => DishDetails(
                          from_page: 0,
                          dish_id: dish.dishID,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<_SearchData> _loadSearchData() async {
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final dishes = await Dish.fetchDishesFromDB();

    final activeRestaurants =
        restaurants.where((restaurant) => restaurant.valid == 1).toList();
    final activeDishes = dishes.where((dish) => (dish.status ?? 0) == 1).toList();

    return _SearchData(restaurants: activeRestaurants, dishes: activeDishes);
  }
}

class _SearchData {
  const _SearchData({
    required this.restaurants,
    required this.dishes,
  });

  final List<Restaurant> restaurants;
  final List<Dish> dishes;
}
