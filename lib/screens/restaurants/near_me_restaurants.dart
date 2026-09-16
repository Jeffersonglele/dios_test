import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/nearby_service.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NearMeRestaurants extends StatefulWidget {
  const NearMeRestaurants({super.key});

  @override
  State<NearMeRestaurants> createState() => _NearMeRestaurantsState();
}

class _NearMeRestaurantsState extends State<NearMeRestaurants> {
  final TextEditingController _searchController = TextEditingController();
  List<NearbyRestaurantResult> _allRestaurants = [];
  List<NearbyRestaurantResult> _visibleRestaurants = [];
  List<Users> _users = [];
  bool _isLoading = true;
  bool _openOnly = false;
  double _maxDistanceKm = 10;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isProRestaurant(int userID) {
    final user = Users.getUsersByUserId(_users, userID);
    return user != null &&
        AppRole.fromId(user.roleID) == AppRole.microRestaurant;
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
    });

    final restaurants = await NearbyService.getNearbyRestaurants(
      maxDistanceKm: _maxDistanceKm,
      openOnly: _openOnly,
    );

    final usersList = await Users.fetchUsersFromDB();

    if (!mounted) return;
    setState(() {
      _allRestaurants = restaurants;
      _users = usersList;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allRestaurants.where((result) {
      final restaurant = result.restaurant;
      final haystack =
          '${restaurant.name} ${restaurant.categories} ${restaurant.description}'
              .toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    if (!mounted) return;
    setState(() {
      _visibleRestaurants = filtered;
    });
  }

  Future<void> _updateDistance(double distanceKm) async {
    setState(() {
      _maxDistanceKm = distanceKm;
    });
    await _loadRestaurants();
  }

  Future<void> _updateOpenOnly(bool value) async {
    setState(() {
      _openOnly = value;
    });
    await _loadRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.near_restaurants_title,
            style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRestaurants,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextField(
              controller: _searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: l10n.near_restaurants_search_hint,
                hintStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor:
                    AppColors.resolve(AppColors.card, AppDarkColors.card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                          AppColors.brandSurface, AppDarkColors.brandSurface)
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                            .withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _visibleRestaurants.where((r) => r.isOutOfRange).isEmpty
                            ? '${_visibleRestaurants.length} restaurants dans le rayon'
                            : '${_visibleRestaurants.where((r) => !r.isOutOfRange).length} en livraison • ${_visibleRestaurants.where((r) => r.isOutOfRange).length} hors portée',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isLoading) const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2, left: 4),
                  child: Text(
                    'Rayon :',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                _DistanceChip(
                  label: '5 km',
                  selected: _maxDistanceKm == 5,
                  onTap: () => _updateDistance(5),
                ),
                _DistanceChip(
                  label: '10 km',
                  selected: _maxDistanceKm == 10,
                  onTap: () => _updateDistance(10),
                ),
                _DistanceChip(
                  label: '20 km',
                  selected: _maxDistanceKm == 20,
                  onTap: () => _updateDistance(20),
                ),
                const SizedBox(width: 2),
                FilterChip(
                  label: Text(l10n.near_restaurants_open_now,
                      style: TextStyle(
                          color: _openOnly
                              ? Colors.white
                              : colorScheme.onSurface)),
                  selected: _openOnly,
                  selectedColor:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  checkmarkColor: Colors.white,
                  onSelected: _updateOpenOnly,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(
                  child: CircularProgressIndicator(
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand)))
            else if (_visibleRestaurants.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(l10n.near_restaurants_no_results,
                      style: TextStyle(color: colorScheme.onSurface)),
                ),
              )
            else
              ..._visibleRestaurants.map(
                (result) {
                  final outOfRange = result.isOutOfRange;
                  final brandColor =
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
                  final dangerColor = AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkSubtle);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    color:
                        AppColors.resolve(AppColors.card, AppDarkColors.card),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: outOfRange
                          ? BorderSide(
                              color: colorScheme.onSurface.withOpacity(0.08),
                              width: 1)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantDetails(
                              restaurant_id: result.restaurant.restaurantID,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _RestaurantAvatar(
                                    imageUrl: result.restaurant.image),
                                if (outOfRange)
                                  Positioned(
                                    right: -6,
                                    bottom: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.resolve(
                                            AppColors.inkSubtle,
                                            AppDarkColors.ink),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.resolve(
                                              AppColors.card,
                                              AppDarkColors.card),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.location_off_rounded,
                                              color: Colors.white, size: 11),
                                          const SizedBox(width: 3),
                                          const Text(
                                            'Hors portée',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          result.restaurant.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: outOfRange
                                                ? colorScheme.onSurface
                                                    .withValues(alpha: 0.7)
                                                : colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (result.restaurant.isPro)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.resolve(
                                                AppColors.accentLight,
                                                AppDarkColors.accentLight),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified,
                                                  size: 12,
                                                  color: AppColors.resolve(
                                                      AppColors.accent,
                                                      AppDarkColors.accent)),
                                              const SizedBox(width: 2),
                                              Text(
                                                'PRO',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.resolve(
                                                      AppColors.accent,
                                                      AppDarkColors.accent),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.near_me_rounded,
                                        size: 13,
                                        color: outOfRange
                                            ? dangerColor
                                            : brandColor.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${result.distanceKm.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: outOfRange
                                                ? dangerColor
                                                : colorScheme.onSurface
                                                    .withOpacity(0.75)),
                                      ),
                                      if (outOfRange) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Livraison indisponible',
                                          style: TextStyle(
                                              fontSize: 11, color: dangerColor),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    result.restaurant.categories.isEmpty
                                        ? result.restaurant.openingHours
                                        : result.restaurant.categories,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.65)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Livraison ${result.restaurant.deliveryFee.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: outOfRange
                                            ? colorScheme.onSurface
                                                .withValues(alpha: 0.45)
                                            : brandColor,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  result.restaurant.isCurrentlyOpen
                                      ? Icons.check_circle
                                      : Icons.remove_circle,
                                  color: result.restaurant.isCurrentlyOpen
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  result.restaurant.isCurrentlyOpen
                                      ? l10n.open
                                      : l10n.closed,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : colorScheme.onSurface)),
      selected: selected,
      selectedColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      checkmarkColor: Colors.white,
      onSelected: (_) => onTap(),
    );
  }
}

class _RestaurantAvatar extends StatelessWidget {
  const _RestaurantAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    if (!hasImage) {
      return const CircleAvatar(
        radius: 28,
        child: Icon(Icons.storefront),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage(imageUrl!),
      onBackgroundImageError: (_, __) {},
      child: hasImage ? null : const Icon(Icons.storefront),
    );
  }
}
