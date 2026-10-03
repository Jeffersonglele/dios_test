import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../providers/cart_provider.dart';
import '../../services/delivery_availability_service.dart';
import '../../services/favorites_service.dart';
import '../../services/restaurant_opening_hours_service.dart';
import '../../services/session_service.dart';
import '../../services/currency_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import '../../widgets/dios_image.dart';
import '../../widgets/micro_interactions.dart';
import '../../widgets/delivery_unavailable.dart';
import '../../widgets/cart_conflict.dart';
import '../../widgets/rating_tags_display.dart';
import '../../widgets/swirling_loader.dart';
import 'dish_form_page.dart';

/// 1500.0 -> "1500", 2.5 -> "2.50"
String _fmt(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

class DishDetails extends ConsumerStatefulWidget {
  final int dish_id;
  final int from_page;

  const DishDetails({super.key, required this.dish_id, required this.from_page});

  @override
  ConsumerState<DishDetails> createState() => _DishDetailsState();
}

class _DishDetailsState extends ConsumerState<DishDetails> {
  /// Durée minimale d'affichage du loader : évite un clignotement
  /// quand l'ajout au panier est quasi instantané.
  static const Duration _minLoaderDuration = Duration(milliseconds: 700);

  String? country = "";
  int currentUser_restau = 0;
  int currentUser_role = 0;

  bool isLoading = true;
  bool _notFound = false;
  bool _checksDone = false; // dispo livraison + horaires + restaurant chargés
  bool isFavorite = false;
  bool isOwner = false;

  /// true pendant l'ajout au panier : un overlay Swirling bloque toute la page.
  bool _isAdding = false;

  DeliveryAvailability? _deliveryAvailability;
  RestaurantOpeningStatus? _openingStatus;
  String _restaurantName = '';

  List<Dish> dishes = [];
  Dish? current_dish;
  int number_of_parts = 1;
  int _galleryIndex = 0;
  final PageController _pageController = PageController();

  // Sélection des options (index de l'option -> index du choix sélectionné)
  final Map<int, int> _selectedChoiceIndices = {};

  // ── Palette (raccourcis) ───────────────────────────────────
  Color get _surface => AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  Color get _card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  Color get _ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  Color get _inkMuted => AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  Color get _inkSubtle => AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  Color get _brand => AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  Color get _brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  Color get _surfaceWarm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  Color get _accent => AppColors.resolve(AppColors.accent, AppDarkColors.accent);
  Color get _border => AppColors.resolve(AppColors.border, AppDarkColors.border);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Données ────────────────────────────────────────────────

  void _retry() {
    setState(() {
      isLoading = true;
      _notFound = false;
      _checksDone = false;
    });
    loadData();
  }

  Future<void> loadData() async {
    Dish? dish;
    try {
      final session = await SessionService.readSession();
      country = session.country;
      currentUser_restau = session.restaurantId ?? 0;
      currentUser_role = session.role.id;

      final dishesList = await Dish.fetchDishesFromDB();
      dish = Dish.getDishByDishId(dishesList, widget.dish_id);

      if (!mounted) return;
      if (dish == null) {
        setState(() {
          isLoading = false;
          _notFound = true;
        });
        return;
      }
      final loaded = dish;
      setState(() {
        dishes = dishesList;
        current_dish = loaded;
        isLoading = false;
        isOwner = currentUser_restau > 0 && loaded.restauID == currentUser_restau;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _notFound = true;
        });
      }
      return;
    }

    // Infos secondaires : le contenu est déjà affiché, on complète ensuite
    try {
      isFavorite = await FavoritesService.isDishFavorite(widget.dish_id);
      if (!mounted) return;
      setState(() {});

      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final restaurant =
          Restaurant.getRestaurantByRestaurantId(restaurants, dish.restauID);
      if (restaurant != null) {
        if (mounted) setState(() => _restaurantName = restaurant.name);
        final availability =
            await DeliveryAvailabilityService.forRestaurant(restaurant);
        if (mounted) {
          setState(() {
            _deliveryAvailability = availability;
            _openingStatus = restaurant.openingStatus;
          });
        }
      }
    } catch (_) {
      // On ne bloque pas la page si ces infos échouent
    } finally {
      if (mounted) setState(() => _checksDone = true);
    }
  }

  Future<void> _toggleFavorite() async {
    final next = await FavoritesService.toggleDishFavorite(widget.dish_id);
    if (!mounted) return;
    setState(() => isFavorite = next);
  }

  // ── Options ────────────────────────────────────────────────

  /// Options brutes non vides du plat (même ordre que les options parsées).
  List<String> _rawOptionsOf(Dish dish) => <String>[
        if (dish.option1 != null && dish.option1!.isNotEmpty) dish.option1!,
        if (dish.option2 != null && dish.option2!.isNotEmpty) dish.option2!,
        if (dish.option3 != null && dish.option3!.isNotEmpty) dish.option3!,
      ];

  List<_ParsedOption> _optionsOf(Dish dish) =>
      _rawOptionsOf(dish).map(_parseOption).toList();

  /// "+500 FCFA" -> 500.0
  double _extraAmount(String? extra) {
    if (extra == null) return 0.0;
    final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(extra);
    if (m == null) return 0.0;
    return double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0;
  }

  /// Supplément total des choix actuellement sélectionnés (par portion).
  double _selectedOptionsPrice(List<_ParsedOption> options) {
    var sum = 0.0;
    for (var i = 0; i < options.length; i++) {
      final idx = _selectedChoiceIndices[i];
      if (idx == null || idx >= options[i].choices.length) continue;
      sum += _extraAmount(options[i].choices[idx].extra);
    }
    return sum;
  }

  // ── Panier ─────────────────────────────────────────────────

  Future<void> _addToCart() async {
    if (_isAdding) return;

    final blocked = !isOwner &&
        _deliveryAvailability != null &&
        !_deliveryAvailability!.canOrder;
    final closed = !isOwner && _openingStatus != null && !_openingStatus!.isOpen;
    if (blocked) {
      await showDeliveryUnavailableSheet(context);
      return;
    }
    if (closed) {
      await showRestaurantClosedSheet(context);
      return;
    }

    HapticFeedback.lightImpact();

    final session = await SessionService.readSession();
    if (!mounted) return;
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final dish = current_dish!;

    // Conflit de restaurant : la feuille s'affiche AVANT le loader
    var replaceCart = false;
    if (cartNotifier.hasOtherRestaurant(dish.restauID)) {
      final choice = await showCartConflictSheet(
        context,
        restaurantName: _restaurantName,
      );
      if (!mounted || choice == CartConflictChoice.cancel) return;
      replaceCart = choice == CartConflictChoice.replace;
    }

    // Construire les choix sélectionnés
    final rawList = _rawOptionsOf(dish);
    final dishOptions = rawList.map(_parseOption).toList();
    final selectedChoices = <int, String>{};
    final rawOptions = <String?>[];

    for (int i = 0; i < dishOptions.length; i++) {
      final opt = dishOptions[i];
      final selectedIdx = _selectedChoiceIndices[i];
      if (selectedIdx != null && selectedIdx < opt.choices.length) {
        selectedChoices[i] = opt.choices[selectedIdx].label;
        rawOptions.add(rawList[i]);
      }
    }
    final optionPrice = _selectedOptionsPrice(dishOptions);

    // ── Loader bloquant ──
    setState(() => _isAdding = true);

    String? result = 'error';
    try {
      final minDelay = Future<void>.delayed(_minLoaderDuration);

      if (replaceCart) {
        await cartNotifier.clearCart();
      }

      result = await cartNotifier.addToCart(
        dish.dishID,
        dish.name ?? '',
        dish.price?.toDouble() ?? 0.0,
        dish.image ?? '',
        number_of_parts,
        dish.nb_servings ?? 99,
        country ?? 'RDC',
        session.userId,
        dish.restauID,
        selectedChoices: selectedChoices,
        optionPrice: optionPrice,
        rawOptions: rawOptions,
      );

      await minDelay;
    } catch (e) {
      debugPrint('Add to cart error: $e');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }

    if (!mounted) return;

    switch (result) {
      case 'success':
        HapticFeedback.mediumImpact();
        Toast(context, AppLocalizations.of(context)!.dish_added_to_cart, true);
        break;
      case 'out_of_delivery_zone':
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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) return const _DishDetailsSkeleton();
    if (_notFound || current_dish == null) {
      return _DishNotFound(onRetry: _retry, brand: _brand, ink: _ink, surface: _surface);
    }

    final currency = CurrencyUtil.symbol(CurrencyUtil.code(country ?? ''));
    final dish = current_dish!;

    final deliveryBlocked =
        !isOwner && _deliveryAvailability != null && !_deliveryAvailability!.canOrder;
    final restaurantClosed =
        !isOwner && _openingStatus != null && !_openingStatus!.isOpen;

    final extraImages = dish.images
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final mainImage = (dish.image ?? '').trim();
    final gallery = <String>[if (mainImage.isNotEmpty) mainImage, ...extraImages];

    final options = _optionsOf(dish);

    final categories = (dish.categories ?? '')
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    final servings = dish.nb_servings ?? 0;
    final lowStock = servings > 0 && servings <= 5;
    final hasRating = dish.note > 0;
    final isPopular = (dish.nb_orders ?? 0) > 20;

    final unitPrice = (dish.price ?? 0) + _selectedOptionsPrice(options);
    final total = unitPrice * number_of_parts;

    return PopScope(
      // Pendant l'ajout au panier, le retour système est bloqué
      canPop: !_isAdding,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              backgroundColor: _surface,
              body: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(gallery, dish.image ?? ''),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Galerie (miniatures cliquables) ──
                          if (gallery.length > 1) ...[
                            _buildGalleryStrip(gallery),
                            const SizedBox(height: 24),
                          ],

                          // ── Titre + prix ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  dish.name ?? '',
                                  style: AppTypography.headlineMedium(color: _ink)
                                      .copyWith(height: 1.15),
                                ),
                              ),
                              const SizedBox(width: 16),
                              AnimatedBuilder(
                                animation: CurrencyService.instance,
                                builder: (_, __) => Text(
                                  CurrencyUtil.formatConvertedPrice(
                                      (dish.price ?? 0).toDouble()),
                                  style: AppTypography.headlineMedium(color: _brand)
                                      .copyWith(height: 1.15),
                                ),
                              ),
                            ],
                          ),

                          // ── Restaurant ──
                          const SizedBox(height: 8),
                          _buildRestaurantLine(),

                          // ── Méta : note, popularité, portions ──
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hasRating)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  StarRating(rating: dish.note),
                                  const SizedBox(width: 6),
                                  Text(
                                    dish.note.toStringAsFixed(1),
                                    style: AppTypography.bodyMedium(color: _ink)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              if (isPopular)
                                Text(
                                  l10n.dish_popular,
                                  style: AppTypography.bodyMedium(color: _accent)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              Text(
                                l10n.dish_servings_available('$servings'),
                                style: AppTypography.bodyMedium(
                                        color: lowStock ? _accent : _inkMuted)
                                    .copyWith(
                                        fontWeight:
                                            lowStock ? FontWeight.w600 : FontWeight.w400),
                              ),
                            ],
                          ),

                          CharacteristicsDisplay(targetType: 2, targetID: widget.dish_id),

                          // ── Catégories ──
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: categories
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _brandSurface,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          tag,
                                          style: AppTypography.labelMedium(color: _brand)
                                              .copyWith(fontSize: 11.5),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],

                          // ── Description ──
                          if ((dish.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              dish.description!,
                              style: AppTypography.bodyLarge(color: _ink)
                                  .copyWith(height: 1.55),
                            ),
                          ],

                          // ── Bannières (livraison / fermé) ──
                          if (deliveryBlocked) ...[
                            const SizedBox(height: 20),
                            DeliveryUnavailableBanner(
                              onTap: () => showDeliveryUnavailableSheet(context),
                            ),
                          ],
                          if (restaurantClosed) ...[
                            const SizedBox(height: 20),
                            RestaurantClosedBanner(
                              status: _openingStatus!,
                              onTap: () => showRestaurantClosedSheet(context),
                            ),
                          ],

                          // ── Options ──
                          if (options.isNotEmpty) ...[
                            _sectionDivider(),
                            Text(l10n.dish_options,
                                style: AppTypography.titleMedium(color: _ink)),
                            const SizedBox(height: 4),
                            ...options.asMap().entries.map((entry) {
                              return _buildOptionBlock(
                                entry.value,
                                entry.key,
                                isLast: entry.key == options.length - 1,
                              );
                            }),
                          ],

                          // ── Avis ──
                          _sectionDivider(),
                          Text(l10n.dish_reviews,
                              style: AppTypography.titleMedium(color: _ink)),
                          const SizedBox(height: 8),
                          PaginatedComments(targetType: 2, targetID: widget.dish_id),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: isOwner
                  ? null
                  : _buildBottomBar(
                      dish, currency, total, deliveryBlocked, restaurantClosed),
            ),

            // ── Overlay bloquant (couvre aussi la barre du bas) ──
            Positioned.fill(
              child: _BlockingLoader(
                visible: _isAdding,
                cardColor: _card,
                brand: _brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(height: 1, thickness: 0.5, color: _border),
    );
  }

  Widget _roundedIconButton({required Widget child, required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: child,
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(List<String> gallery, String fallbackUrl) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      leading: _roundedIconButton(
        child: Icon(Icons.arrow_back_rounded, size: 20, color: _ink),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (isOwner)
          _roundedIconButton(
            child: Icon(Icons.edit_rounded, size: 20, color: _brand),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => DishFormPage(dish: current_dish)),
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
            // Photos : on peut glisser horizontalement, les miniatures suivent
            if (gallery.isEmpty)
              DiosImage(url: fallbackUrl, fit: BoxFit.cover)
            else
              PageView.builder(
                controller: _pageController,
                itemCount: gallery.length,
                onPageChanged: (i) => setState(() => _galleryIndex = i),
                itemBuilder: (_, i) => SizedBox.expand(
                  child: DiosImage(url: gallery[i], fit: BoxFit.cover),
                ),
              ),

            // Dégradé haut : garde les boutons lisibles sur une photo claire
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _ink.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Dégradé bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _ink.withValues(alpha: 0.5)],
                    ),
                  ),
                ),
              ),
            ),

            // Indicateur de page
            if (gallery.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(gallery.length, (i) {
                      final active = i == _galleryIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: active ? 1 : 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
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
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryStrip(List<String> gallery) {
    const double size = 64;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gallery.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == _galleryIndex;
          return GestureDetector(
            onTap: () {
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
              } else {
                setState(() => _galleryIndex = i);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? _brand : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Opacity(
                opacity: selected ? 1 : 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: DiosImage(
                    url: gallery[i],
                    height: size - 8,
                    width: size - 8,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantLine() {
    if (_restaurantName.isNotEmpty) {
      return Row(children: [
        Icon(Icons.storefront_rounded, size: 16, color: _inkSubtle),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _restaurantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium(color: _inkMuted),
          ),
        ),
      ]);
    }
    // Le nom arrive après le plat : on réserve la place pour éviter un saut de mise en page
    if (!_checksDone) {
      return const _SkeletonShimmer(child: _Bone(width: 120, height: 14));
    }
    return const SizedBox.shrink();
  }

  /// Une option = un bloc à plat (sans carte), séparé de la suivante par un filet.
  Widget _buildOptionBlock(_ParsedOption opt, int optionIndex, {required bool isLast}) {
    final selectedChoiceIndex = _selectedChoiceIndices[optionIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opt.name,
            style: AppTypography.bodyLarge(color: _ink)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          if (opt.choices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opt.choices.asMap().entries.map((entry) {
                final choiceIndex = entry.key;
                final c = entry.value;
                final isSelected = selectedChoiceIndex == choiceIndex;
                final paid = c.extra != null;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      // Un second appui sur le choix actif le désélectionne
                      if (isSelected) {
                        _selectedChoiceIndices.remove(optionIndex);
                      } else {
                        _selectedChoiceIndices[optionIndex] = choiceIndex;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? _brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected ? _brand : _border,
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : _ink,
                        ),
                      ),
                      if (paid) ...[
                        const SizedBox(width: 6),
                        AnimatedBuilder(
                          animation: CurrencyService.instance,
                          builder: (_, __) => Text(
                            '+ ${CurrencyUtil.formatConvertedPrice(_extraAmount(c.extra))}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : _brand,
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(Dish dish, String currency, num total,
      bool deliveryBlocked, bool restaurantClosed) {
    final l10n = AppLocalizations.of(context)!;
    final disabled = deliveryBlocked || restaurantClosed;
    final maxParts = dish.nb_servings ?? 99;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          // Tant que dispo/horaires ne sont pas connus, on montre un placeholder
          // plutôt qu'un bouton actif qui deviendrait grisé une seconde après.
          child: !_checksDone
              ? const _SkeletonShimmer(
                  child: _Bone(height: 56, radius: 16),
                )
              : Row(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _qtyBtn(Icons.remove_rounded, number_of_parts > 1, () {
                        HapticFeedback.selectionClick();
                        setState(() => number_of_parts--);
                      }),
                      SizedBox(
                        width: 36,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Text(
                              '$number_of_parts',
                              key: ValueKey(number_of_parts),
                              style: AppTypography.titleMedium(color: _ink),
                            ),
                          ),
                        ),
                      ),
                      _qtyBtn(Icons.add_rounded, number_of_parts < maxParts, () {
                        HapticFeedback.selectionClick();
                        setState(() => number_of_parts++);
                      }),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (disabled || _isAdding) ? null : _addToCart,
                      icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                      label: AnimatedBuilder(
                        animation: CurrencyService.instance,
                        builder: (_, __) => Text(
                          deliveryBlocked
                              ? l10n.delivery_unavailable_short
                              : restaurantClosed
                                  ? l10n.restaurant_closed_short
                                  : l10n.dish_add_to_cart(CurrencyUtil.formatConvertedPrice(total.toDouble())),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        elevation: 0,
                        backgroundColor: _brand,
                        foregroundColor: _card,
                        disabledBackgroundColor: _inkMuted.withValues(alpha: 0.55),
                        disabledForegroundColor: _card.withValues(alpha: 0.75),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                        textStyle: AppTypography.labelLarge(color: _card),
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: enabled ? _brand : _inkSubtle, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overlay bloquant : voile + Swirling au centre.
// Le ModalBarrier absorbe tous les gestes tant qu'il est affiché.
// Quand il n'est pas visible, aucun widget animé n'est monté.
// ─────────────────────────────────────────────────────────────

class _BlockingLoader extends StatelessWidget {
  final bool visible;
  final Color cardColor;
  final Color brand;

  const _BlockingLoader({
    required this.visible,
    required this.cardColor,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? Stack(
              key: const ValueKey('blocking_loader'),
              fit: StackFit.expand,
              children: [
                ModalBarrier(
                  dismissible: false,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Swirling(size: 72, color: brand),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('blocking_loader_idle')),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Options : format stocké "Nom: Choix1 +500 FCFA / Choix2 (inclus)"
// Le premier choix est collé au nom, après les deux-points.
// ─────────────────────────────────────────────────────────────

class _ParsedChoice {
  final String label;
  final String? extra; // "+500 FCFA" ou null si inclus
  const _ParsedChoice(this.label, this.extra);
}

class _ParsedOption {
  final String name;
  final List<_ParsedChoice> choices;
  const _ParsedOption(this.name, this.choices);
}

_ParsedOption _parseOption(String raw) {
  final parts = raw.split(' / ');
  final head = parts.first;
  final colon = head.indexOf(':');
  final name = colon >= 0 ? head.substring(0, colon).trim() : head.trim();

  final rawChoices = <String>[
    if (colon >= 0) head.substring(colon + 1),
    ...parts.skip(1),
  ].map((e) => e.trim()).where((e) => e.isNotEmpty);

  final choices = rawChoices.map((c) {
    if (c.contains('(inclus)')) {
      return _ParsedChoice(c.replaceAll('(inclus)', '').trim(), null);
    }
    final m = RegExp(r'\+\s*\d[^+]*$').firstMatch(c);
    if (m != null) {
      return _ParsedChoice(c.substring(0, m.start).trim(), c.substring(m.start).trim());
    }
    return _ParsedChoice(c, null);
  }).toList();

  return _ParsedOption(name, choices);
}

// ─────────────────────────────────────────────────────────────
// État "introuvable / erreur"
// ─────────────────────────────────────────────────────────────

class _DishNotFound extends StatelessWidget {
  final VoidCallback onRetry;
  final Color brand;
  final Color ink;
  final Color surface;

  const _DishNotFound({
    required this.onRetry,
    required this.brand,
    required this.ink,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_meals_rounded, size: 56, color: ink.withValues(alpha: 0.35)),
              const SizedBox(height: 16),
              Text(
                "Ce plat est introuvable ou indisponible pour le moment.",
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: ink),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Réessayer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON de préchargement
// Reprend la structure de la vraie page (héros, titre, méta,
// description, miniatures, options, barre du bas) pour que le
// passage au contenu réel ne fasse pas "sauter" la mise en page.
// ─────────────────────────────────────────────────────────────

class _DishDetailsSkeleton extends StatelessWidget {
  const _DishDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: surface,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Stack(
          children: [
            // Héros
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 340,
              child: _SkeletonShimmer(child: _Bone(height: 340, radius: 0)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 316),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                  ),
                  child: const _SkeletonShimmer(child: _SkeletonContent()),
                ),
              ],
            ),
            // Bouton retour réel : l'utilisateur peut quitter pendant le chargement
            Positioned(
              top: top + 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border, width: 0.5)),
        ),
        child: const SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: _SkeletonShimmer(
              child: Row(children: [
                _Bone(width: 128, height: 56, radius: 16),
                SizedBox(width: 12),
                Expanded(child: _Bone(height: 56, radius: 16)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Miniatures
        Row(children: const [
          _Bone(width: 64, height: 64, radius: 12),
          SizedBox(width: 8),
          _Bone(width: 64, height: 64, radius: 12),
          SizedBox(width: 8),
          _Bone(width: 64, height: 64, radius: 12),
        ]),
        const SizedBox(height: 24),
        // Titre + prix
        Row(children: const [
          Expanded(child: _Bone(height: 28, radius: 8)),
          SizedBox(width: 40),
          _Bone(width: 90, height: 28, radius: 8),
        ]),
        const SizedBox(height: 10),
        // Restaurant
        const _Bone(width: 130, height: 14),
        const SizedBox(height: 16),
        // Méta (note, portions)
        Row(children: const [
          _Bone(width: 90, height: 14),
          SizedBox(width: 18),
          _Bone(width: 110, height: 14),
        ]),
        const SizedBox(height: 16),
        // Catégories
        Row(children: const [
          _Bone(width: 72, height: 26, radius: 999),
          SizedBox(width: 6),
          _Bone(width: 88, height: 26, radius: 999),
          SizedBox(width: 6),
          _Bone(width: 64, height: 26, radius: 999),
        ]),
        const SizedBox(height: 20),
        // Description
        const _Bone(height: 14),
        const SizedBox(height: 8),
        const _Bone(height: 14),
        const SizedBox(height: 8),
        const FractionallySizedBox(
          widthFactor: 0.65,
          alignment: Alignment.centerLeft,
          child: _Bone(height: 14),
        ),
        const SizedBox(height: 40),
        // Options
        const _Bone(width: 90, height: 20),
        const SizedBox(height: 16),
        const _Bone(width: 120, height: 16),
        const SizedBox(height: 12),
        Row(children: const [
          _Bone(width: 80, height: 36, radius: 999),
          SizedBox(width: 8),
          _Bone(width: 100, height: 36, radius: 999),
        ]),
      ],
    );
  }
}

/// Bloc gris de base du skeleton. La couleur réelle est peinte par le shimmer.
class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _Bone({this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // remplacé par le dégradé du shimmer (srcATop)
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Effet shimmer sans dépendance externe : un dégradé qui balaie ses enfants.
class _SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const _SkeletonShimmer({required this.child});

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE7E5E0);
    final highlight = isDark ? const Color(0xFF3C3C3C) : const Color(0xFFF6F4F0);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
            begin: const Alignment(-1, -0.3),
            end: const Alignment(1, 0.3),
            transform: _SlidingGradient(_controller.value),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlidingGradient extends GradientTransform {
  final double progress; // 0 → 1
  const _SlidingGradient(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // De -largeur à +largeur : le reflet traverse tout le bloc
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}