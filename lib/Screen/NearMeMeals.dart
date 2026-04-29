import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/services/nearby_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NearMeMeals extends StatefulWidget {
  const NearMeMeals({super.key});

  @override
  State<NearMeMeals> createState() => _NearMeMealsState();
}

class _NearMeMealsState extends State<NearMeMeals> {
  final TextEditingController _searchController = TextEditingController();
  List<NearbyDishResult> _allDishes = [];
  List<NearbyDishResult> _visibleDishes = [];
  bool _isLoading = true;
  bool _openRestaurantsOnly = false;
  double _maxDistanceKm = 10;

  @override
  void initState() {
    super.initState();
    _loadNearbyDishes();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyDishes() async {
    setState(() {
      _isLoading = true;
    });

    final dishes = await NearbyService.getNearbyDishes(
      maxDistanceKm: _maxDistanceKm,
      openRestaurantsOnly: _openRestaurantsOnly,
    );

    if (!mounted) return;
    setState(() {
      _allDishes = dishes;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _allDishes.where((result) {
      final haystack =
          '${result.dish.name} ${result.dish.categories} ${result.restaurant.name}'
              .toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    if (!mounted) return;
    setState(() {
      _visibleDishes = filtered;
    });
  }

  Future<void> _updateDistance(double distanceKm) async {
    setState(() {
      _maxDistanceKm = distanceKm;
    });
    await _loadNearbyDishes();
  }

  Future<void> _updateOpenOnly(bool value) async {
    setState(() {
      _openRestaurantsOnly = value;
    });
    await _loadNearbyDishes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plats à proximité'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNearbyDishes,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un plat ou un restaurant',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
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
                _FilterChip(
                  label: '5 km',
                  selected: _maxDistanceKm == 5,
                  onTap: () => _updateDistance(5),
                ),
                _FilterChip(
                  label: '10 km',
                  selected: _maxDistanceKm == 10,
                  onTap: () => _updateDistance(10),
                ),
                _FilterChip(
                  label: '20 km',
                  selected: _maxDistanceKm == 20,
                  onTap: () => _updateDistance(20),
                ),
                FilterChip(
                  label: const Text('Restos ouverts'),
                  selected: _openRestaurantsOnly,
                  onSelected: _updateOpenOnly,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_visibleDishes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text('Aucun plat trouvé avec ces filtres.'),
                ),
              )
            else
              ..._visibleDishes.map(
                (result) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: _DishAvatar(imageUrl: result.dish.image),
                    title: Text(
                      result.dish.name ?? 'Plat',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(result.restaurant.name),
                        Text(
                          '${result.distanceKm.toStringAsFixed(2)} km | ${result.dish.nb_servings ?? 0} portions',
                        ),
                        Text(
                          '${result.dish.price?.toStringAsFixed(2) ?? '0.00'} | ${result.dish.categories ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => DishDetails(
                            from_page: 0,
                            dish_id: result.dish.dishID,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _DishAvatar extends StatelessWidget {
  const _DishAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    if (!hasImage) {
      return const CircleAvatar(
        radius: 28,
        child: Icon(Icons.restaurant_menu),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundImage: NetworkImage(imageUrl!),
      onBackgroundImageError: (_, __) {},
      child: hasImage ? null : const Icon(Icons.restaurant_menu),
    );
  }
}
