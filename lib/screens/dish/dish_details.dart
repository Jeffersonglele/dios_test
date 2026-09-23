import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constant.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../services/delivery_availability_service.dart';
import '../../services/favorites_service.dart';
import '../../services/restaurant_opening_hours_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import '../../widgets/dios_image.dart';
import '../../widgets/micro_interactions.dart';
import '../../widgets/delivery_unavailable.dart';
import '../../widgets/cart_conflict.dart';
import '../../widgets/rating_tags_display.dart';
import 'dish_form_page.dart';

class DishDetails extends ConsumerStatefulWidget {
  final int dish_id;
  final int from_page;

  const DishDetails(
      {super.key, required this.dish_id, required this.from_page});

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
  DeliveryAvailability? _deliveryAvailability;
  RestaurantOpeningStatus? _openingStatus;
  String _restaurantName = '';

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

    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final restaurant = Restaurant.getRestaurantByRestaurantId(
      restaurants,
      dish.restauID,
    );
    if (restaurant != null) {
      if (mounted) {
        setState(() => _restaurantName = restaurant.name);
      }
      final availability =
          await DeliveryAvailabilityService.forRestaurant(restaurant);
      if (mounted) {
        setState(() {
          _deliveryAvailability = availability;
          _openingStatus = restaurant.openingStatus;
        });
      }
    }
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

    if (cartNotifier.hasOtherRestaurant(dish.restauID)) {
      final choice = await showCartConflictSheet(
        context,
        restaurantName: _restaurantName,
      );
      if (!mounted || choice == CartConflictChoice.cancel) return;
      if (choice == CartConflictChoice.replace) {
        await cartNotifier.clearCart();
      }
    }

    final result = await cartNotifier.addToCart(
      dish.dishID,
      dish.name ?? '',
      dish.price?.toDouble() ?? 0.0,
      dish.image ?? '',
      number_of_parts,
      dish.nb_servings ?? 99,
      country ?? 'RDC',
      session.userId,
      dish.restauID,
    );

    if (!mounted) return;

