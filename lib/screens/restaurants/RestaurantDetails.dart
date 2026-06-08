import 'dart:io';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;

import '../../constants/Constant.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../services/favorites_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dios_image.dart';
import '../../widgets/micro_interactions.dart';
import '../../utils/currency_util.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import '../../widgets/rating_tags_display.dart';
import '../DishDetails.dart';
import 'RestaurantFormPage.dart';

class RestaurantDetails extends ConsumerStatefulWidget {
  final int restaurant_id;
  const RestaurantDetails({super.key, required this.restaurant_id});

  @override
  ConsumerState<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends ConsumerState<RestaurantDetails> {
  final _formKey = GlobalKey<FormState>();
  int currentUser_restau = 0;
  int currentUser_role = 0;
  int currentUser_id = 0;
  String currentUser_country = "";
  bool restau_de_luser_connecte = false;
  bool isFavorite = false;
  bool isEditMode = false;

  late TextEditingController nameCtrl, descCtrl, nbOrdersCtrl, noteCtrl;
  late TextEditingController catCtrl, hoursCtrl, feeCtrl;

  List<String> _selectedHashtags = [];
  List<Dish> dishes = [];
  Restaurant? current_restaurant;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    descCtrl = TextEditingController();
    nbOrdersCtrl = TextEditingController();
    noteCtrl = TextEditingController();
    catCtrl = TextEditingController();
    hoursCtrl = TextEditingController();
    feeCtrl = TextEditingController();
    loadData();
  }

  @override
  void dispose() {
    nameCtrl.dispose(); descCtrl.dispose(); nbOrdersCtrl.dispose();
    noteCtrl.dispose(); catCtrl.dispose(); hoursCtrl.dispose(); feeCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final session = await SessionService.readSession();
      currentUser_role = session.role.id;
      currentUser_country = session.country;
      currentUser_id = session.userId;

      final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
      final restaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, widget.restaurant_id);
      final allDishes = await Dish.fetchDishesFromDB();
      final filtered = allDishes.where((d) => d.restauID == widget.restaurant_id).toList();

      if (!mounted) return;
      setState(() {
        currentUser_restau = session.restaurantId ?? 0;
        current_restaurant = restaurant;
        dishes = filtered;
        restau_de_luser_connecte = currentUser_restau == restaurant?.restaurantID;

        if (restaurant != null) {
          nameCtrl.text = restaurant.name ?? '';
          descCtrl.text = restaurant.description ?? '';
          nbOrdersCtrl.text = restaurant.nb_orders.toString();
          noteCtrl.text = restaurant.note.toString();
          catCtrl.text = restaurant.categories ?? '';
          hoursCtrl.text = restaurant.openingHours;
          feeCtrl.text = restaurant.deliveryFee.toStringAsFixed(2);
          _selectedHashtags = restaurant.categories?.split(', ') ?? [];
        }
      });

