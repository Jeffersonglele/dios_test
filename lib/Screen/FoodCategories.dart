import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'NearMeMeals.dart';

class FoodCategories extends StatefulWidget {
  const FoodCategories({super.key});
  @override
  State<FoodCategories> createState() => _FoodCategoriesState();
}

class _FoodCategoriesState extends State<FoodCategories> {
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final dishes = await Dish.fetchDishesFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final cats = <String>{};
    // Catégories depuis les plats
    for (final d in dishes) {
      if (d.categories != null && d.categories!.trim().isNotEmpty) {
        cats.addAll(d.categories!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty));
      }
    }
    // Catégories depuis les restaurants
    for (final r in restaurants) {
      if (r.categories != null && r.categories!.trim().isNotEmpty) {
        cats.addAll(r.categories!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty));
      }
    }
    if (cats.isEmpty) {
      cats.addAll(['#africain', '#végétarien', '#dessert', '#fast-food', '#asiatique', '#boisson']);
    }
    if (mounted) setState(() { _categories = cats.toList()..sort(); _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Catégories')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _loadCategories,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => NearMeMeals(category: _categories[i]))),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.restaurant_rounded, color: AppColors.brand),
                      const SizedBox(width: 14),
                      Text(_categories[i], style: AppTypography.titleMedium().copyWith(fontSize: 18)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}
