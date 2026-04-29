import 'package:dios_delices/Screen/UserOrdersPage.dart';
import 'package:dios_delices/Screen/dish/DishFormPage.dart';
import 'package:dios_delices/Screen/micro_restau/DishDetailsMicroRestau.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/ligne_commande.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeMicroRestau extends StatefulWidget {
  const HomeMicroRestau({super.key});

  @override
  State<HomeMicroRestau> createState() => _HomeMicroRestauState();
}

class _HomeMicroRestauState extends State<HomeMicroRestau> {
  bool isLoading = true;
  Restaurant? restaurant;
  List<Dish> dishes = [];
  List<Commande> commandes = [];
  int pendingOrders = 0;
  int confirmedOrders = 0;
  int availableDishes = 0;
  int unavailableDishes = 0;
  int totalAvailableServings = 0;
  int soldServings = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      isLoading = true;
    });

    final session = await SessionService.readSession();

    if (session.restaurantId == null) {
      if (!mounted) return;
      setState(() {
        restaurant = null;
        dishes = [];
        commandes = [];
        pendingOrders = 0;
        confirmedOrders = 0;
        availableDishes = 0;
        unavailableDishes = 0;
        totalAvailableServings = 0;
        soldServings = 0;
        isLoading = false;
      });
      return;
    }

    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final allDishes = await Dish.fetchDishesFromDB();
    final allCommandes = await Commande.fetchCommandesFromDB();
    final allLignes = await LigneCommande.fetchLignesCommandeFromDB();

    final currentRestaurant =
        Restaurant.getRestaurantByRestaurantId(restaurants, session.restaurantId!);
    final restaurantDishes = allDishes
        .where((dish) => dish.restauID == session.restaurantId)
        .toList()
      ..sort((a, b) => (b.nb_orders).compareTo(a.nb_orders));

    final restaurantCommandes = allCommandes
        .where((commande) => commande.restaurateurID == session.userId)
        .toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    final commandeIds = restaurantCommandes
        .map((commande) => commande.commandeID.toString())
        .toSet();

    final totalSoldServings = allLignes
        .where((ligne) => commandeIds.contains(ligne.commandeID))
        .fold<int>(0, (sum, ligne) => sum + ligne.quantite);

    if (!mounted) return;
    setState(() {
      restaurant = currentRestaurant;
      dishes = restaurantDishes;
      commandes = restaurantCommandes;
      pendingOrders = restaurantCommandes
          .where((commande) => CommandeStatus.isPending(commande.status))
          .length;
      confirmedOrders = restaurantCommandes
          .where(
            (commande) =>
                CommandeStatus.normalize(commande.status) ==
                CommandeStatus.confirmed,
          )
          .length;
      availableDishes =
          restaurantDishes.where((dish) => (dish.status ?? 0) == 1).length;
      unavailableDishes =
          restaurantDishes.where((dish) => (dish.status ?? 0) != 1).length;
      totalAvailableServings = restaurantDishes.fold<int>(
        0,
        (sum, dish) => sum + ((dish.nb_servings ?? 0) > 0 ? dish.nb_servings! : 0),
      );
      soldServings = totalSoldServings;
      isLoading = false;
    });
  }

  Future<void> _refreshRemoteData() async {
    await Restaurant.getAllRestaurantsDetails();
    await Dish.getAllDishesDetails();
    await Commande.getAllCommandes();
    await LigneCommande.getAllLignesCommande();
    await _loadDashboard();
  }

  Future<void> _toggleDishAvailability(Dish dish, bool isAvailable) async {
    final result = await Dish.updateDishStatus(dish.dishID, isAvailable ? 1 : 0);

    if (!mounted) return;

    if (result == "success") {
      Toast(
        context,
        isAvailable ? "Plat rendu disponible." : "Plat rendu indisponible.",
        true,
      );
      await Dish.getAllDishesDetails();
      await _loadDashboard();
    } else {
      Toast(context, result, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F2),
        body: RefreshIndicator(
          onRefresh: _refreshRemoteData,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    size.height * 0.02,
                    20,
                    32,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    if (restaurant == null) _buildEmptyState(context) else ...[
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildQuickActions(context),
                      const SizedBox(height: 20),
                      _buildRecentOrders(context),
                      const SizedBox(height: 20),
                      _buildDishAvailability(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1B1B), Color(0xFFE0533D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Espace restaurant',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            restaurant?.name ?? 'Restaurant non configuré',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            restaurant?.adress ??
                "Aucun restaurant n'est encore rattaché à ce compte.",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
          if (restaurant != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    restaurant!.isOpen == 1 ? 'Ouvert' : 'Fermé',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor:
                      restaurant!.isOpen == 1 ? Colors.green : Colors.black45,
                ),
                Chip(
                  label: Text(restaurant!.openingHours),
                  backgroundColor: Colors.white,
                ),
                Chip(
                  label: Text(
                    "Livraison ${restaurant!.deliveryFee.toStringAsFixed(2)}",
                  ),
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined, size: 52, color: Colors.red),
          const SizedBox(height: 14),
          const Text(
            "Aucun restaurant n'est disponible pour ce compte.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            "Dès qu'un restaurant sera créé ou synchronisé, cet espace affichera les commandes, les plats disponibles et les portions.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _refreshRemoteData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.35,
      children: [
        _StatCard(
          title: 'Commandes en attente',
          value: pendingOrders.toString(),
          subtitle: 'A confirmer rapidement',
          color: const Color(0xFFF59E0B),
          icon: Icons.pending_actions,
        ),
        _StatCard(
          title: 'Commandes confirmées',
          value: confirmedOrders.toString(),
          subtitle: 'Déjà prises en charge',
          color: const Color(0xFF16A34A),
          icon: Icons.verified,
        ),
        _StatCard(
          title: 'Plats disponibles',
          value: availableDishes.toString(),
          subtitle: '$unavailableDishes indisponibles',
          color: const Color(0xFFDC2626),
          icon: Icons.restaurant_menu,
        ),
        _StatCard(
          title: 'Portions',
          value: totalAvailableServings.toString(),
          subtitle: '$soldServings portions vendues',
          color: const Color(0xFF2563EB),
          icon: Icons.inventory_2,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickActionChip(
              icon: Icons.receipt_long,
              label: 'Voir les commandes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const UserOrdersPage(showRestaurantOrders: true),
                  ),
                );
              },
            ),
            _QuickActionChip(
              icon: Icons.add_circle_outline,
              label: 'Ajouter un plat',
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => DishFormPage(),
                  ),
                ).then((_) => _refreshRemoteData());
              },
            ),
            _QuickActionChip(
              icon: Icons.store_mall_directory_outlined,
              label: 'Gérer mon restaurant',
              onTap: () {
                if (restaurant == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantDetails(
                      restaurant_id: restaurant!.restaurantID,
                    ),
                  ),
                ).then((_) => _refreshRemoteData());
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Dernières commandes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const UserOrdersPage(showRestaurantOrders: true),
                    ),
                  );
                },
                child: const Text('Tout voir'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (commandes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("Aucune commande reçue pour l'instant."),
            )
          else
            ...commandes.take(3).map(
                  (commande) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          CommandeStatus.color(commande.status).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.receipt,
                        color: CommandeStatus.color(commande.status),
                      ),
                    ),
                    title: Text('Commande #${commande.commandeID}'),
                    subtitle: Text(
                      '${commande.dateCommande.toLocal().toString().split(" ")[0]} à ${commande.heure}',
                    ),
                    trailing: Chip(
                      label: Text(CommandeStatus.normalize(commande.status)),
                      backgroundColor:
                          CommandeStatus.color(commande.status).withValues(alpha: 0.12),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildDishAvailability() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plats et portions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Activez ou désactivez rapidement vos plats disponibles.',
          ),
          const SizedBox(height: 14),
          if (dishes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("Aucun plat enregistré pour ce restaurant."),
            )
          else
            ...dishes.take(6).map(
                  (dish) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: const Color(0xFFF8F5F2),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => DishDetailsMicroRestau(
                              dish_id: dish.dishID,
                              from_page: 1,
                              dish_restau: dish.restauID,
                            ),
                          ),
                        ).then((_) => _refreshRemoteData());
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          (dish.status ?? 0) == 1
                              ? Icons.check_circle
                              : Icons.remove_circle_outline,
                          color:
                              (dish.status ?? 0) == 1 ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(dish.name ?? 'Plat sans nom'),
                      subtitle: Text(
                        '${dish.nb_servings ?? 0} portions | ${dish.nb_orders} commandes',
                      ),
                      trailing: Switch(
                        value: (dish.status ?? 0) == 1,
                        activeThumbColor: Colors.green,
                        onChanged: (value) {
                          _toggleDishAvailability(dish, value);
                        },
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFFD3CC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