      if (restaurant != null) {
        final fav = await FavoritesService.isRestaurantFavorite(restaurant.restaurantID);
        if (!mounted) return;
        setState(() => isFavorite = fav);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (current_restaurant == null) return;
    final next = await FavoritesService.toggleRestaurantFavorite(current_restaurant!.restaurantID);
    if (mounted) setState(() => isFavorite = next);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
    if (current_restaurant == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isOwner = restau_de_luser_connecte;
    final canFavorite = !restau_de_luser_connecte && currentUser_role != 1 && currentUser_role != 4;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(
          slivers: [
            // ── Image parallaxe ──────────────────────────
            SliverAppBar(
              expandedHeight: 300,
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
                if (canFavorite)
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
                    DiosImage(
                      url: current_restaurant!.image,
                      fit: BoxFit.cover,
                    ),
                    // Overlay dégradé bas
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.ink.withValues(alpha: 0.6),
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
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                  ),
                ),
              ),
            ),
            // ── Contenu ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Nom + statut
                  Row(children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(current_restaurant!.name ?? '', style: AppTypography.headlineMedium()),
                          ),
                          if (current_restaurant!.isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('PRO',
                                  style: AppTypography.labelMedium(color: Colors.white)
                                      .copyWith(fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (current_restaurant!.isOpen == 1 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(current_restaurant!.isOpen == 1 ? l10n.open : l10n.closed,
                          style: TextStyle(
                            color: current_restaurant!.isOpen == 1 ? AppColors.success : AppColors.error,
                            fontSize: 12, fontWeight: FontWeight.w700,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Note
                  if (current_restaurant!.note > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        StarRating(rating: current_restaurant!.note),
                        const SizedBox(width: 6),
                        Text(current_restaurant!.note.toStringAsFixed(1), style: AppTypography.bodyMedium(color: AppColors.inkSubtle)),
                      ]),
                    ),
                  CharacteristicsDisplay(targetType: 1, targetID: widget.restaurant_id),

                  // Adresse
                  if ((current_restaurant!.location ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.location_on_rounded, size: 16, color: AppColors.inkSubtle),
                        const SizedBox(width: 6),
                        Expanded(child: Text(current_restaurant!.location!,
                            style: AppTypography.bodyMedium())),
                      ]),
                    ),

                  // Horaires + jours
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 16, color: AppColors.inkSubtle),
                    const SizedBox(width: 6),
                    Text(current_restaurant!.openingHours, style: AppTypography.bodyMedium()),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.inkSubtle),
                    const SizedBox(width: 4),
                    Flexible(child: Text(current_restaurant!.openingDays,
                        style: AppTypography.bodyMedium(), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),

                  // Mode de retrait
                  Row(children: [
                    Icon(_deliveryIcon(current_restaurant!.recoveryMode),
                        size: 16, color: AppColors.inkSubtle),
                    const SizedBox(width: 6),
                    Text(_deliveryLabel(current_restaurant!.recoveryMode),
                        style: AppTypography.bodyMedium()),
                  ]),
                  const SizedBox(height: 12),

                  // Description
                  Text(current_restaurant!.description ?? '', style: AppTypography.bodyLarge()),
                  const SizedBox(height: 16),

                  // Catégories
                  if ((current_restaurant!.categories ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Wrap(spacing: 8, runSpacing: 8, children:
                        current_restaurant!.categories!.split(',').map((h) {
                          final tag = h.trim();
                          return tag.isEmpty
                              ? const SizedBox.shrink()
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSurface,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Text(tag, style: AppTypography.labelMedium(color: AppColors.brand).copyWith(fontSize: 12)),
                                );
                        }).toList()),
                    ),

                  // ── MENU ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(children: [
                      Text(l10n.restaurant_details_menu, style: AppTypography.titleMedium()),
                      const SizedBox(width: 8),
                      Text(l10n.restaurant_details_dish_count(dishes.length), style: AppTypography.bodyMedium()),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  ...dishes.map((dish) => _buildDishItem(dish)),
                  const SizedBox(height: 24),

                  // ── Avis ──────────────────────────────
                  if (current_restaurant != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                        child: Text(l10n.restaurant_details_reviews, style: AppTypography.titleMedium()),
                    ),
                    const SizedBox(height: 12),
                    PaginatedComments(targetType: 1, targetID: widget.restaurant_id),
                  ],

                  // ── Bouton Modifier ──────────────────
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantFormPage(restaurant: current_restaurant),
                            ),
                          );
                          if (result == true) await loadData();
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(l10n.store_edit_restaurant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _deliveryIcon(String mode) {
    switch (mode) {
      case 'pickup': return Icons.takeout_dining_rounded;
      case 'both': return Icons.swap_horiz_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }

  String _deliveryLabel(String mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case 'pickup': return l10n.restaurant_details_mode_takeaway;
      case 'both': return l10n.restaurant_details_mode_delivery;
      default: return l10n.restaurant_details_mode_delivery_only;
    }
  }

  Widget _buildDishItem(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DishDetails(dish_id: dish.dishID, from_page: 1))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
          child: DiosImage(
            url: dish.image,
            width: 72, height: 72,
          ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dish.name ?? '', style: AppTypography.labelMedium()),
              const SizedBox(height: 4),
              Text(dish.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium()),
              const SizedBox(height: 4),
              Text('${dish.price?.toStringAsFixed(2)} ${CurrencyUtil.symbol(currentUser_country)}',
                  style: AppTypography.bodyLarge(color: AppColors.brand)),
            ]),
          ),
        ]),
      ),
    );
  }
}
