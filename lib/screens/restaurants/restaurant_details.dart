import 'dart:io';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;

import '../../constants/constant.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../services/favorites_service.dart';
import '../../services/delivery_availability_service.dart';
import '../../services/session_service.dart';
import '../../services/node_catalog_service.dart';
import '../../services/currency_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dios_image.dart';
import '../../widgets/micro_interactions.dart';
import '../../utils/currency_util.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import '../../widgets/rating_tags_display.dart';
import '../../widgets/delivery_unavailable.dart';
import '../../widgets/cart_conflict.dart';
import '../../providers/cart_provider.dart';
import '../dish/dish_details.dart';
import 'restaurant_form_page.dart';

class RestaurantDetails extends ConsumerStatefulWidget {
  final int restaurant_id;
  const RestaurantDetails({super.key, required this.restaurant_id});

  @override
  ConsumerState<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends ConsumerState<RestaurantDetails>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  int currentUser_restau = 0;
  int currentUser_role = 0;
  int currentUser_id = 0;
  String currentUser_country = "";
  bool restau_de_luser_connecte = false;
  bool isFavorite = false;
  bool isEditMode = false;

  late TabController _tabController;
  int _selectedTabIndex = 0;

  late TextEditingController nameCtrl,
      descCtrl,
      nbOrdersCtrl,
      noteCtrl,
      catCtrl,
      hoursCtrl,
      feeCtrl;

