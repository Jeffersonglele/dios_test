import 'dart:math';

import 'dart:convert';

import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/screens/profile/profile_page.dart';
import 'package:dios_delices/screens/profile/location_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../constants/constant.dart';
import '../../controllers/ui_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/search_input.dart';
import '../../core/app_role.dart';
import '../../models/address.dart';
import '../../models/category.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../services/session_service.dart';
import '../../services/favorites_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dios_image.dart';
import '../explore/food_categories.dart';
import 'near_me_meals.dart';
import '../restaurants/near_me_restaurants.dart';
import '../restaurants/restaurant_details.dart';

// ═══════════════════════════════════════════════════════════
// HomeUser
// ═══════════════════════════════════════════════════════════

class HomeUser extends StatefulWidget {
  const HomeUser({super.key});

  @override
  State<HomeUser> createState() => _HomeUserState();
}

class _HomeUserState extends State<HomeUser> {
  List<Users> _users = [];
  List<Restaurant> _allRestaus = [];
  List<Restaurant> _restaus = [];
  List<Address> _addresses = [];

  /// Set d'IDs de restaurants qui sont hors du rayon de livraison
  final Set<int> _outOfRangeRestauIds = {};

  int _currentUserID = 0;
  int _currentUserRole = 0;
  int _currentUserRestau = 0;
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  String _liveAddress = '';
  List<_Category> _categories = [
    _Category(icon: Icons.restaurant_rounded, label: 'Tout'),
  ];

  static IconData _iconForCategory(String name) {
    switch (name.toLowerCase()) {
      case 'africain':
        return Icons.language_rounded;
      case 'européen':
      case 'europeen':
        return Icons.public_rounded;
      case 'asiatique':
        return Icons.ramen_dining_rounded;
      case 'végétarien':
      case 'vegetarien':
        return Icons.eco_rounded;
      case 'street food':
        return Icons.directions_walk_rounded;
      case 'fast food':
        return Icons.fastfood_rounded;
      case 'dessert':
        return Icons.cake_rounded;
      case 'pizza':
        return Icons.local_pizza_rounded;
      case 'burger':
        return Icons.lunch_dining_rounded;
      case 'soup':
      case 'soupe':
        return Icons.soup_kitchen_rounded;
      case 'salade':
        return Icons.eco_rounded;
      case 'crepes':
      case 'crêpes':
        return Icons.dinner_dining_rounded;
      case 'japonais':
        return Icons.ramen_dining_rounded;
      case 'beignets':
        return Icons.bakery_dining_rounded;
      case 'jus':
      case 'bubble tea':
        return Icons.local_drink_rounded;
      case 'vegan':
        return Icons.spa_rounded;
      case 'healthy':
        return Icons.favorite_rounded;
      case 'boisson':
        return Icons.local_drink_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    dataVersionNotifier.addListener(_onDataChanged);
    _loadData();
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final session = await SessionService.readSession();
    final results = await Future.wait([
      Users.fetchUsersFromDB(),
      Restaurant.fetchRestaurantsFromDB(),
      Address.fetchAddressesFromDB(),
      CategoryService.getAllCategories(),
    ]);
    final usersList = results[0] as List<Users>;
    final restausList = results[1] as List<Restaurant>;
    final addressList = results[2] as List<Address>;
    final dbCats = results[3] as List<Category>;
    if (!mounted) return;
    setState(() {
      _currentUserID = session.userId;
      _currentUserRole = session.role.id;
      _currentUserRestau = session.restaurantId ?? 0;
      _users = usersList;
      _allRestaus = restausList;
      _addresses = addressList;
      _categories = [
        _Category(icon: Icons.restaurant_rounded, label: 'Tout'),
        ...dbCats.map(
            (c) => _Category(icon: _iconForCategory(c.name), label: c.name)),
      ];
    });
    await _tagOutOfRangeAndSort();
    _detectLiveLocation();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _tagOutOfRangeAndSort() async {
    const double maxKm = 10.0;
    final inRange = <Restaurant>[];
    final outOfRange = <Restaurant>[];
    _outOfRangeRestauIds.clear();

    Address? userAddress;
    for (final addr in _addresses) {
      if (addr.objectID == _currentUserID && addr.object == 'User') {
        userAddress = addr;
        break;
      }
    }

    if (userAddress != null) {
      double? uLat = double.tryParse(userAddress.lat ?? '');
      double? uLon = double.tryParse(userAddress.long ?? '');

      for (final r in _allRestaus) {
        final rAddr = Address.getAddressByObject(_addresses, 'User', r.userID);
        bool isOut = false;
        if (uLat != null && uLon != null && rAddr != null) {
          final rLat = double.tryParse(rAddr.lat ?? '');
          final rLon = double.tryParse(rAddr.long ?? '');
          if (rLat != null && rLon != null) {
            if (_haversine(uLat, uLon, rLat, rLon) > maxKm) {
              isOut = true;
            }
          }
        }
        if (isOut) {
          outOfRange.add(r);
          _outOfRangeRestauIds.add(r.restaurantID);
        } else {
          inRange.add(r);
        }
      }
    } else {
      inRange.addAll(_allRestaus);
    }

    if (mounted) {
      setState(() {
        _allRestaus = [...inRange, ...outOfRange];
      });
    }
    _filterByCategory();
  }

  void _filterByCategory() {
    if (_selectedCategoryIndex == 0) {
      // "Tout" is selected, show all
      if (mounted) {
        setState(() {
          _restaus = _allRestaus;
        });
      }
      return;
    }
    final selectedCat = _categories[_selectedCategoryIndex]
        .label
        .toLowerCase()
        .replaceAll(' ', '-');
    if (mounted) {
      setState(() {
        _restaus = _allRestaus.where((r) {
          final restauCats = r.categories.toLowerCase();
          return restauCats.contains('#$selectedCat') ||
              restauCats.contains(selectedCat);
        }).toList();
      });
    }
  }

  void _addAddress() {
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => LocationPage(
                  objectID: _currentUserID,
                  user_roleID: _currentUserRole,
                ))).then((_) => _loadData());
  }

