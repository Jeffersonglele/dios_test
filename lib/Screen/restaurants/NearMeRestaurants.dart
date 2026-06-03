import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/services/nearby_service.dart';
import 'package:dios_delices/modeles/users.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Restaurants à proximité',
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
                hintText: 'Rechercher un restaurant ou une cuisine',
                hintStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                FilterChip(
                  label: Text('Ouverts maintenant',
                      style: TextStyle(
                          color: _openOnly
                              ? Colors.white
                              : colorScheme.onSurface)),
                  selected: _openOnly,
                  selectedColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  checkmarkColor: Colors.white,
                  onSelected: _updateOpenOnly,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Center(
                  child: CircularProgressIndicator(
                      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)))
            else if (_visibleRestaurants.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text('Aucun restaurant trouvé avec ces filtres.',
                      style: TextStyle(color: colorScheme.onSurface)),
                ),
              )
            else
              ..._visibleRestaurants.map(
                (result) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading:
                        _RestaurantAvatar(imageUrl: result.restaurant.image),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.restaurant.name,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface),
                          ),
                        ),
                        if (_isProRestaurant(result.restaurant.userID))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 12,
                                    color: AppColors.resolve(AppColors.accent, AppDarkColors.accent)),
                                const SizedBox(width: 2),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('${result.distanceKm.toStringAsFixed(2)} km',
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.7))),
                        Text(
                          result.restaurant.categories.isEmpty
                              ? result.restaurant.openingHours
                              : result.restaurant.categories,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        Text(
                          'Livraison ${result.restaurant.deliveryFee.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          result.restaurant.isCurrentlyOpen
                              ? Icons.check_circle
                              : Icons.remove_circle,
                          color: result.restaurant.isCurrentlyOpen
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.restaurant.isCurrentlyOpen
                              ? 'Ouvert'
                              : 'Fermé',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
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
                  ),
                ),
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
      selectedColor:
          AppColors.resolve(AppColors.brand, AppDarkColors.brand),
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
