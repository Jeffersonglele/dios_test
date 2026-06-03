import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'DishDetails.dart';
import '../widgets/dios_image.dart';
import '../utils/strings.dart';

class MealsOfACategory extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  const MealsOfACategory({super.key, this.categoryId, this.categoryName});

  @override
  State<MealsOfACategory> createState() => _MealsOfACategoryState();
}

class _MealsOfACategoryState extends State<MealsOfACategory> {
  List<Dish> _dishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    final allDishes = await Dish.fetchDishesFromDB();
    final filtered = allDishes.where((d) => (d.status ?? 0) == 1).toList();
    if (mounted) setState(() { _dishes = filtered; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.categoryName ?? Strings.get('Plats', 'Dishes'))),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _loadDishes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _dishes.isEmpty
                ? Center(child: Text(Strings.get('Aucun plat', 'No dish'), style: AppTypography.bodyMedium()))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: _dishes.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.push(context,
                          CupertinoPageRoute(builder: (_) => DishDetails(from_page: 4, dish_id: _dishes[i].dishID))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(children: [
                          SizedBox(width: 100, height: 100, child: DiosImage(url: _dishes[i].image)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_dishes[i].name ?? Strings.get('Plat', 'Dish'), style: AppTypography.titleMedium()),
                                const SizedBox(height: 4),
                                Text(_dishes[i].description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium()),
                                const SizedBox(height: 4),
                                Text('${_dishes[i].price?.toStringAsFixed(2) ?? "0"} €',
                                    style: AppTypography.bodyLarge(color: AppColors.brand)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
      ),
    );
  }
}
