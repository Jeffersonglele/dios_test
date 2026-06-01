import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Constant/Constant.dart';
import '../modeles/dish.dart';
import '../services/favorites_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/micro_interactions.dart';

class DishDetails extends StatefulWidget {
  final int dish_id;
  final int from_page;

  const DishDetails({super.key, required this.dish_id, required this.from_page});

  @override
  State<DishDetails> createState() => _DishDetailsState();
}

class _DishDetailsState extends State<DishDetails> {
  String? country = "";
  int currentUser_restau = 0;
  int currentUser_role = 0;
  bool isLoading = true;
  bool isFavorite = false;

  List<Dish> dishes = [];
  Dish? current_dish;
  var number_of_parts = 1;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final session = await SessionService.readSession();
    country = session.country;
    currentUser_restau = session.restaurantId ?? 0;
    currentUser_role = session.role.id;

    final dishesList = await Dish.fetchDishesFromDB();
    final dish = Dish.getDishByDishId(dishesList, widget.dish_id);

    if (!mounted || dish == null) return;
    setState(() {
      dishes = dishesList;
      current_dish = dish;
      isLoading = false;
    });

    isFavorite = await FavoritesService.isDishFavorite(widget.dish_id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleFavorite() async {
    final next = await FavoritesService.toggleDishFavorite(widget.dish_id);
    if (!mounted) return;
    setState(() => isFavorite = next);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (isLoading || current_dish == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currency = country == 'France' ? '€' : 'FCFA';
    final dish = current_dish!;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(
          slivers: [
            // ── Photo immersive ─────────────────────────
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedLikeButton(
                    isLiked: isFavorite,
                    size: 22,
                    onTap: _toggleFavorite,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      (dish.image != null && dish.image!.isNotEmpty) ? dish.image! : '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset('assets/images/no_image.png', fit: BoxFit.cover),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.5)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                  ),
                ),
              ),
            ),

            // ── Contenu ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Nom + prix
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(dish.name ?? '', style: AppTypography.headlineMedium()),
                    ),
                    Text('${dish.price?.toStringAsFixed(2)} $currency',
                        style: AppTypography.headlineMedium(color: AppColors.brand)),
                  ]),
                  const SizedBox(height: 8),
                  // Badges
                  if ((dish.nb_orders ?? 0) > 20)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 4),
                        Text('Populaire', style: AppTypography.labelMedium(color: AppColors.accent).copyWith(fontSize: 11)),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  // Description
                  Text(dish.description ?? '', style: AppTypography.bodyLarge()),
                  const SizedBox(height: 8),
                  // Portions dispo
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.inkSubtle, size: 16),
                    const SizedBox(width: 6),
                    Text('${dish.nb_servings ?? 0} portions disponibles',
                        style: AppTypography.bodyMedium()),
                  ]),
                  const SizedBox(height: 24),

                  // ── Quantité ──────────────────────────
                  Text('Quantité', style: AppTypography.titleMedium()),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _QtyBtn(Icons.remove_rounded, () {
                        if (number_of_parts > 1) setState(() => number_of_parts--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('$number_of_parts', style: AppTypography.headlineMedium()),
                      ),
                      _QtyBtn(Icons.add_rounded, () {
                        if (number_of_parts < (dish.nb_servings ?? 99)) {
                          setState(() => number_of_parts++);
                        }
                      }),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Options (simulé) ──────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tune_rounded, color: AppColors.inkSubtle, size: 18),
                      const SizedBox(width: 8),
                      Text('Personnaliser', style: AppTypography.labelMedium()),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
                    ]),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
        // ── Bouton Ajouter au panier sticky ──────────
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Ajout au panier (logique à connecter au provider)
                },
                icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                label: Text('Ajouter au panier · ${(dish.price ?? 0) * number_of_parts} $currency'),
                style: ElevatedButton.styleFrom(
                  textStyle: AppTypography.labelLarge(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _QtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: AppColors.brand, size: 20),
      ),
    );
  }
}
