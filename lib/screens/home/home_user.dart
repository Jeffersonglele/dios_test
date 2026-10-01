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
import '../../services/node_home_service.dart';
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

  final Set<int> _outOfRangeRestauIds = {};

  int _currentUserID = 0;
  int _currentUserRole = 0;
  int _currentUserRestau = 0;
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  String _liveAddress = '';
  String? _liveCity;
  String? _liveCountry;
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
    final nodeToken = await SessionService.readNodeToken();

    NodeHomeSnapshot? nodeHome;
    try {
      nodeHome = await NodeHomeService.load(token: nodeToken);
    } catch (e, stack) {
      debugPrint('⚠️ NodeHomeService.load() FAILED: $e');
      debugPrint('$stack');
      nodeHome = null;
    }

    if (nodeHome != null && mounted) {
      final u = nodeHome.user;
      final restaus = nodeHome.restaurants;
      final addrs = nodeHome.addresses;
      final cats = nodeHome.categories;
      setState(() {
        _currentUserID = u?.userID ?? session.userId;
        _currentUserRole = u?.roleID ?? session.role.id;
        _currentUserRestau = session.restaurantId ?? 0;
        _users = u == null ? _users : [u];
        _allRestaus = restaus;
        _addresses = addrs;
        _categories = [
          _Category(icon: Icons.restaurant_rounded, label: 'Tout'),
          ...cats.map(
              (c) => _Category(icon: _iconForCategory(c.name), label: c.name)),
        ];
        _isLoading = false;
      });
      await _tagOutOfRangeAndSort();
      _detectLiveLocation();
      return;
    }

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
      _isLoading = false;
    });
    await _tagOutOfRangeAndSort();
    _detectLiveLocation();
  }

  Future<void> _tagOutOfRangeAndSort() async {
    final inRange = <Restaurant>[];
    final outOfRange = <Restaurant>[];
    _outOfRangeRestauIds.clear();

    final userAddress =
        Address.getAddressByObject(_addresses, 'User', _currentUserID) ??
            Address.getAddressByObject(_addresses, 'Livraison', _currentUserID);

    final userCityID = userAddress?.cityID ?? 0;
    final userCityText = _normalize(_firstNonEmpty([
      userAddress?.city,
      _liveCity,
    ]));
    final userCountryText = _normalize(_firstNonEmpty([
      userAddress?.state,
      _liveCountry,
    ]));
    final userLat = double.tryParse(userAddress?.lat ?? '');
    final userLon = double.tryParse(userAddress?.long ?? '');

    final hasUserLocation = (userCityID > 0) ||
        (userCityText != null && userCountryText != null) ||
        (userLat != null && userLon != null);

    if (hasUserLocation) {
      for (final r in _allRestaus) {
        final rAddr =
            Address.getAddressByObject(_addresses, 'Restaurant', r.userID) ??
                Address.getAddressByObject(_addresses, 'User', r.userID);
        bool isOut = false;

        final rCityID = r.cityID > 0 ? r.cityID : (rAddr?.cityID ?? 0);
        final rCityText = _normalize(_firstNonEmpty([rAddr?.city, r.location]));
        final rCountryText = _normalize(_firstNonEmpty([
          rAddr?.state,
          r.country,
        ]));

        // 1) cityID fiable des deux côtés → comparaison stricte
        if (userCityID > 0 && rCityID > 0) {
          if (userCityID != rCityID) isOut = true;
        }
        // 2) Sinon comparaison texte normalisée (ville + pays)
        else if ((userCityText != null && userCountryText != null) ||
            (rCityText != null && rCountryText != null)) {
          final sameCountry = (userCountryText != null &&
              rCountryText != null &&
              userCountryText == rCountryText);
          final sameCity = sameCountry &&
              userCityText != null &&
              rCityText != null &&
              userCityText == rCityText;
          if (!sameCity) {
            // Même pays, ville différente → directement Hors zone
            if (sameCountry) {
              isOut = true;
            } else if (userCountryText != null && rCountryText != null) {
              // Pays différents → directement Hors zone
              isOut = true;
            }
          }
        }

        // 3) Sinon (ou pour confirmer) : distance à vol d'oiseau vs rayon livraison
        if (!isOut && userLat != null && userLon != null) {
          final rLat = r.latitude ??
              (rAddr != null ? double.tryParse(rAddr.lat ?? '') : null);
          final rLon = r.longitude ??
              (rAddr != null ? double.tryParse(rAddr.long ?? '') : null);
          if (rLat != null && rLon != null) {
            final maxKm = r.deliveryRadius > 0 ? r.deliveryRadius : 10.0;
            if (_haversine(userLat, userLon, rLat, rLon) > maxKm) {
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

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    // Suppression des accents courants (FR/EN/ES/PT)
    const accents = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ç': 'c',
      'ñ': 'n',
    };
    final buf = StringBuffer();
    for (final r in v.runes) {
      final ch = String.fromCharCode(r);
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _filterByCategory() {
    if (_selectedCategoryIndex == 0) {
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
        final liveCity = _firstNonEmpty(
            [p.locality, p.subAdministrativeArea, p.administrativeArea]);
        final liveCountry = _firstNonEmpty([p.country, p.isoCountryCode]);
        if (mounted) {
          bool needsRetag = false;
          if (addr.isNotEmpty && _liveAddress != addr) {
            setState(() => _liveAddress = addr);
          }
          if (liveCity != null && _liveCity != liveCity) {
            _liveCity = liveCity;
            needsRetag = true;
          }
          if (liveCountry != null && _liveCountry != liveCountry) {
            _liveCountry = liveCountry;
            needsRetag = true;
          }
          if (needsRetag) {
            await _tagOutOfRangeAndSort();
          }
        }
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

  bool _hasUserAddress() {
    return _addresses.any((a) =>
        a.objectID == _currentUserID &&
        (a.object == 'User' || a.object == 'Livraison'));
  }

  bool _hasLiveLocation() {
    final city = _liveCity;
    final country = _liveCountry;
    final address = _liveAddress;
    return ((city != null && city.trim().isNotEmpty) ||
            (address != null && address.trim().isNotEmpty)) &&
        (country != null && country.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showAddressBanner =
        _currentUserRole == 2 && !_hasUserAddress() && !_hasLiveLocation();
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
                if (showAddressBanner)
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
                    onSeeAll: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => FoodCategories())),
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
// _HomeHeader
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
                  child: GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: brandColor, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            addressLabel ?? l10n.home_nearby,
                            style: AppTypography.titleLarge(
                                    color: colorScheme.onSurface)
                                .copyWith(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: colorScheme.onSurface.withOpacity(0.5),
                            size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
// _WelcomeBanner
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
// _RoundCategories
// ═══════════════════════════════════════════════════════════
class _RoundCategories extends StatelessWidget {
  const _RoundCategories({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSeeAll,
  });

  final List<_Category> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    final visibleCount = categories.length > 7 ? 7 : categories.length;
    final tileCount = visibleCount + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
          child: Text(l10n.home_categories,
              style: AppTypography.titleMedium(color: colorScheme.onSurface)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tileCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (_, i) {
              final isMore = i == visibleCount;

              if (isMore) {
                return GestureDetector(
                  onTap: onSeeAll,
                  child: Container(
                    decoration: BoxDecoration(
                      color: resolvedBrand,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: resolvedBrand.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          'Plus',
                          style: AppTypography.labelMedium(color: Colors.white)
                              .copyWith(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final selected = i == selectedIndex;
              final cat = categories[i];
              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  decoration: BoxDecoration(
                    color: selected ? resolvedBrand : card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: selected
                          ? resolvedBrand
                          : border.withValues(alpha: 0.6),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: resolvedBrand.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [AppShadows.subtle],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat.icon,
                        size: 22,
                        color: selected ? Colors.white : inkMuted,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          cat.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium(
                            color: selected ? Colors.white : inkMuted,
                          ).copyWith(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
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
  }) : topPadding = AppSpacing.xl;

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, topPadding, AppSpacing.lg, AppSpacing.md),
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
// _RestaurantCarousel — REDESIGNÉ
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
      // ── Hauteur augmentée pour accueillir les cards plus grandes ──
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Padding latéral cohérent avec le reste de la page
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 8,
        ),
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

// ═══════════════════════════════════════════════════════════
// _RestaurantCard
// ═══════════════════════════════════════════════════════════
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBrand =
        AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final resolvedAccent =
        AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final resolvedSuccess =
        AppColors.resolve(AppColors.success, AppDarkColors.success);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final surfaceWarm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

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
    final isFreeDelivery = widget.restaurant.deliveryFee <= 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: border.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: inkColor.withValues(alpha: 0.06),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: inkColor.withValues(alpha: 0.03),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ════════════════════════════════════════════
            // BLOC IMAGE — occupe bien toute la largeur
            // ════════════════════════════════════════════
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  // Image principale
                  SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Opacity(
                      opacity: widget.outOfRange
                          ? 0.55
                          : (restaurantClosed ? 0.75 : 1.0),
                      child: ColorFiltered(
                        colorFilter: widget.outOfRange
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
                          url: widget.restaurant.image,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Dégradé bas (pour lisibilité des badges)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
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
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_off_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
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

                  // Overlay restaurant fermé
                  if (!widget.outOfRange && restaurantClosed)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: Colors.black.withValues(alpha: 0.32),
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

                  // ── Badge note ──────────────────────────
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: resolvedAccent, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            widget.restaurant.note > 0
                                ? widget.restaurant.note.toStringAsFixed(1)
                                : '—',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B211D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Bouton favori ───────────────────────
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x20000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: resolvedBrand,
                        ),
                      ),
                    ),
                  ),

                  // ── Badge PRO ────────────────────────────
                  if (widget.isPro)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: resolvedAccent,
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
                ],
              ),
            ),

            // ════════════════════════════════════════════
            // BLOC TEXTE — informations du restaurant
            // ════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom du restaurant
                  Text(
                    widget.restaurant.name,
                    style: AppTypography.titleMedium(color: titleColor)
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Horaires + frais de livraison
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.40),
                          size: 12),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          restaurantClosed
                              ? openingMessage
                              : widget.restaurant.openingHours.isNotEmpty
                                  ? widget.restaurant.openingHours
                                  : l10n.home_contact,
                          style: AppTypography.labelMedium(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.50),
                          ).copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pill livraison
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFreeDelivery
                              ? resolvedSuccess.withValues(alpha: 0.12)
                              : surfaceWarm,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isFreeDelivery
                              ? l10n.home_delivery_fee_label('0')
                              : l10n.home_delivery_fee_label(widget
                                  .restaurant.deliveryFee
                                  .toStringAsFixed(0)),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isFreeDelivery
                                ? resolvedSuccess
                                : inkColor.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tags catégories
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: surfaceWarm,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: inkColor.withValues(alpha: 0.55),
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
// _RestaurantSkeleton — REDESIGNÉ (cohérent avec nouvelle card)
// ═══════════════════════════════════════════════════════════
class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surfaceWarm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 8,
        ),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 220,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: border.withValues(alpha: 0.5),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: surfaceWarm,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimmerBar(width: 140, height: 13),
                    SizedBox(height: 10),
                    _ShimmerBar(width: 100, height: 10),
                    SizedBox(height: 10),
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

// ═══════════════════════════════════════════════════════════
// _ShimmerBar
// ═══════════════════════════════════════════════════════════
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