  List<String> _selectedHashtags = [];
  List<Dish> dishes = [];
  Restaurant? current_restaurant;
  DeliveryAvailability? _deliveryAvailability;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _selectedTabIndex = _tabController.index);
      });
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
    _tabController.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();
    nbOrdersCtrl.dispose();
    noteCtrl.dispose();
    catCtrl.dispose();
    hoursCtrl.dispose();
    feeCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    _hasError = false;
    _errorMessage = null;
    try {
      final session = await SessionService.readSession();
      currentUser_role = session.role.id;
      currentUser_country = session.country;
      currentUser_id = session.userId;

      Restaurant? restaurant;
      List<Dish> filtered;
      final nodeToken = await SessionService.readNodeToken();
      if (nodeToken != null) {
        final menu = await NodeCatalogService.loadRestaurantMenu(
          restaurantId: widget.restaurant_id,
          token: nodeToken,
        );
        restaurant = menu.restaurant;
        filtered = menu.dishes;
      } else {
        final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
        restaurant = Restaurant.getRestaurantByRestaurantId(
            restaurantsList, widget.restaurant_id);
        final allDishes = await Dish.fetchDishesFromDB();
        filtered =
            allDishes.where((d) => d.restauID == widget.restaurant_id).toList();
      }

      if (!mounted) return;
      setState(() {
        currentUser_restau = session.restaurantId ?? 0;
        current_restaurant = restaurant;
        dishes = filtered;
        restau_de_luser_connecte =
            currentUser_restau == restaurant?.restaurantID;

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
        final fav = await FavoritesService.isRestaurantFavorite(
            restaurant.restaurantID);
        if (!mounted) return;
        setState(() => isFavorite = fav);

        final availability =
            await DeliveryAvailabilityService.forRestaurant(restaurant);
        if (mounted) setState(() => _deliveryAvailability = availability);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (current_restaurant == null) return;
    final next = await FavoritesService.toggleRestaurantFavorite(
        current_restaurant!.restaurantID);
    if (mounted) setState(() => isFavorite = next);
  }

  Future<bool> _handleWillPop() async {
    final restaurant = current_restaurant;
    if (restaurant == null || restau_de_luser_connecte) return true;

    final cartNotifier = ref.read(cartStateProvider.notifier);
    if (!cartNotifier.restaurantIds.contains(restaurant.restaurantID)) {
      return true;
    }

    final choice = await showCartConflictSheet(
      context,
      restaurantName: restaurant.name,
    );
    if (!mounted || choice == CartConflictChoice.cancel) return false;
    if (choice == CartConflictChoice.replace) {
      await cartNotifier.clearCart();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_hasError || current_restaurant == null) {
      final surface =
          AppColors.resolve(AppColors.surface, AppDarkColors.surface);
      final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
      final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
      final inkMuted =
          AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
      return Scaffold(
        backgroundColor: surface,
        appBar: AppBar(backgroundColor: surface),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text("Impossible de charger le restaurant",
                          style: TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          _errorMessage?.isNotEmpty == true
                              ? _errorMessage!
                              : "Veuillez réessayer plus tard.",
                          style: TextStyle(color: inkMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 200,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text("Réessayer"),
                        ),
                      ),
                    ],
                  )
                : CircularProgressIndicator(color: brand),
          ),
        ),
      );
    }

    final isOwner = restau_de_luser_connecte;
    final openingStatus = current_restaurant!.openingStatus;
    final restaurantClosed = !openingStatus.isOpen;
    final canFavorite = !restau_de_luser_connecte &&
        currentUser_role != 1 &&
        currentUser_role != 4;
    final deliveryBlocked = !isOwner &&
        _deliveryAvailability != null &&
        !_deliveryAvailability!.canOrder;
    final openingMessage = openingStatus.isClosedManually
        ? l10n.restaurant_closed_manually
        : openingStatus.opensLaterToday
            ? l10n.restaurant_opens_at(openingStatus.opensAt!)
            : openingStatus.opensOn != null
                ? l10n.restaurant_opens_on(
                    openingStatus.opensOn!, openingStatus.opensAt ?? '')
                : l10n.restaurant_closed_today;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: WillPopScope(
        onWillPop: _handleWillPop,
        child: Scaffold(
          backgroundColor:
              AppColors.resolve(AppColors.surface, AppDarkColors.surface),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ════════════════════════════════════════════
              // HERO IMAGE — SliverAppBar (sans nom dans l'image)
              // ════════════════════════════════════════════
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                elevation: 0,
                backgroundColor:
                    AppColors.resolve(AppColors.surface, AppDarkColors.surface),
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () async {
                      if (await _handleWillPop() && mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: Color(0xFF2B211D)),
                    ),
                  ),
                ),
                actions: [
                  // Badge note flottant
                  if (current_restaurant!.note > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppColors.resolve(
                                    AppColors.accent, AppDarkColors.accent),
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                current_restaurant!.note.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2B211D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Bouton favori
                  if (canFavorite)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: AnimatedLikeButton(
                              isLiked: isFavorite,
                              size: 20,
                              onTap: _toggleFavorite,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Image principale ──────────────────
                      Opacity(
                        opacity: deliveryBlocked
                            ? 0.55
                            : (restaurantClosed ? 0.8 : 1.0),
                        child: ColorFiltered(
                          colorFilter: deliveryBlocked
                              ? const ColorFilter.matrix([
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ])
                              : const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply),
                          child: DiosImage(
                            url: current_restaurant!.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // ── Dégradé bas léger ─────────────────
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.25),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Overlay hors zone ─────────────────
                      if (deliveryBlocked)
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                            child: const Text(
                              'Marchand hors de votre zone de livraison',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),

                      // ── Overlay fermé ─────────────────────
                      if (!deliveryBlocked && restaurantClosed)
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.black.withValues(alpha: 0.34),
                            child: Text(
                              openingMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Arrondi de transition image → contenu ──
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(0),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.resolve(
                          AppColors.surface, AppDarkColors.surface),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                  ),
                ),
              ),

              // ════════════════════════════════════════════
              // INFOS RESTAURANT
              // Nom ici, bien intégré dans la section info
              // ════════════════════════════════════════════
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.resolve(
                      AppColors.surface, AppDarkColors.surface),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Nom + badge PRO + statut ──────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    current_restaurant!.name ?? '',
                                    style: AppTypography.headlineMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink),
                                    ).copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                      height: 1.15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (current_restaurant!.isPro) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.resolve(AppColors.accent,
                                          AppDarkColors.accent),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2B211D),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ── Pill statut ouvert/fermé ──────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: (openingStatus.isOpen
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: openingStatus.isOpen
                                        ? AppColors.success
                                        : AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  openingStatus.isOpen
                                      ? l10n.open
                                      : l10n.closed,
                                  style: TextStyle(
                                    color: openingStatus.isOpen
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── Note étoiles ──────────────────────
                      if (current_restaurant!.note > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              StarRating(rating: current_restaurant!.note),
                              const SizedBox(width: 6),
                              Text(
                                current_restaurant!.note.toStringAsFixed(1),
                                style: AppTypography.bodyMedium(
                                  color: AppColors.resolve(AppColors.inkSubtle,
                                      AppDarkColors.inkSubtle),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Chips d'infos rapides ─────────────
                      _InfoChipsRow(
                        restaurant: current_restaurant!,
                        openingStatus: openingStatus,
                        deliveryBlocked: deliveryBlocked,
                        l10n: l10n,
                      ),

                      const SizedBox(height: 12),

                      // ── Mode de récupération ──────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                              AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _deliveryIcon(current_restaurant!.recoveryMode),
                              size: 13,
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _deliveryLabel(current_restaurant!.recoveryMode),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.resolve(
                                    AppColors.inkMuted, AppDarkColors.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      CharacteristicsDisplay(
                          targetType: 1, targetID: widget.restaurant_id),

                      // ── Bannières d'alerte ────────────────
                      if (deliveryBlocked) ...[
                        const SizedBox(height: 12),
                        DeliveryUnavailableBanner(
                          onTap: () => showDeliveryUnavailableSheet(context),
                        ),
                      ],
                      if (!isOwner && restaurantClosed) ...[
                        const SizedBox(height: 12),
                        RestaurantClosedBanner(
                          status: openingStatus,
                          onTap: () => showRestaurantClosedSheet(context),
                        ),
                      ],

                      // ── Description ───────────────────────
                      if ((current_restaurant!.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 4),
                          child: Text(
                            current_restaurant!.description ?? '',
                            style: AppTypography.bodyMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                            ),
                          ),
                        ),

                      // ── Catégories tags ───────────────────
                      if ((current_restaurant!.categories ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: current_restaurant!.categories!
                                .split(',')
                                .map((h) {
                              final tag = h.trim();
                              return tag.isEmpty
                                  ? const SizedBox.shrink()
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.resolve(
                                            AppColors.brandSurface,
                                            AppDarkColors.brandSurface),
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.lg),
                                      ),
                                      child: Text(
                                        tag,
                                        style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.brand,
                                              AppDarkColors.brand),
                                        ).copyWith(fontSize: 12),
                                      ),
                                    );
                            }).toList(),
                          ),
                        ),

                      // ── Avis ──────────────────────────────
                      const SizedBox(height: 22),
                      _SectionTitle(
                        icon: Icons.reviews_rounded,
                        label: l10n.restaurant_details_reviews,
                      ),
                      const SizedBox(height: 10),
                      PaginatedComments(
                          targetType: 1, targetID: widget.restaurant_id),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ════════════════════════════════════════════
              // MENU — Header sticky
              // ════════════════════════════════════════════
              SliverPersistentHeader(
                pinned: true,
                delegate: _MenuStickyHeader(
                  tabController: _tabController,
                  dishCount: dishes.length,
                  l10n: l10n,
                ),
              ),

              // ════════════════════════════════════════════
              // LISTE DES PLATS
              // ════════════════════════════════════════════
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dish = dishes[index];
                      return _buildDishItem(
                          dish, deliveryBlocked, isOwner, l10n);
                    },
                    childCount: dishes.length,
                  ),
                ),
              ),

              // ── Bouton modifier (owner) ──────────────────
              if (isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantFormPage(
                                  restaurant: current_restaurant),
                            ),
                          );
                          if (result == true) await loadData();
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(l10n.store_edit_restaurant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _deliveryIcon(String mode) {
    switch (mode) {
      case 'pickup':
        return Icons.takeout_dining_rounded;
      case 'both':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  String _deliveryLabel(String mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case 'pickup':
        return l10n.restaurant_details_mode_takeaway;
      case 'both':
        return l10n.restaurant_details_mode_delivery;
      default:
        return l10n.restaurant_details_mode_delivery_only;
    }
  }

  Widget _buildDishItem(
    Dish dish,
    bool deliveryBlocked,
    bool isOwner,
    AppLocalizations l10n,
  ) {
    final blocked = !isOwner && deliveryBlocked;

    return IgnorePointer(
      ignoring: blocked,
      child: Opacity(
        opacity: blocked ? 0.62 : 1.0,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DishDetails(dish_id: dish.dishID, from_page: 1),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                    .withValues(alpha: 0.6),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Image avec ombre portée ───────────────
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColorFiltered(
                            colorFilter: blocked
                                ? const ColorFilter.matrix([
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0.2126,
                                    0.7152,
                                    0.0722,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    1,
                                    0,
                                  ])
                                : const ColorFilter.mode(
                                    Colors.transparent, BlendMode.multiply),
                            child: DiosImage(
                              url: dish.image,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Badge note du plat
                      if (dish.note != null && dish.note! > 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 9),
                                const SizedBox(width: 2),
                                Text(
                                  dish.note!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Infos texte ───────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom du plat
                        Text(
                          dish.name ?? '',
                          style: AppTypography.titleMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink),
                          ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Description
                        Text(
                          dish.description ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                    AppColors.inkMuted, AppDarkColors.inkMuted)
                                .withValues(alpha: 0.7),
                          ).copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        // Prix + chevron
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '${dish.price?.toStringAsFixed(2)} ${CurrencyUtil.symbol(CurrencyUtil.code(currentUser_country))}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.resolve(
                                      AppColors.brand, AppDarkColors.brand),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ── Chevron > ou badge indisponible ──
                            if (!blocked)
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.resolve(
                                          AppColors.brand, AppDarkColors.brand)
                                      .withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: AppColors.resolve(
                                      AppColors.brand, AppDarkColors.brand),
                                ),
                              )
                            else
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.96),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_off_rounded,
                                        size: 11,
                                        color: AppColors.resolve(
                                            AppColors.error,
                                            AppDarkColors.error),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          l10n.delivery_unavailable_short,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.resolve(
                                                    AppColors.ink,
                                                    AppDarkColors.ink)
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _InfoChipsRow
// ═══════════════════════════════════════════════════════════
class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({
    required this.restaurant,
    required this.openingStatus,
    required this.deliveryBlocked,
    required this.l10n,
  });

  final Restaurant restaurant;
  final dynamic openingStatus;
  final bool deliveryBlocked;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final chipBg =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final chipText =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if ((restaurant.location ?? '').isNotEmpty)
          _InfoChip(
            icon: Icons.location_on_rounded,
            label: restaurant.location!,
            bg: chipBg,
            color: chipText,
          ),
        if (restaurant.openingHours.isNotEmpty)
          _InfoChip(
            icon: Icons.access_time_rounded,
            label: restaurant.openingHours,
            bg: chipBg,
            color: chipText,
          ),
        AnimatedBuilder(
          animation: CurrencyService.instance,
          builder: (_, __) {
            final isFree = false;
            // Afficher le tarif par défaut du pays si le restaurant n'a pas de tarif
            final deliveryFee = restaurant.deliveryFee > 0 
                ? restaurant.deliveryFee 
                : (restaurant.country?.toLowerCase().contains('bénin') == true || 
                   restaurant.country?.toLowerCase().contains('benin') == true ? 500.0 : 2000.0);
            final label = CurrencyUtil.formatConvertedPrice(deliveryFee);
            final bg = isFree
                ? success.withValues(alpha: 0.10)
                : chipBg;
            final col = isFree ? success : chipText;
            return _InfoChip(
              icon: Icons.delivery_dining_rounded,
              label: label,
              bg: bg,
              color: col,
            );
          },
        ),
        if (restaurant.openingDays.isNotEmpty)
          _InfoChip(
            icon: Icons.calendar_today_rounded,
            label: restaurant.openingDays,
            bg: chipBg,
            color: chipText,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _SectionTitle
// ═══════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: brand),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.titleMedium(color: ink)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _MenuStickyHeader
// ═══════════════════════════════════════════════════════════
class _MenuStickyHeader extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final int dishCount;
  final AppLocalizations l10n;

  const _MenuStickyHeader({
    required this.tabController,
    required this.dishCount,
    required this.l10n,
  });

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final surfaceWarm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    // Ombre subtile quand le header est collé
    final shadow = overlapsContent
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
        : <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(color: surface, boxShadow: shadow),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      alignment: Alignment.bottomLeft,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.restaurant_menu_rounded, size: 16, color: brand),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.restaurant_details_menu,
            style: AppTypography.titleMedium(color: ink)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: surfaceWarm,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$dishCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_MenuStickyHeader old) => old.dishCount != dishCount;
}