  Future<void> _detectLiveLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5));
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addr = [p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        if (mounted && addr.isNotEmpty) setState(() => _liveAddress = addr);
      }
    } catch (_) {}
  }

  double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371.0;
    final dLat = (la2 - la1) * (pi / 180);
    final dLon = (lo2 - lo1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1 * pi / 180) *
            cos(la2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor:
              AppColors.resolve(AppColors.surface, AppDarkColors.surface),
          body: RefreshIndicator(
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            backgroundColor:
                AppColors.resolve(AppColors.card, AppDarkColors.card),
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Bannière adresse manquante ───────────
                if (_currentUserRole == 2 &&
                    !_addresses.any((a) =>
                        a.objectID == _currentUserID && a.object == 'User'))
                  SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () => _addAddress(),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFBE3A34),
                        ),
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.home_add_address_banner,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white70),
                        ]),
                      ),
                    ),
                  ),
                // ── Header ──────────────────────────────
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    currentUser: Users.getUsersByUserId(_users, _currentUserID),
                    addressLabel: _liveAddress.isNotEmpty ? _liveAddress : null,
                    onTap: () => _addAddress(),
                  ),
                ),

                // ── Bannière de bienvenue ────────────────
                const SliverToBoxAdapter(
                  child: _WelcomeBanner(),
                ),

                // ── Catégories rondes ─────────────────────
                SliverToBoxAdapter(
                  child: _RoundCategories(
                    categories: _categories,
                    selectedIndex: _selectedCategoryIndex,
                    onSelect: (i) {
                      setState(() {
                        _selectedCategoryIndex = i;
                      });
                      _filterByCategory();
                    },
                  ),
                ),

                // ── Section restaurants ──────────────────
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l10n.home_top_picks,
                    actionLabel: l10n.home_see_all,
                    onAction: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const NearMeRestaurants())),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _isLoading
                      ? const _RestaurantSkeleton()
                      : _restaus.isEmpty
                          ? const _EmptyRestaurants()
                          : _RestaurantCarousel(
                              restaurants: _restaus,
                              users: _users,
                              outOfRangeRestauIds: _outOfRangeRestauIds,
                              onTap: (id) => Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) =>
                                      RestaurantDetails(restaurant_id: id),
                                ),
                              ),
                            ),
                ),

                // ── Section plats ────────────────────────
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l10n.home_meals_nearby,
                    actionLabel: l10n.home_see_all,
                    onAction: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => NearMeMeals(
                                category: _selectedCategoryIndex > 0
                                    ? _categories[_selectedCategoryIndex].label
                                    : null))),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _ExploreButton(
                    onTap: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => FoodCategories())),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _HomeHeader — SafeArea + padding top généreux