    switch (result) {
      case 'success':
        Toast(context, AppLocalizations.of(context)!.dish_added_to_cart, true);
        break;
      case 'out_of_delivery_zone':
        await showDeliveryUnavailableSheet(context);
        break;
      case 'delivery_address_required':
        await showDeliveryUnavailableSheet(context);
        break;
      case 'restaurant_closed':
        await showRestaurantClosedSheet(context);
        break;
      default:
        Toast(context, AppLocalizations.of(context)!.dish_add_error, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    if (isLoading || current_dish == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currency = CurrencyUtil.symbol(country ?? '');
    final dish = current_dish!;
    final deliveryBlocked = !isOwner &&
        _deliveryAvailability != null &&
        !_deliveryAvailability!.canOrder;
    final restaurantClosed =
        !isOwner && _openingStatus != null && !_openingStatus!.isOpen;
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
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              backgroundColor:
                  AppColors.resolve(AppColors.surface, AppDarkColors.surface),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.card, AppDarkColors.card)
                        .withValues(alpha: 0.9),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                                AppColors.card, AppDarkColors.card)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(Icons.edit_rounded,
                          size: 20,
                          color: AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand)),
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
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.resolve(
                                      AppColors.ink, AppDarkColors.ink)
                                  .withValues(alpha: 0.5)
                            ],
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
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                        AppColors.surface, AppDarkColors.surface),
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(dish.name ?? '',
                                  style: AppTypography.headlineMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink))),
                            ),
                            Text('${dish.price?.toStringAsFixed(2)} $currency',
                                style: AppTypography.headlineMedium(
                                    color: AppColors.resolve(
                                        AppColors.brand, AppDarkColors.brand))),
                          ]),
                      const SizedBox(height: 6),
                      if (dish.note > 0)
                        Row(children: [
                          StarRating(rating: dish.note),
                          const SizedBox(width: 6),
                          Text(dish.note.toStringAsFixed(1),
                              style: AppTypography.bodyMedium(
                                  color: AppColors.resolve(AppColors.inkSubtle,
                                      AppDarkColors.inkSubtle))),
                          const SizedBox(width: 16),
                        ]),
                      CharacteristicsDisplay(
                          targetType: 2, targetID: widget.dish_id),
                      const SizedBox(height: 6),
                      if ((dish.nb_orders ?? 0) > 20)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: AppColors.accent, size: 14),
                            const SizedBox(width: 4),
                            Text(l10n.dish_popular,
                                style: AppTypography.labelMedium(
                                        color: AppColors.resolve(
                                            AppColors.accent,
                                            AppDarkColors.accent))
                                    .copyWith(fontSize: 11)),
                          ]),
                        ),
                      if (dish.categories != null &&
                          dish.categories!.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: dish.categories!.split(',').map((c) {
                            final tag = c.trim();
                            return tag.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.resolve(
                                          AppColors.brandSurface,
                                          AppDarkColors.brandSurface),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(tag,
                                        style: AppTypography.labelMedium(
                                                color: AppColors.brand)
                                            .copyWith(fontSize: 11)),
                                  )
                                : const SizedBox.shrink();
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(dish.description ?? '',
                          style: AppTypography.bodyLarge(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink))),
                      const SizedBox(height: 12),
                      if (deliveryBlocked) ...[
                        DeliveryUnavailableBanner(
                          onTap: () => showDeliveryUnavailableSheet(context),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (restaurantClosed) ...[
                        RestaurantClosedBanner(
                          status: _openingStatus!,
                          onTap: () => showRestaurantClosedSheet(context),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(children: [
                        Icon(Icons.inventory_2_outlined,
                            color: AppColors.resolve(
                                AppColors.inkSubtle, AppDarkColors.inkSubtle),
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                            l10n.dish_servings_available(
                                '${dish.nb_servings ?? 0}'),
                            style: AppTypography.bodyMedium(
                                color: AppColors.resolve(AppColors.inkMuted,
                                    AppDarkColors.inkMuted))),
                      ]),
                      const SizedBox(height: 24),
                      if (extraImages.isNotEmpty) ...[
                        Text(l10n.dish_photos,
                            style: AppTypography.titleMedium(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: extraImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: DiosImage(
                                  url: extraImages[i],
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!isOwner) ...[
                        Text(l10n.dish_quantity,
                            style: AppTypography.titleMedium(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.resolve(AppColors.surfaceWarm,
                                AppDarkColors.surfaceWarm),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _QtyBtn(Icons.remove_rounded, () {
                              if (number_of_parts > 1)
                                setState(() => number_of_parts--);
                            }),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text('$number_of_parts',
                                  style: AppTypography.headlineMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink))),
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
                        Text(l10n.dish_options,
                            style: AppTypography.titleMedium(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))),
                        const SizedBox(height: 8),
                        ...options.map((opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 16, color: AppColors.brand),
                                const SizedBox(width: 8),
                                Text(opt,
                                    style: AppTypography.bodyMedium(
                                        color: AppColors.resolve(
                                            AppColors.inkMuted,
                                            AppDarkColors.inkMuted))),
                              ]),
                            )),
                        const SizedBox(height: 24),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.dish_reviews,
                                style: AppTypography.titleMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))),
                            const SizedBox(height: 8),
                            PaginatedComments(
                                targetType: 2, targetID: widget.dish_id),
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
                  color: AppColors.resolve(
                      AppColors.surface, AppDarkColors.surface),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)
                          .withValues(alpha: 0.04),
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
                      label: Text(
                        deliveryBlocked
                            ? l10n.delivery_unavailable_short
                            : restaurantClosed
                                ? l10n.restaurant_closed_short
                                : l10n.dish_add_to_cart(
                                    '${(dish.price ?? 0) * number_of_parts} $currency'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deliveryBlocked || restaurantClosed
                            ? AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted)
                            : AppColors.resolve(
                                AppColors.brand, AppDarkColors.brand),
                        textStyle: AppTypography.labelLarge(
                            color: AppColors.resolve(
                                AppColors.card, AppDarkColors.card)),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon,
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            size: 20),
      ),
    );
  }
}
