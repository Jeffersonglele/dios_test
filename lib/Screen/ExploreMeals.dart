import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'DishDetails.dart';
import '../widgets/dios_image.dart';

class ExploreMeals extends StatefulWidget {
  const ExploreMeals({super.key});
  @override
  State<ExploreMeals> createState() => _ExploreMealsState();
}

class _ExploreMealsState extends State<ExploreMeals> {
  List<Dish> _dishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    final dishes = await Dish.fetchDishesFromDB();
    final available = dishes.where((d) => (d.status ?? 0) == 1).toList();
    if (mounted) setState(() { _dishes = available; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Explorer')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _loadDishes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _dishes.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.restaurant_rounded, size: 56, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text('Aucun plat disponible.', style: AppTypography.bodyMedium()),
                    ]),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 12, mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _dishes.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.push(context,
                          CupertinoPageRoute(builder: (_) => DishDetails(from_page: 3, dish_id: _dishes[i].dishID))),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Stack(children: [
                              Positioned.fill(child: DiosImage(url: _dishes[i].image, fit: BoxFit.cover)),
                              Positioned(bottom: 0, left: 0, right: 0,
                                child: Container(height: 30,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.3)],
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text('${_dishes[i].name ?? "Plat"}\n${_dishes[i].price?.toStringAsFixed(2) ?? "0"} €',
                                style: AppTypography.labelMedium()),
                          ),
                        ]),
                      ),
                    ),
                  ),
      ),
    );
  }
}