// ═══════════════════════════════════════════════════════════
class _HomeHeader extends StatelessWidget {
  final Users? currentUser;
  final String? addressLabel;
  final VoidCallback? onTap;
  const _HomeHeader({this.currentUser, this.addressLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final user = currentUser;
    final brandColor = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final brandSurface =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
    final surfaceColor =
        AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final borderColor =
        AppColors.resolve(AppColors.border, AppDarkColors.border);

    Widget avatarChild;
    if (user != null && user.image.isNotEmpty) {
      try {
        avatarChild = ClipOval(
          child: Image.memory(
            base64Decode(user.image),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        avatarChild = _avatarInitials(user, brandColor);
      }
    } else if (user != null) {
      avatarChild = _avatarInitials(user, brandColor);
    } else {
      avatarChild = Icon(Icons.person_rounded, color: brandColor, size: 24);
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: brandColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            l10n.home_deliver_to,
                            style: AppTypography.labelMedium(
                                color: colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: onTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              addressLabel ?? l10n.home_nearby,
                              style: AppTypography.titleMedium(
                                      color: colorScheme.onSurface)
                                  .copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurface.withOpacity(0.6),
                                size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          CupertinoPageRoute(builder: (_) => ProfilePage())),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandSurface,
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
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
                          color: brandColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor, width: 1.5),
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

  Widget _avatarInitials(Users user, Color brandColor) {
    final initials = '${user.firstname.isNotEmpty ? user.firstname[0] : ''}'
            '${user.lastname.isNotEmpty ? user.lastname[0] : ''}'
        .toUpperCase();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: brandColor,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _WelcomeBanner — Bannière de bienvenue chaleureuse
// Fond dégradé brand chaud · visuels food flottants · message accueil
// ═══════════════════════════════════════════════════════════
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8673A),
            Color(0xFFC84C2F),
            Color(0xFF9E3520),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cercles décoratifs de fond
            Positioned(
              right: -24,
              top: -28,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -36,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Texte bienvenue à gauche
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, 130, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👋', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.home_welcome,
                        style: AppTypography.labelMedium(
                          color: Colors.white.withValues(alpha: 0.85),
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.home_tagline,
                    style: AppTypography.titleLarge().copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.home_subtagline,
                    style: AppTypography.labelMedium(
                      color: Colors.white.withValues(alpha: 0.70),
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),

            // Visuels food flottants à droite
            Positioned(
              right: 10,
              bottom: -4,
              child: Transform.rotate(
                angle: 0.06,
                child: Image.asset(
                  'assets/images/meals/pancakes.png',
                  width: 90,
                  height: 90,
                ),
              ),
            ),
            Positioned(
              right: 68,
              top: 12,
              child: Transform.rotate(
                angle: -0.20,
                child: Image.asset(
                  'assets/images/meals/soda.png',
                  width: 70,
                  height: 70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RoundCategories — Catégories en icônes rondes
// ═══════════════════════════════════════════════════════════
class _RoundCategories extends StatelessWidget {
  const _RoundCategories({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_Category> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
          child: Text(l10n.home_categories,
              style: AppTypography.titleMedium(color: colorScheme.onSurface)),
        ),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final selected = i == selectedIndex;
              final cat = categories[i];
              final resolvedBrand =
                  AppColors.resolve(AppColors.brand, AppDarkColors.brand);
              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 68,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        curve: AppMotion.standard,
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? resolvedBrand
                              : AppColors.resolve(
                                  AppColors.card, AppDarkColors.card),
                          border: Border.all(
                            color: selected
                                ? resolvedBrand
                                : AppColors.resolve(
                                        AppColors.border, AppDarkColors.border)
                                    .withValues(alpha: 0.6),
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color:
                                        resolvedBrand.withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [AppShadows.subtle],
                        ),
                        child: Icon(
                          cat.icon,
                          size: 24,
                          color: selected
                              ? Colors.white
                              : AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium(
                          color: selected
                              ? resolvedBrand
                              : AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                        ).copyWith(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _SectionHeader
// ═══════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: AppTypography.titleMedium(color: colorScheme.onSurface)),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.brandSurface, AppDarkColors.brandSurface),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.labelMedium(color: resolvedBrand),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RestaurantCarousel
// ═══════════════════════════════════════════════════════════
class _RestaurantCarousel extends StatelessWidget {
  const _RestaurantCarousel({
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
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: count,
        itemBuilder: (_, i) {
          final restau = restaurants[i];
          final isPro = restau.isPro;
          final outOfRange = outOfRangeRestauIds.contains(restau.restaurantID);
          return _RestaurantCard(
            restaurant: restau,
            isPro: isPro,
            outOfRange: outOfRange,
            onTap: () => onTap(restau.restaurantID),
          );
        },
      ),
    );
  }
}

class _RestaurantCard extends StatefulWidget {
  const _RestaurantCard({
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
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final favorite = await FavoritesService.isRestaurantFavorite(
        widget.restaurant.restaurantID);
    if (mounted) {
      setState(() {
        isFavorite = favorite;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await FavoritesService.toggleRestaurantFavorite(
        widget.restaurant.restaurantID);
    if (mounted) {
      setState(() {
        isFavorite = newStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final resolvedAccent =
        AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final titleColor = widget.outOfRange
        ? colorScheme.onSurface.withValues(alpha: 0.7)
        : colorScheme.onSurface;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)
                  .withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Opacity(
                    opacity: widget.outOfRange ? 0.75 : 1,
                    child: DiosImage(
                      url: widget.restaurant.image,
                      width: double.infinity,
                      height: 180,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          inkColor.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.outOfRange)
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.black.withValues(alpha: 0.32),
                      child: const Text(
                        'Marchand hors de votre zone de livraison',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Color(0x55000000),
                              offset: Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.outOfRange
                          ? inkColor.withValues(alpha: 0.6)
                          : resolvedBrand,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      l10n.home_delivery_fee_label(
                          widget.restaurant.deliveryFee.toStringAsFixed(0)),
                      style: AppTypography.labelMedium(color: Colors.white)
                          .copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (widget.isPro)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: resolvedAccent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'PRO',
                        style: AppTypography.labelMedium(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))
                            .copyWith(
                                fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                if (widget.outOfRange)
                  Positioned(
                    bottom: -6,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            size: 12,
                            color: inkColor.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Hors de portée',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xDE000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                                AppColors.card, AppDarkColors.card)
                            .withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [AppShadows.subtle],
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                        color: widget.outOfRange
                            ? inkColor.withValues(alpha: 0.55)
                            : resolvedBrand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant.name,
                    style: AppTypography.titleMedium(color: titleColor)
                        .copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: widget.outOfRange
                              ? colorScheme.onSurface.withValues(alpha: 0.45)
                              : resolvedAccent,
                          size: 13),
                      const SizedBox(width: 3),
                      Text(
                        widget.restaurant.note > 0
                            ? widget.restaurant.note.toStringAsFixed(1)
                            : l10n.home_rated,
                        style: AppTypography.labelMedium(
                                color: titleColor.withValues(alpha: 0.85))
                            .copyWith(fontSize: 11),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      Icon(Icons.schedule_rounded,
                          color: colorScheme.onSurface.withOpacity(0.4),
                          size: 12),
                      const SizedBox(width: 3),
                      Text(
                        widget.restaurant.openingHours.isNotEmpty
                            ? widget.restaurant.openingHours
                            : l10n.home_contact,
                        style: AppTypography.labelMedium(
                                color: colorScheme.onSurface.withOpacity(0.5))
                            .copyWith(fontSize: 11),
                      ),
                    ],
                  ),
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
// _EmptyRestaurants
// ═══════════════════════════════════════════════════════════
class _EmptyRestaurants extends StatelessWidget {
  const _EmptyRestaurants();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.storefront_outlined, color: resolvedBrand, size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.home_no_restaurants,
              style: AppTypography.titleMedium(color: colorScheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.home_no_restaurants_hint,
            style: AppTypography.bodyMedium(
                color: colorScheme.onSurface.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _ExploreButton
// ═══════════════════════════════════════════════════════════
class _ExploreButton extends StatelessWidget {
  const _ExploreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(
            Icons.grid_view_rounded,
            size: 20,
            color: colorScheme.onSurface,
          ),
          label: Text(
            l10n.home_explore_categories,
            style: AppTypography.titleMedium(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Skeleton + Shimmer
// ═══════════════════════════════════════════════════════════
class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 200,
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color:
                    AppColors.resolve(AppColors.border, AppDarkColors.border),
                width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 180,
                  color: AppColors.resolve(
                      AppColors.surfaceWarm, AppDarkColors.surfaceWarm)),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBar(width: 120, height: 13),
                    SizedBox(height: 8),
                    _ShimmerBar(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSurfaceWarm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final resolvedBorder =
        AppColors.resolve(AppColors.border, AppDarkColors.border);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(resolvedSurfaceWarm, resolvedBorder, _ctrl.value),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Modèle interne
// ═══════════════════════════════════════════════════════════
class _Category {
  const _Category({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
