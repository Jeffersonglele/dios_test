import 'dart:math';

import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/screens/profile/location_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_cache_service.dart';

import '../../constants/constant.dart';
import '../../controllers/ui_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/country_util.dart';
import '../../core/app_role.dart';
import '../../models/address.dart';
import '../../models/category.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../services/session_service.dart';
import '../../services/node_home_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_widgets.dart';
import '../explore/food_categories.dart';
import '../wallet/wallet_screen.dart';
import 'near_me_meals.dart';
import '../restaurants/near_me_restaurants.dart';
import '../restaurants/restaurant_details.dart';


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
  bool _firstLoadDone = false;

  String _liveAddress = '';
  String? _liveCity;
  String? _liveCountry;
  List<HomeCategory> _categories = [
    HomeCategory(icon: Icons.restaurant_rounded, label: 'Tout'),
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
      final restaus = nodeHome.restaurants.where((r) => r.valid == 1).toList();
      final addrs = nodeHome.addresses;
      final cats = nodeHome.categories;

      // Récupération des utilisateurs locaux pour conserver les images base64
      final localUsers = await Users.fetchUsersFromDB();
      var nodeUser = nodeHome.user;
      if (nodeUser != null) {
        final idx = localUsers.indexWhere((lu) => lu.userID == nodeUser!.userID);
        if (idx >= 0) {
          // Toujours utiliser l'image locale (comme dans profile_page.dart)
          // car le backend Node peut renvoyer une image vide ou invalide.
          nodeUser = nodeUser.copy(image: localUsers[idx].image);
          localUsers[idx] = nodeUser;
        } else {
          localUsers.add(nodeUser);
        }
      }

      setState(() {
        _currentUserID = nodeUser?.userID ?? session.userId;
        _currentUserRole = nodeUser?.roleID ?? session.role.id;
        _currentUserRestau = session.restaurantId ?? 0;
        _users = localUsers;
        _allRestaus = restaus;
        _addresses = addrs;
        _categories = [
          HomeCategory(icon: Icons.restaurant_rounded, label: 'Tout'),
          ...cats.map((c) =>
              HomeCategory(icon: _iconForCategory(c.name), label: c.name)),
        ];
        _isLoading = false;
        _firstLoadDone = true;
      });
      await _tagOutOfRangeAndSort();
      _detectLiveLocation();
      return;
    }

    List<dynamic> results;
    try {
      results = await Future.wait([
        Users.fetchUsersFromDB(),
        Restaurant.fetchRestaurantsFromDB(),
        Address.fetchAddressesFromDB(),
        CategoryService.getAllCategories(),
      ]);
    } catch (e) {
      debugPrint('⚠️ Home fallback load FAILED: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _firstLoadDone = true; // évite un skeleton infini
        });
      }
      return;
    }
    final usersList = results[0] as List<Users>;
    final restausList =
        (results[1] as List<Restaurant>).where((r) => r.valid == 1).toList();
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
        HomeCategory(icon: Icons.restaurant_rounded, label: 'Tout'),
        ...dbCats.map((c) =>
            HomeCategory(icon: _iconForCategory(c.name), label: c.name)),
      ];
      _isLoading = false;
      _firstLoadDone = true;
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
    final userCountryRaw = _firstNonEmpty([
      userAddress?.state,
      _liveCountry,
    ]);
    final userCountryText = CountryUtil.canonical(userCountryRaw).isNotEmpty
        ? CountryUtil.canonical(userCountryRaw)
        : _normalize(userCountryRaw);
    final cachedPos = LocationCacheService.instance.cachedPosition;
    final userLat =
        double.tryParse(userAddress?.lat ?? '') ?? cachedPos?.latitude;
    final userLon =
        double.tryParse(userAddress?.long ?? '') ?? cachedPos?.longitude;

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
        final rCountryRaw = _firstNonEmpty([
          r.country,
          rAddr?.state,
        ]);
        final rCountryText = CountryUtil.canonical(rCountryRaw).isNotEmpty
            ? CountryUtil.canonical(rCountryRaw)
            : _normalize(rCountryRaw);

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
      final cache = LocationCacheService.instance;
      // Appliquer immédiatement si déjà disponible en cache
      if (cache.cachedPosition != null) {
        _applyCachedLocation(cache);
      }

      final pos = await cache.getPosition();
      if (pos == null || !mounted) return;

      _applyCachedLocation(cache);
    } catch (_) {}
  }

  void _applyCachedLocation(LocationCacheService cache) {
    if (!mounted) return;
    bool needsRetag = false;
    final addr = cache.cachedDisplayName;
    final liveCity = cache.cachedCity;
    final liveCountry = cache.cachedCountry;

    if (addr != null && addr.isNotEmpty && _liveAddress != addr) {
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
      _tagOutOfRangeAndSort();
    }
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
            address.trim().isNotEmpty) &&
        (country != null && country.trim().isNotEmpty);
  }

  final GlobalKey<HomeWalletBannerState> _walletBannerKey = GlobalKey();

  void _openWallet({bool topUp = false}) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => WalletScreen(openTopUpOnStart: topUp),
      ),
    ).then((_) => _walletBannerKey.currentState?.refresh());
  }

  Widget _buildContent(AppLocalizations l10n, bool showAddressBanner) {
    return RefreshIndicator(
      key: const ValueKey('home_content'),
      color: HC.brand,
      backgroundColor: HC.card,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── Bannière adresse manquante ───────────
          if (showAddressBanner)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => _addAddress(),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0xFFBE3A34)),
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
            child: HomeReveal(
              child: HomeHeader(
                currentUser: Users.getUsersByUserId(_users, _currentUserID),
                addressLabel: _liveAddress.isNotEmpty ? _liveAddress : null,
                onTap: () => _addAddress(),
              ),
            ),
          ),

          // ── Bannière de bienvenue ────────────────
          const SliverToBoxAdapter(
            child: HomeReveal(index: 1, child: HomeWelcomeBanner()),
          ),

          // ── Bannière Wallet ──────────────────────
          SliverToBoxAdapter(
            child: HomeReveal(
              index: 2,
              child: HomeWalletBanner(
                key: _walletBannerKey,
                onTap: () => _openWallet(),
                onAdd: () => _openWallet(topUp: true),
              ),
            ),
          ),

          // ── Catégories rondes ─────────────────────
          SliverToBoxAdapter(
            child: HomeReveal(
              index: 3,
              child: HomeRoundCategories(
                categories: _categories,
                selectedIndex: _selectedCategoryIndex,
                onSelect: (i) {
                  setState(() => _selectedCategoryIndex = i);
                  _filterByCategory();
                },
                onSeeAll: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const FoodCategories())),
              ),
            ),
          ),

          // ── Section restaurants ──────────────────
          SliverToBoxAdapter(
            child: HomeSectionHeader(
              title: l10n.home_top_picks,
              actionLabel: l10n.home_see_all,
              onAction: () => Navigator.push(context,
                  CupertinoPageRoute(builder: (_) => const NearMeRestaurants())),
            ),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const HomeRestaurantSkeleton()
                : _restaus.isEmpty
                    ? const HomeEmptyRestaurants()
                    : HomeReveal(
                        index: 3,
                        child: HomeRestaurantCarousel(
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
          ),

          // ── Section plats ────────────────────────
          SliverToBoxAdapter(
            child: HomeSectionHeader(
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
    );
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
          // Skeleton au premier chargement, puis fondu vers le vrai contenu.
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            child: _firstLoadDone
                ? _buildContent(l10n, showAddressBanner)
                : const HomeSkeleton(key: ValueKey('home_skeleton')),
          ),
        ),
      ),
    );
  }
}