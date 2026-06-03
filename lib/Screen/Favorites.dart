import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/services/favorites_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import '../widgets/dios_image.dart';
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
  String _tab = 'restaurants';

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
      favoriteRestaurants = restaurants.where((r) => restaurantIds.contains(r.restaurantID)).toList();
      favoriteDishes = dishes.where((d) => dishIds.contains(d.dishID)).toList();
      isLoading = false;
    });
  }

  Future<void> _removeRestaurant(int id) async {
    await FavoritesService.toggleRestaurantFavorite(id);
    await _loadFavorites();
  }

  Future<void> _removeDish(int id) async {
    await FavoritesService.toggleDishFavorite(id);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: _loadFavorites,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Mes favoris', style: AppTypography.headlineLarge()),
                          const SizedBox(height: 4),
                          Text('Retrouvez vos restaurants et plats préférés.',
                              style: AppTypography.bodyMedium()),
                          const SizedBox(height: 16),
                          // Tabs
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWarm,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Row(children: [
                              _TabBtn('Restaurants', 'restaurants'),
                              _TabBtn('Plats', 'plats'),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (_tab == 'restaurants')
                      favoriteRestaurants.isEmpty
                          ? _emptySliver('Aucun restaurant en favori.')
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _RestaurantCard(favoriteRestaurants[i]),
                                childCount: favoriteRestaurants.length,
                              ),
                            )
                    else
                      favoriteDishes.isEmpty
                          ? _emptySliver('Aucun plat en favori.')
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _DishCard(favoriteDishes[i]),
                                childCount: favoriteDishes.length,
                              ),
                            ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _TabBtn(String label, String value) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Text(label,
                style: AppTypography.labelMedium(color: active ? AppColors.brand : AppColors.inkMuted)),
          ),
        ),
      ),
    );
  }

  Widget _emptySliver(String msg) => SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Center(child: Text(msg, style: AppTypography.bodyMedium())),
        ),
      );

  Widget _RestaurantCard(Restaurant r) => GestureDetector(
        onTap: () => Navigator.push(context, CupertinoPageRoute(
            builder: (_) => RestaurantDetails(restaurant_id: r.restaurantID)))
            .then((_) => _loadFavorites()),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.brandSurface, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: const Icon(Icons.storefront_rounded, color: AppColors.brand, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: AppTypography.labelMedium()),
                Text('${r.openingHours} · ${r.deliveryFee.toStringAsFixed(2)} €',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              ]),
            ),
            _LikeButton(
              active: true,
              onTap: () => _removeRestaurant(r.restaurantID),
            ),
          ]),
        ),
      );

  Widget _DishCard(Dish d) => GestureDetector(
        onTap: () => Navigator.push(context, CupertinoPageRoute(
            builder: (_) => DishDetails(from_page: 5, dish_id: d.dishID)))
            .then((_) => _loadFavorites()),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: DiosImage(url: d.image, width: 56, height: 56),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name ?? 'Plat', style: AppTypography.labelMedium()),
                Text('${d.price?.toStringAsFixed(2) ?? '0'} €',
                    style: AppTypography.bodyMedium(color: AppColors.brand)),
              ]),
            ),
            _LikeButton(active: true, onTap: () => _removeDish(d.dishID)),
          ]),
        ),
      );
}

/// Bouton like avec animation de rebond
class _LikeButton extends StatefulWidget {
  const _LikeButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = Tween<double>(begin: 1, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: const Icon(Icons.favorite_rounded, color: AppColors.error, size: 22),
        ),
      ),
    );
  }
}
