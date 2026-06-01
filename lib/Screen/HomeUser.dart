import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../SearchInput.dart';
import '../core/app_role.dart';
import '../modeles/address.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/DateTime.dart';
import 'FoodCategories.dart';
import 'NearMeMeals.dart';
import 'restaurants/NearMeRestaurants.dart';
import 'restaurants/RestaurantDetails.dart';

class HomeUser extends StatefulWidget {
  const HomeUser({super.key});

  @override
  State<HomeUser> createState() => _HomeUserState();
}

class _HomeUserState extends State<HomeUser> {
  List<Users> users = [];
  List<Restaurant> restaus = [];
  List<Address> addresses = [];

  int current_userID = 0;
  int current_user_role = 0;
  int current_user_restau = 0;

  String? _selectedCategory;
  double? _maxPrice;
  double? _minRating;
  int _excludedCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final session = await SessionService.readSession();
    final usersList = await Users.fetchUsersFromDB();
    final restausList = await Restaurant.fetchRestaurantsFromDB();
    final addressesList = await Address.fetchAddressesFromDB();

    if (!mounted) return;
    setState(() {
      current_userID = session.userId;
      current_user_role = session.role.id;
      current_user_restau = session.restaurantId ?? 0;
      users = usersList;
      restaus = restausList;
      addresses = addressesList;
    });
    await _filterRestaurants();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _filterRestaurants() async {
    for (var a in addresses) {
      if (a.objectID == current_userID && a.object == "User") {
        const double maxDistanceKm = 10.0;
        final List<Restaurant> nearby = [];
        int excluded = 0;

        for (var restau in restaus) {
          final associatedUser = Users.getUsersByUserId(users, restau.userID);
          if (associatedUser == null || restau.userID == current_userID) continue;

          final restauAddr =
              Address.getAddressByObject(addresses, "User", restau.userID);
          if (restauAddr == null) {
            excluded++;
            continue;
          }

          try {
            final userLat = double.parse(a.lat ?? "");
            final userLon = double.parse(a.long ?? "");
            final restauLat = double.parse(restauAddr.lat ?? "");
            final restauLon = double.parse(restauAddr.long ?? "");
            final distance =
                _calculateDistance(userLat, userLon, restauLat, restauLon);
            if (distance <= maxDistanceKm) nearby.add(restau);
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            restaus = nearby;
            _excludedCount = excluded;
            _totalCount = nearby.length + excluded;
          });
        }
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: RefreshIndicator(
            color: AppColors.brand,
            backgroundColor: AppColors.card,
            onRefresh: loadData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header : date + recherche ─────────────
                SliverToBoxAdapter(
                  child: _buildHeader(size),
                ),
                // ── Catégories chips ───────────────────────
                SliverToBoxAdapter(
                  child: _buildCategoryChips(),
                ),
                // ── Restaurants proches ────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    'Restaurants près de chez vous',
                    actionText: 'Voir plus',
                    onTap: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => const NearMeRestaurants())),
                  ),
                ),
                if (_excludedCount > 0)
                  SliverToBoxAdapter(child: _buildExcludedBanner()),
                if (_isLoading)
                  const SliverToBoxAdapter(child: _RestaurantSkeleton()),
                if (restaus.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildRestaurantCarousel(size),
                  ),
                // ── Plats populaires ───────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    'Plats près de chez vous',
                    actionText: 'Voir plus',
                    onTap: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => const NearMeMeals())),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildCategoryButton(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader(Size size) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Localisation + Avatar
          Row(
            children: [
              // Icône localisation avec badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.brand, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'À proximité',
                      style: AppTypography.labelMedium(color: AppColors.ink),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.inkMuted, size: 18),
                  ],
                ),
              ),
              const Spacer(),
              // Avatar
              GestureDetector(
                onTap: () {
                  // Navigation vers profil
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandSurface,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.brand, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Titre
          RichText(
            text: TextSpan(
              style: AppTypography.headlineLarge(),
              children: const [
                TextSpan(text: 'Bon appétit '),
                TextSpan(
                  text: '!',
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Découvrez les meilleurs plats faits maison',
            style: AppTypography.bodyMedium(),
          ),
          // Barre de recherche
          const SizedBox(height: 12),
          const SearchInput(),
        ],
      ),
    );
  }

  // ── Catégories ──────────────────────────────────────────
  Widget _buildCategoryChips() {
    final categories = [
      {'icon': Icons.restaurant_rounded, 'label': 'Tout'},
      {'icon': Icons.star_rounded, 'label': '⭐ 4+'},
      {'icon': Icons.euro_rounded, 'label': '-10€'},
      {'icon': Icons.language_rounded, 'label': '#africain'},
      {'icon': Icons.eco_rounded, 'label': '#végétarien'},
      {'icon': Icons.cake_rounded, 'label': '#dessert'},
      {'icon': Icons.fastfood_rounded, 'label': '#fast-food'},
      {'icon': Icons.ramen_dining_rounded, 'label': '#asiatique'},
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = index == 0 &&
              _selectedCategory == null &&
              _maxPrice == null &&
              _minRating == null;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedCategory = null;
              _maxPrice = null;
              _minRating = null;
            }),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brand : AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.border.withValues(alpha: 0.6),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: AppTypography.labelMedium(
                      color: isSelected ? Colors.white : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Titre de section ────────────────────────────────────
  Widget _buildSectionTitle(String title,
      {String? actionText, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTypography.titleMedium()),
          ),
          if (actionText != null && onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  actionText,
                  style: AppTypography.labelMedium(color: AppColors.brand),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bannière exclus ─────────────────────────────────────
  Widget _buildExcludedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_excludedCount restaurant(s) hors zone de livraison sur $_totalCount.',
              style: AppTypography.labelMedium(color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carrousel restaurants ───────────────────────────────
  Widget _buildRestaurantCarousel(Size size) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: restaus.length > 6 ? 6 : restaus.length,
        itemBuilder: (context, index) {
          return _buildRestaurantCard(restaus[index], index);
        },
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, int index) {
    final associatedUser = Users.getUsersByUserId(users, restaurant.userID);
    final isPro = associatedUser != null &&
        AppRole.fromId(associatedUser.roleID) == AppRole.microRestaurant;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              RestaurantDetails(restaurant_id: restaurant.restaurantID),
        ),
      ),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de couverture
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.network(
                    (restaurant.image != null &&
                            restaurant.image!.trim().isNotEmpty)
                        ? restaurant.image!
                        : "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/no_image.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Overlay dégradé en bas de l'image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.ink.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Badge note
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.accent, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '4.5',
                          style: AppTypography.labelMedium(
                            color: AppColors.ink,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge PRO
                if (isPro)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppTypography.titleMedium().copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: AppColors.inkSubtle, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '20-30 min',
                        style: AppTypography.labelMedium(
                          color: AppColors.inkSubtle,
                        ).copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.delivery_dining_rounded,
                          color: AppColors.inkSubtle, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '3,90 €',
                        style: AppTypography.labelMedium(
                          color: AppColors.inkSubtle,
                        ).copyWith(fontSize: 11),
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

  // ── Bouton catégories ───────────────────────────────────
  Widget _buildCategoryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              CupertinoPageRoute(builder: (_) => FoodCategories())),
          icon: const Icon(Icons.grid_view_rounded, size: 20),
          label: const Text('Explorer toutes les catégories'),
        ),
      ),
    );
  }
}

// ── Skeleton Loader chaleureux ──────────────────────────────
class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBar(width: 140, height: 14),
                      SizedBox(height: 10),
                      _ShimmerBar(width: 100, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.surfaceWarm,
            AppColors.border,
            _controller.value,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
