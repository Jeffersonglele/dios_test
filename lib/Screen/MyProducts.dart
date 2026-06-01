import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dish/DishFormPage.dart';
import '../widgets/dios_image.dart';

class MyProducts extends StatefulWidget {
  const MyProducts({super.key});
  @override
  State<MyProducts> createState() => _MyProductsState();
}

class _MyProductsState extends State<MyProducts> {
  List<Dish> _dishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final allDishes = await Dish.fetchDishesFromDB();
    final myDishes = allDishes.where((d) => d.restauID == (session.restaurantId ?? 0)).toList();
    if (mounted) setState(() { _dishes = myDishes; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Mes plats')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _dishes.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.restaurant_menu_rounded, size: 56, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text('Aucun plat.', style: AppTypography.bodyMedium()),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context,
                            CupertinoPageRoute(builder: (_) => DishFormPage())).then((_) => _load()),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter un plat'),
                      ),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _dishes.length,
                    itemBuilder: (_, i) {
                      final d = _dishes[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.lg)),
                            child: SizedBox(width: 90, height: 90, child: DiosImage(url: d.image)),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.name ?? 'Plat', style: AppTypography.labelMedium()),
                                const SizedBox(height: 2),
                                Text('${d.price?.toStringAsFixed(2) ?? "0"} € · ${d.nb_servings ?? 0} portions',
                                    style: AppTypography.bodyMedium()),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (d.status ?? 0) == 1 ? AppColors.successLight : AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text((d.status ?? 0) == 1 ? 'Disponible' : 'Indisponible',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                          color: (d.status ?? 0) == 1 ? AppColors.success : AppColors.error)),
                                ),
                              ]),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context,
            CupertinoPageRoute(builder: (_) => DishFormPage())).then((_) => _load()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un plat'),
      ),
    );
  }
}
