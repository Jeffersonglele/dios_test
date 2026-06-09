import 'package:dios_delices/screens/dish/dish_details.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/nearby_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NearMeMeals extends StatefulWidget {
  final String? category;
  const NearMeMeals({super.key, this.category});

  @override
  State<NearMeMeals> createState() => _NearMeMealsState();
}

class _NearMeMealsState extends State<NearMeMeals> {
  final TextEditingController _searchController = TextEditingController();
  List<NearbyDishResult> _allDishes = [];
  List<NearbyDishResult> _visibleDishes = [];
  bool _isLoading = true;
  bool _showAll = true; // "Tout" is selected by default
  bool _openRestaurantsOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyDishes();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyDishes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dishes = await NearbyService.getNearbyDishes(
        maxDistanceKm: _showAll ? 100 : 10,
        openRestaurantsOnly: _openRestaurantsOnly,
      );

      if (mounted) {
        setState(() {
          _allDishes = dishes;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allDishes = [];
          _visibleDishes = [];
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final catFilter = widget.category?.toLowerCase();

    final filtered = _allDishes.where((result) {
      final dishName = result.dish.name?.toLowerCase() ?? '';
      final dishCat = result.dish.categories?.toLowerCase() ?? '';
      final restoName = result.restaurant.name?.toLowerCase() ?? '';

      final haystack = '$dishName $dishCat $restoName';
      final matchesQuery = query.isEmpty || haystack.contains(query);
      final matchesCategory = catFilter == null || dishCat.contains(catFilter);
      return matchesQuery && matchesCategory;
    }).toList();

    if (mounted) {
      setState(() {
        _visibleDishes = filtered;
      });
    }
  }

  Future<void> _updateShowAll(bool value) async {
    setState(() {
      _showAll = value;
    });
    await _loadNearbyDishes();
  }

  Future<void> _updateOpenOnly(bool value) async {
    setState(() {
      _openRestaurantsOnly = value;
    });
    await _loadNearbyDishes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.near_meals_title,
            style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNearbyDishes,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextField(
              controller: _searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: l10n.near_meals_search_hint,
                hintStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(l10n.home_category_all,
                      style: TextStyle(
                          color:
                              _showAll ? Colors.white : colorScheme.onSurface)),
                  selected: _showAll,
                  selectedColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  checkmarkColor: Colors.white,
                  onSelected: _updateShowAll,
                ),
                FilterChip(
                  label: Text(l10n.near_meals_filter_open,
                      style: TextStyle(
                          color: _openRestaurantsOnly
                              ? Colors.white
                              : colorScheme.onSurface)),
                  selected: _openRestaurantsOnly,
                  selectedColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  checkmarkColor: Colors.white,
                  onSelected: _updateOpenOnly,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(
                  child: CircularProgressIndicator(
                      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)))
            else if (_visibleDishes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(l10n.near_meals_no_results,
                      style: TextStyle(color: colorScheme.onSurface)),
                ),
              )
            else
              ..._visibleDishes.map(
                (result) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: _DishAvatar(imageUrl: result.dish.image),
                    title: Text(
                      result.dish.name ?? 'Plat',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(result.restaurant.name ?? 'Restaurant',
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7))),
                        Text(
                          '${result.dish.nb_orders} commandes | ${result.dish.nb_servings ?? 0} portions',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: colorScheme.onSurface.withOpacity(0.5)),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => DishDetails(
                            from_page: 0,
                            dish_id: result.dish.dishID,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : colorScheme.onSurface)),
      selected: selected,
      selectedColor:
          AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      checkmarkColor: Colors.white,
      onSelected: (_) => onTap(),
    );
  }
}

class _DishAvatar extends StatelessWidget {
  const _DishAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    if (!hasImage) {
      return const CircleAvatar(
        radius: 28,
        child: Icon(Icons.restaurant_menu),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage(imageUrl!),
      child: const Icon(Icons.restaurant_menu),
    );
  }
}
