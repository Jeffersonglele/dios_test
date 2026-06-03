import 'package:flutter/material.dart';
import '../Controller/UiController.dart';
import '../modeles/dish.dart';
import '../modeles/restaurant.dart';
import 'restaurants/RestaurantDetails.dart';
import 'authentification/Login.dart';
import 'authentification/Signup.dart';

class GuestBrowsePage extends StatefulWidget {
  const GuestBrowsePage({super.key});

  @override
  State<GuestBrowsePage> createState() => _GuestBrowsePageState();
}

class _GuestBrowsePageState extends State<GuestBrowsePage> {
  List<Restaurant> restaurants = [];
  Map<int, List<Dish>> dishesByRestaurant = {};
  bool isLoading = true;
  String? _selectedCategory;
  double? _minRating;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final restos = await Restaurant.fetchRestaurantsFromDB();
    final allDishes = await Dish.fetchDishesFromDB();
    final grouped = <int, List<Dish>>{};
    for (final resto in restos) {
      grouped[resto.restaurantID] =
          allDishes.where((d) => d.restauID == resto.restaurantID).toList();
    }
    if (!mounted) return;
    setState(() {
      restaurants = restos;
      dishesByRestaurant = grouped;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Dios Délices'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Login()),
            ),
            child:
                const Text('Connexion', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SignUpView()),
            ),
            child: const Text('S\'inscrire',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildFilterChips(),
                  Expanded(
                    child: restaurants.isEmpty
                        ? const Center(
                            child: Text('Aucun restaurant disponible.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: restaurants.length,
                            itemBuilder: (ctx, i) {
                              final resto = restaurants[i];
                              final dishes =
                                  dishesByRestaurant[resto.restaurantID] ?? [];
                              return _RestaurantCard(
                                restaurant: resto,
                                dishCount: dishes.length,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RestaurantDetails(
                                      restaurant_id: resto.restaurantID,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tout'),
            selected: _selectedCategory == null && _minRating == null,
            onSelected: (_) => setState(() {
              _selectedCategory = null;
              _minRating = null;
            }),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('⭐ 4+'),
            selected: _minRating == 4,
            onSelected: (_) =>
                setState(() => _minRating = _minRating == 4 ? null : 4),
          ),
          const SizedBox(width: 6),
          ...[
            '#africain',
            '#européen',
            '#asiatique',
            '#végétarien',
            '#fast-food',
            '#dessert'
          ].map((cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: _selectedCategory == cat,
                  onSelected: (_) => setState(() {
                    _selectedCategory = _selectedCategory == cat ? null : cat;
                  }),
                ),
              )),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final int dishCount;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    required this.dishCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepOrange.shade50,
                radius: 30,
                child: const Icon(Icons.restaurant,
                    color: Colors.deepOrange, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                            5,
                            (i) => Icon(
                                  i < restaurant.note.toInt()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                )),
                        const SizedBox(width: 6),
                        Text('$dishCount plats',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        const Spacer(),
                        Text(
                            '${restaurant.deliveryFee.toStringAsFixed(0)}€ livraison',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
