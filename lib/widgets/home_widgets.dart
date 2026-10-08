import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/screens/profile/profile_page.dart';
import 'package:dios_delices/services/currency_service.dart';
import 'package:dios_delices/services/favorites_service.dart';
import 'package:dios_delices/services/location_cache_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/delivery_fee_calculator.dart';
import 'package:dios_delices/widgets/dios_image.dart';
import 'package:dios_delices/widgets/search_input.dart';

// ═══════════════════════════════════════════════════════════
// Raccourcis couleurs (mêmes tokens que le reste de l'app)
// ═══════════════════════════════════════════════════════════
class HC {
  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  static Color get surfaceWarm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  static Color get card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  static Color get accent =>
      AppColors.resolve(AppColors.accent, AppDarkColors.accent);
  static Color get success =>
      AppColors.resolve(AppColors.success, AppDarkColors.success);
}

class HomeCategory {
  const HomeCategory({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// ═══════════════════════════════════════════════════════════
// Animations utilitaires
// ═══════════════════════════════════════════════════════════

/// Apparition douce (fondu + glissement), échelonnée par `index`.
class HomeReveal extends StatelessWidget {
  const HomeReveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Effet « appui » : léger rétrécissement au toucher.
class HomePressable extends StatefulWidget {
  const HomePressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<HomePressable> createState() => _HomePressableState();
}

class _HomePressableState extends State<HomePressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════
class HomeHeader extends StatelessWidget {
  final Users? currentUser;
  final String? addressLabel;
  final VoidCallback? onTap;
  const HomeHeader({super.key, this.currentUser, this.addressLabel, this.onTap});

  // Cache du dernier avatar décodé : évite de re-décoder le base64
  // (souvent plusieurs centaines de Ko) à chaque rebuild de la page.
  static String? _cachedRaw;
  static Uint8List? _cachedBytes;

  static Uint8List? _decodeBase64(String raw) {
    if (raw == _cachedRaw) return _cachedBytes;
    var data = raw;
    final comma = data.indexOf(',');
    if (data.startsWith('data:') && comma != -1) {
      data = data.substring(comma + 1); // data:image/jpeg;base64,XXXX
    }
    data = data.replaceAll(RegExp(r'\s'), '');
    Uint8List? bytes;
    try {
      bytes = base64Decode(data);
    } catch (_) {
      try {
        bytes = base64Decode(base64.normalize(data));
      } catch (_) {}
    }
    _cachedRaw = raw;
    _cachedBytes = bytes;
    return bytes;
  }

  /// Construit l'avatar utilisateur :
  /// 1. URL explicite (http, https, file://) ou chemin local connu → DiosImage
  /// 2. Base64 → Image.memory
  ///    ⚠ Un JPEG en base64 commence par "/9j/" : on ne doit SURTOUT PAS
  ///    le confondre avec un chemin commençant par "/".
  /// 3. Fallback → initiales
  Widget _buildUserAvatar(Users user, double size) {
    final raw = user.image.trim();
    if (raw.isEmpty) return _initials(user, size);

    final isUrlOrKnownPath = raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('file://') ||
        raw.startsWith('/data/') ||
        raw.startsWith('/storage/');
    if (isUrlOrKnownPath) {
      return ClipOval(
        child: DiosImage(url: raw, width: size, height: size, fit: BoxFit.cover),
      );
    }

    final bytes = _decodeBase64(raw);
    if (bytes != null && bytes.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initials(user, size),
        ),
      );
    }

    // Dernier recours : chemin / URL relative
    if (raw.startsWith('/')) {
      return ClipOval(
        child: DiosImage(url: raw, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return _initials(user, size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = currentUser;

    Widget avatarChild;
    if (user != null) {
      avatarChild = _buildUserAvatar(user, 46);
    } else {
      avatarChild = Icon(Icons.person_rounded, color: HC.brand, size: 24);
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: HC.card,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: HC.border.withValues(alpha: 0.6)),
                        boxShadow: [AppShadows.subtle],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: HC.brandSurface, shape: BoxShape.circle),
                            child: Icon(Icons.location_on_rounded,
                                color: HC.brand, size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              addressLabel ?? l10n.home_nearby,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium(color: HC.ink)
                                  .copyWith(
                                      fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: HC.inkMuted, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          CupertinoPageRoute(builder: (_) => ProfilePage())),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HC.brandSurface,
                          border: Border.all(color: HC.brand, width: 1.8),
                          boxShadow: [AppShadows.subtle],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatarChild,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: HC.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: HC.surface, width: 1.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SearchInput(),
          ],
        ),
      ),
    );
  }

  Widget _initials(Users user, double size) {
    final initials = '${user.firstname.isNotEmpty ? user.firstname[0] : ''}'
            '${user.lastname.isNotEmpty ? user.lastname[0] : ''}'
        .toUpperCase();
    return Center(
      child: Text(initials,
          style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: HC.brand)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Bannière de bienvenue
// ═══════════════════════════════════════════════════════════
class HomeWelcomeBanner extends StatelessWidget {
  const HomeWelcomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8673A), Color(0xFFC84C2F), Color(0xFF9E3520)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.38),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: _bubble(140, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              right: 70,
              bottom: -40,
              child: _bubble(100, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              left: -24,
              bottom: -24,
              child: _bubble(90, Colors.black.withValues(alpha: 0.07)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, 128, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l10n.home_welcome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium(color: Colors.white)
                                .copyWith(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.home_tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleLarge().copyWith(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.home_subtagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(
                      color: Colors.white.withValues(alpha: 0.78),
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: -4,
              child: Transform.rotate(
                angle: 0.06,
                child: Image.asset('assets/images/meals/pancakes.png',
                    width: 96, height: 96),
              ),
            ),
            Positioned(
              right: 70,
              top: 10,
              child: Transform.rotate(
                angle: -0.20,
                child: Image.asset('assets/images/meals/soda.png',
                    width: 72, height: 72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ═══════════════════════════════════════════════════════════
// Catégories rondes (défilement horizontal)
// ═══════════════════════════════════════════════════════════
class HomeRoundCategories extends StatelessWidget {
  const HomeRoundCategories({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSeeAll,
  });

  final List<HomeCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visibleCount = categories.length > 8 ? 8 : categories.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l10n.home_categories),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: visibleCount + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              if (i == visibleCount) {
                return _item(
                  icon: Icons.grid_view_rounded,
                  label: 'Plus',
                  selected: false,
                  more: true,
                  onTap: onSeeAll,
                );
              }
              final cat = categories[i];
              return _item(
                icon: cat.icon,
                label: cat.label,
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool more = false,
  }) {
    return HomePressable(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? HC.brand
                    : (more ? HC.brandSurface : HC.card),
                border: Border.all(
                  color: selected
                      ? HC.brand
                      : (more ? HC.brand.withValues(alpha: 0.4) : HC.border),
                  width: selected ? 0 : 0.8,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: HC.brand.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [AppShadows.subtle],
              ),
              child: Icon(icon,
                  size: 26,
                  color: selected
                      ? Colors.white
                      : (more ? HC.brand : HC.inkMuted)),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium(
                color: selected ? HC.brand : HC.inkMuted,
              ).copyWith(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// En-tête de section
// ═══════════════════════════════════════════════════════════
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: HC.brand,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: AppTypography.titleMedium(color: HC.ink)
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                decoration: BoxDecoration(
                  color: HC.brandSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!,
                        style: AppTypography.labelMedium(color: HC.brand)),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: HC.brand),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Carrousel restaurants
// ═══════════════════════════════════════════════════════════
class HomeRestaurantCarousel extends StatelessWidget {
  const HomeRestaurantCarousel({
    super.key,
    required this.restaurants,
    required this.users,
    required this.onTap,
    this.outOfRangeRestauIds = const {},
  });

  final List<Restaurant> restaurants;
  final List<Users> users;
  final ValueChanged<int> onTap;
  final Set<int> outOfRangeRestauIds;

  @override
  Widget build(BuildContext context) {
    final count = restaurants.length > 6 ? 6 : restaurants.length;
    return SizedBox(
      height: 296,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
            left: AppSpacing.lg, right: AppSpacing.lg, bottom: 8),
        itemCount: count,
        itemBuilder: (_, i) {
          final restau = restaurants[i];
          return HomeRestaurantCard(
            restaurant: restau,
            isPro: restau.isPro,
            outOfRange: outOfRangeRestauIds.contains(restau.restaurantID),
            onTap: () => onTap(restau.restaurantID),
          );
        },
      ),
    );
  }
}

class HomeRestaurantCard extends StatefulWidget {
  const HomeRestaurantCard({
    super.key,
    required this.restaurant,
    required this.isPro,
    required this.onTap,
    this.outOfRange = false,
  });

  final Restaurant restaurant;
  final bool isPro;
  final bool outOfRange;
  final VoidCallback onTap;

  @override
  State<HomeRestaurantCard> createState() => _HomeRestaurantCardState();
}

class _HomeRestaurantCardState extends State<HomeRestaurantCard> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final favorite = await FavoritesService.isRestaurantFavorite(
        widget.restaurant.restaurantID);
    if (mounted) setState(() => isFavorite = favorite);
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await FavoritesService.toggleRestaurantFavorite(
        widget.restaurant.restaurantID);
    if (mounted) setState(() => isFavorite = newStatus);
  }

  List<String> _tags() {
    final raw = widget.restaurant.categories;
    if (raw.isEmpty) return const [];
    final parts = raw
        .split(RegExp(r'[#,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s
            .replaceAll('-', ' ')
            .split(' ')
            .map(
                (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' '))
        .toSet()
        .toList();
    return parts.take(2).toList();
  }

  Widget _floatingChip({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
                color: Color(0x20000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final openingStatus = widget.restaurant.openingStatus;
    final restaurantClosed = !openingStatus.isOpen;
    final openingMessage = openingStatus.isClosedManually
        ? l10n.restaurant_closed_manually
        : openingStatus.opensLaterToday
            ? l10n.restaurant_opens_at(openingStatus.opensAt!)
            : openingStatus.opensOn != null
                ? l10n.restaurant_opens_on(
                    openingStatus.opensOn!, openingStatus.opensAt ?? '')
                : l10n.restaurant_closed_today;

    final titleColor = widget.outOfRange
        ? colorScheme.onSurface.withValues(alpha: 0.7)
        : colorScheme.onSurface;
    final tags = _tags();
    
    /** Affichage dynamique basé sur le cache GPS ou libellé harmonisé "Dès X"
    final cachedPos = LocationCacheService.instance.cachedPosition;
    final String deliveryLabel;
    final bool isFreeDelivery;
    if (cachedPos != null) {
      final estimate = DeliveryFeeCalculator.estimateFeeForRestaurant(
        userLat: cachedPos.latitude,
        userLng: cachedPos.longitude,
        restaurant: widget.restaurant,
      );
      deliveryLabel = estimate.summaryLabel;
      isFreeDelivery = estimate.fee == 0;
    } else {
      deliveryLabel =
          DeliveryFeeCalculator.getStartingFeeLabel(widget.restaurant);
      isFreeDelivery = false;
    } **/

    return HomePressable(
      onTap: widget.onTap,
      child: Container(
        width: 262,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: HC.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: HC.border.withValues(alpha: 0.5), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: HC.ink.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: HC.ink.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE ────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 164,
                    width: double.infinity,
                    child: Opacity(
                      opacity: widget.outOfRange
                          ? 0.55
                          : (restaurantClosed ? 0.75 : 1.0),
                      child: ColorFiltered(
                        colorFilter: widget.outOfRange
                            ? const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0.2126, 0.7152, 0.0722, 0, 0, //
                                0, 0, 0, 1, 0,
                              ])
                            : const ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply),
                        child: DiosImage(
                          url: widget.restaurant.image,
                          width: double.infinity,
                          height: 164,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Dégradé bas
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Overlay hors zone
                  if (widget.outOfRange)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE3A34),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_off_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Hors zone',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Overlay fermé
                  if (!widget.outOfRange && restaurantClosed)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: Colors.black.withValues(alpha: 0.38),
                        child: Text(
                          openingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),

                  // Note
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _floatingChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: HC.accent, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            widget.restaurant.note > 0
                                ? widget.restaurant.note.toStringAsFixed(1)
                                : '—',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B211D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Favori
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? HC.brand
                              : Colors.white.withValues(alpha: 0.96),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x20000000),
                                blurRadius: 6,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: isFavorite ? Colors.white : HC.brand,
                        ),
                      ),
                    ),
                  ),

                  // PRO
                  if (widget.isPro)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: HC.accent,
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
                    ),

                  // Frais de livraison (sur l'image)
                  /** Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        //color: isFreeDelivery
                            ? HC.success
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: AnimatedBuilder(
                        animation: CurrencyService.instance,
                        builder: (_, __) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delivery_dining_rounded,
                                size: 14,
                                color: isFreeDelivery
                                    ? Colors.white
                                    : const Color(0xFF2B211D)),
                            const SizedBox(width: 4),
                            Text(
                              deliveryLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isFreeDelivery
                                    ? Colors.white
                                    : const Color(0xFF2B211D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ), **/
                ],
              ),
            ),

            // ── TEXTE ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant.name,
                    style: AppTypography.titleMedium(color: titleColor)
                        .copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        restaurantClosed
                            ? Icons.lock_clock_rounded
                            : Icons.schedule_rounded,
                        color: restaurantClosed
                            ? const Color(0xFFBE3A34)
                            : HC.inkMuted,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          restaurantClosed
                              ? openingMessage
                              : widget.restaurant.openingHours.isNotEmpty
                                  ? widget.restaurant.openingHours
                                  : l10n.home_contact,
                          style: AppTypography.labelMedium(
                            color: HC.inkMuted,
                          ).copyWith(fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: HC.brandSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: HC.brand,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// État vide
// ═══════════════════════════════════════════════════════════
class HomeEmptyRestaurants extends StatelessWidget {
  const HomeEmptyRestaurants({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration:
                BoxDecoration(color: HC.brandSurface, shape: BoxShape.circle),
            child: Icon(Icons.storefront_outlined, color: HC.brand, size: 44),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.home_no_restaurants,
              style: AppTypography.titleMedium(color: colorScheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.home_no_restaurants_hint,
            style: AppTypography.bodyMedium(
                color: colorScheme.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SKELETON (pré-chargement)
// ═══════════════════════════════════════════════════════════

/// Effet « shimmer » : un reflet lumineux traverse tous les blocs enfants.
class HomeShimmer extends StatefulWidget {
  const HomeShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<HomeShimmer> createState() => _HomeShimmerState();
}

class _HomeShimmerState extends State<HomeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = HC.surfaceWarm;
    final highlight = Color.lerp(HC.surfaceWarm, HC.card, 0.85)!;
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final v = _ctrl.value;
          return LinearGradient(
            begin: Alignment(-1.6 + 3.2 * v, -0.3),
            end: Alignment(-0.6 + 3.2 * v, 0.3),
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
    this.circle = false,
  });
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton d'une carte restaurant (aussi utilisé lors des rechargements).
class HomeRestaurantSkeleton extends StatelessWidget {
  const HomeRestaurantSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeShimmer(
      child: SizedBox(
        height: 296,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
              left: AppSpacing.lg, right: AppSpacing.lg, bottom: 8),
          itemCount: 3,
          itemBuilder: (_, __) => Container(
            width: 262,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: HC.card,
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: HC.border.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: const SkeletonBox(
                      width: double.infinity, height: 164, radius: 0),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 15),
                      SizedBox(height: 12),
                      SkeletonBox(width: 110, height: 11),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          SkeletonBox(width: 64, height: 18, radius: 99),
                          SizedBox(width: 6),
                          SkeletonBox(width: 54, height: 18, radius: 99),
                        ],
                      ),
                    ],
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

/// Skeleton de TOUTE la page d'accueil (affiché au premier chargement).
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: HomeShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header : adresse + avatar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Row(
                  children: const [
                    Expanded(
                        child: SkeletonBox(height: 46, radius: 999)),
                    SizedBox(width: 12),
                    SkeletonBox(width: 46, height: 46, circle: true),
                  ],
                ),
              ),
              // Recherche
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: SkeletonBox(height: 52, radius: 16),
              ),
              // Bannière
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: SkeletonBox(height: 160, radius: 24),
              ),
              // Titre catégories
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                child: SkeletonBox(width: 130, height: 18),
              ),
              // Catégories rondes
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, __) => const SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        SkeletonBox(width: 62, height: 62, circle: true),
                        SizedBox(height: 9),
                        SkeletonBox(width: 44, height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              // Titre restaurants
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                child: Row(
                  children: [
                    SkeletonBox(width: 160, height: 18),
                    Spacer(),
                    SkeletonBox(width: 70, height: 28, radius: 99),
                  ],
                ),
              ),
              // Cartes restaurants (sans second shimmer imbriqué)
              SizedBox(
                height: 296,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                      left: AppSpacing.lg, right: AppSpacing.lg, bottom: 8),
                  itemCount: 3,
                  itemBuilder: (_, __) => Container(
                    width: 262,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: HC.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: HC.border.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22)),
                          child: const SkeletonBox(
                              width: double.infinity, height: 164, radius: 0),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 150, height: 15),
                              SizedBox(height: 12),
                              SkeletonBox(width: 110, height: 11),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  SkeletonBox(width: 64, height: 18, radius: 99),
                                  SizedBox(width: 6),
                                  SkeletonBox(width: 54, height: 18, radius: 99),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}