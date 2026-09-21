import 'package:dios_delices/screens/dish/dish_form_page.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import '../../utils/currency_util.dart';
import '../../widgets/dios_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../dish/dish_details.dart';

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
      await Dish.getAllDishesDetails();
      final dishesList = await Dish.fetchDishesFromDB();
      if (mounted) {
        setState(() {
          dishes = dishesList;
          filteredDishes =
              dishes.where((d) => d.restauID == currentUserRestau).toList();
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
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.menu,
                            style: AppTypography.headlineLarge(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))),
                        Text(
                            '${displayedDishes.length} ${AppLocalizations.of(context)!.servings}',
                            style: AppTypography.bodyMedium(
                                color: AppColors.resolve(AppColors.inkMuted,
                                    AppDarkColors.inkMuted))),
                      ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                          CupertinoPageRoute(builder: (_) => DishFormPage()))
                      .then((_) => loadData()),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.resolve(
                                    AppColors.brand, AppDarkColors.brand)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
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
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded,
                                size: 56,
                                color: AppColors.resolve(
                                    AppColors.border, AppDarkColors.border)),
                            const SizedBox(height: 12),
                            Text(l10n.menu_no_dishes,
                                style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(AppColors.inkMuted,
                                        AppDarkColors.inkMuted))),
                            const SizedBox(height: 4),
                            Text(l10n.menu_add_first_dish,
                                style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.inkSubtle,
                                        AppDarkColors.inkSubtle))),
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
                        final curr = CurrencyUtil.symbol(country ?? '');
                        return GestureDetector(
                          onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => DishDetails(
                                          from_page: 2, dish_id: dish.dishID)))
                              .then((_) => loadData()),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.resolve(
                                  AppColors.card, AppDarkColors.card),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(
                                  color: AppColors.resolve(
                                      AppColors.border, AppDarkColors.border),
                                  width: 0.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(children: [
                                      Positioned.fill(
                                        child: DiosImage(
                                          url: dish.image,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                AppColors.ink
                                                    .withValues(alpha: 0.35)
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(dish.name ?? '',
                                              style:
                                                  AppTypography.labelMedium(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(
                                              '${dish.price?.toStringAsFixed(2)} $curr',
                                              style: AppTypography.bodyLarge(
                                                  color: AppColors.resolve(
                                                      AppColors.brand,
                                                      AppDarkColors.brand))),
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
