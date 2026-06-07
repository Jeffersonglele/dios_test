import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Constant/Constant.dart';
import '../modeles/dish.dart';
import '../providers/cart_provider.dart';
import '../services/favorites_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/stars.dart';
import '../utils/toast.dart';
import '../widgets/dios_image.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/rating_tags_display.dart';
import 'dish/DishFormPage.dart';

class DishDetails extends ConsumerStatefulWidget {
  final int dish_id;
  final int from_page;

  const DishDetails({super.key, required this.dish_id, required this.from_page});

  @override
  ConsumerState<DishDetails> createState() => _DishDetailsState();
}

class _DishDetailsState extends ConsumerState<DishDetails> {
  String? country = "";
  int currentUser_restau = 0;
  int currentUser_role = 0;
  bool isLoading = true;
  bool isFavorite = false;
  bool isOwner = false;

  List<Dish> dishes = [];
  Dish? current_dish;
  int number_of_parts = 1;

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
      isOwner = currentUser_restau > 0 && dish.restauID == currentUser_restau;
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

  Future<void> _addToCart() async {
    final session = await SessionService.readSession();
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final dish = current_dish!;

    final result = await cartNotifier.addToCart(
      dish.dishID,
      dish.name ?? '',
      dish.price?.toDouble() ?? 0.0,
      dish.image ?? '',
      number_of_parts,
      dish.nb_servings ?? 99,
      country ?? 'France',
      session.userId,
      dish.restauID,
    );

    if (!mounted) return;

    switch (result) {
      case 'success':
        Toast(context, 'Ajouté au panier !', true);
        break;
      case 'different_restaurant':
        Toast(context, 'Vous ne pouvez pas commander de deux restaurants différents.', false);
        break;
      default:
        Toast(context, "Erreur lors de l'ajout au panier.", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (isLoading || current_dish == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currency = country == 'France' ? '€' : 'FCFA';
    final dish = current_dish!;
    final extraImages = dish.images
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final options = [
      if (dish.option1 != null && dish.option1!.isNotEmpty) dish.option1!,
      if (dish.option2 != null && dish.option2!.isNotEmpty) dish.option2!,
      if (dish.option3 != null && dish.option3!.isNotEmpty) dish.option3!,
    ];

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(
          slivers: [
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
                if (isOwner)
                  IconButton(
                    icon: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 20, color: AppColors.brand),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DishFormPage(dish: current_dish),
                        ),
                      );
                      if (result == true) loadData();
                    },
                  ),
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
                    DiosImage(url: dish.image, fit: BoxFit.cover),
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

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(dish.name ?? '', style: AppTypography.headlineMedium()),
                    ),
                    Text('${dish.price?.toStringAsFixed(2)} $currency',
                        style: AppTypography.headlineMedium(color: AppColors.brand)),
                  ]),
                  const SizedBox(height: 6),

                  if (dish.note > 0)
                    Row(children: [
                      StarRating(rating: dish.note),
                      const SizedBox(width: 6),
                      Text(dish.note.toStringAsFixed(1), style: AppTypography.bodyMedium(color: AppColors.inkSubtle)),
                      const SizedBox(width: 16),
                    ]),
                  CharacteristicsDisplay(targetType: 2, targetID: widget.dish_id),
                  const SizedBox(height: 6),

                  if ((dish.nb_orders ?? 0) > 20)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
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

                  if (dish.categories != null && dish.categories!.isNotEmpty) ...[
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: dish.categories!.split(',').map((c) {
                        final tag = c.trim();
                        return tag.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brandSurface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(tag, style: AppTypography.labelMedium(color: AppColors.brand).copyWith(fontSize: 11)),
                              )
                            : const SizedBox.shrink();
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(dish.description ?? '', style: AppTypography.bodyLarge()),
                  const SizedBox(height: 12),

                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.inkSubtle, size: 16),
                    const SizedBox(width: 6),
                    Text('${dish.nb_servings ?? 0} portions disponibles',
                        style: AppTypography.bodyMedium()),
                  ]),
                  const SizedBox(height: 24),

                  if (extraImages.isNotEmpty) ...[
                    Text('Photos', style: AppTypography.titleMedium()),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: extraImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: DiosImage(url: extraImages[i], height: 80, width: 80, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (!isOwner) ...[
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
                  ],

                  if (options.isNotEmpty) ...[
                    Text('Options', style: AppTypography.titleMedium()),
                    const SizedBox(height: 8),
                    ...options.map((opt) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppColors.brand),
                        const SizedBox(width: 8),
                        Text(opt, style: AppTypography.bodyMedium()),
                      ]),
                    )),
                    const SizedBox(height: 24),
                  ],

                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avis', style: AppTypography.titleMedium()),
                        const SizedBox(height: 8),
                        PaginatedComments(targetType: 2, targetID: widget.dish_id),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isOwner
            ? null
            : Container(
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
                      onPressed: _addToCart,
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
