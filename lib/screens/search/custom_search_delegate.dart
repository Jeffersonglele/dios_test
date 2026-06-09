import 'package:dios_delices/screens/dish/dish_details.dart';
import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dios_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomSearchDelegate extends SearchDelegate<void> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: Icon(Icons.clear_rounded, color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
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
              Icon(Icons.search_off_rounded, size: 56, color: AppColors.resolve(AppColors.border, AppDarkColors.border)),
              const SizedBox(height: 12),
              Text(l10n.search_no_results_for(query), style: AppTypography.bodyMedium(color: colorScheme.onSurface.withOpacity(0.7))),
            ]),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (matchingRestos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.restaurants_section, style: AppTypography.titleMedium(color: colorScheme.onSurface)),
              ),
              ...matchingRestos.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
                ),
                child: ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface), borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Icon(Icons.storefront_rounded, color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 22),
                  ),
                  title: Text(r.name, style: AppTypography.labelMedium(color: colorScheme.onSurface)),
                  subtitle: Text(r.categories.isNotEmpty ? r.categories : r.openingHours,
                      style: AppTypography.bodyMedium(color: colorScheme.onSurface.withOpacity(0.7))),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
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
                child: Text(l10n.dishes_section, style: AppTypography.titleMedium(color: colorScheme.onSurface)),
              ),
              ...matchingDishes.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: DiosImage(url: d.image, width: 44, height: 44),
                  ),
                  title: Text(d.name ?? 'Plat', style: AppTypography.labelMedium(color: colorScheme.onSurface)),
                  subtitle: Text(CurrencyUtil.formatPrice(d.price?.toDouble() ?? 0, data.country),
                      style: AppTypography.bodyMedium(color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
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
    final session = await SessionService.readSession();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final dishes = await Dish.fetchDishesFromDB();
    return _SearchData(
      restaurants: restaurants.where((r) => r.valid == 1).toList(),
      dishes: dishes.where((d) => (d.status ?? 0) == 1).toList(),
      country: session.country,
    );
  }
}

class _SearchData {
  const _SearchData({required this.restaurants, required this.dishes, this.country = 'France'});
  final List<Restaurant> restaurants;
  final List<Dish> dishes;
  final String country;
}
