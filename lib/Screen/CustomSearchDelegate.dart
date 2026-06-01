import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/theme/app_theme.dart';
import '../widgets/dios_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomSearchDelegate extends SearchDelegate<void> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded, color: AppColors.inkMuted),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    return FutureBuilder<_SearchData>(
      future: _loadData(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final data = snap.data!;
        final q = query.trim().toLowerCase();

        final matchingRestos = data.restaurants.where((r) =>
            '${r.name} ${r.categories} ${r.description}'.toLowerCase().contains(q)).toList();
        final matchingDishes = data.dishes.where((d) =>
            '${d.name} ${d.categories} ${d.description}'.toLowerCase().contains(q)).toList();

        if (matchingRestos.isEmpty && matchingDishes.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search_off_rounded, size: 56, color: AppColors.border),
              const SizedBox(height: 12),
              Text('Aucun résultat pour "$query"', style: AppTypography.bodyMedium()),
            ]),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (matchingRestos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Restaurants', style: AppTypography.titleMedium()),
              ),
              ...matchingRestos.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.brandSurface, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.brand, size: 22),
                  ),
                  title: Text(r.name, style: AppTypography.labelMedium()),
                  subtitle: Text(r.categories.isNotEmpty ? r.categories : r.openingHours,
                      style: AppTypography.bodyMedium()),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
                  onTap: () {
                    Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => RestaurantDetails(restaurant_id: r.restaurantID)));
                  },
                ),
              )),
            ],
            if (matchingDishes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text('Plats', style: AppTypography.titleMedium()),
              ),
              ...matchingDishes.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: DiosImage(url: d.image, width: 44, height: 44),
                  ),
                  title: Text(d.name ?? 'Plat', style: AppTypography.labelMedium()),
                  subtitle: Text('${d.price?.toStringAsFixed(2) ?? '0'} €',
                      style: AppTypography.bodyMedium(color: AppColors.brand)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
                  onTap: () {
                    Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => DishDetails(from_page: 0, dish_id: d.dishID)));
                  },
                ),
              )),
            ],
          ],
        );
      },
    );
  }

  Future<_SearchData> _loadData() async {
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final dishes = await Dish.fetchDishesFromDB();
    return _SearchData(
      restaurants: restaurants.where((r) => r.valid == 1).toList(),
      dishes: dishes.where((d) => (d.status ?? 0) == 1).toList(),
    );
  }
}

class _SearchData {
  const _SearchData({required this.restaurants, required this.dishes});
  final List<Restaurant> restaurants;
  final List<Dish> dishes;
}
