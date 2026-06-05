import 'package:dios_delices/Screen/dish/DishFormPage.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import '../widgets/dios_image.dart';
import '../utils/strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'micro_restau/DishDetailsMicroRestau.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  String? country = "";
  int currentUserRestau = 0;
  int currentUserRole = 0;
  List<Dish> dishes = [];
  List<Dish> filteredDishes = [];
  List<Dish> displayedDishes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final session = await SessionService.readSession();
      country = session.country;
      currentUserRestau = session.restaurantId ?? 0;
      currentUserRole = session.role.id;
      final dishesList = await Dish.fetchDishesFromDB();
      if (mounted) {
        setState(() {
          dishes = dishesList;
          filteredDishes = dishes.where((d) => d.restauID == currentUserRestau).toList();
          _filterDishes(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDishes(String query) {
    if (query.isEmpty) {
      displayedDishes = List.from(filteredDishes);
    } else {
      displayedDishes = filteredDishes
          .where((dish) =>
              (dish.name ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Strings.get('Votre menu', 'Your menu'), style: AppTypography.headlineLarge()),
                    Text('${displayedDishes.length} ${Strings.get('plats', 'dishes')}',
                        style: AppTypography.bodyMedium()),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => DishFormPage()))
                      .then((_) => loadData()),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(color: AppColors.brand.withValues(alpha: 0.3),
                            blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: displayedDishes.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.restaurant_menu_rounded, size: 56, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(Strings.get('Aucun plat dans votre menu.', 'No dishes in your menu.'),
                            style: AppTypography.bodyMedium()),
                        const SizedBox(height: 4),
                        Text(Strings.get('Ajoutez votre premier plat !', 'Add your first dish!'),
                            style: AppTypography.bodyMedium(color: AppColors.inkSubtle)),
                      ]),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 3 : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: displayedDishes.length,
                      itemBuilder: (context, i) {
                        final dish = displayedDishes[i];
                        final curr = country == 'France' ? '€' : 'FCFA';
                        return GestureDetector(
                          onTap: () => Navigator.push(context,
                              CupertinoPageRoute(builder: (_) =>
                                  DishDetailsMicroRestau(from_page: 2, dish_id: dish.dishID, dish_restau: currentUserRestau)))
                              .then((_) => loadData()),
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
                                  Positioned.fill(
                                  child: DiosImage(
                                    url: dish.image,
                                    fit: BoxFit.cover,
                                  ),
                                  ),
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.35)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(dish.name ?? '', style: AppTypography.labelMedium(),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('${dish.price?.toStringAsFixed(2)} $curr',
                                      style: AppTypography.bodyLarge(color: AppColors.brand)),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
