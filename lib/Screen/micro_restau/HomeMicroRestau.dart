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
import 'package:dios_delices/theme/app_theme.dart';
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
    setState(() => isLoading = true);
    final session = await SessionService.readSession();

    if (session.restaurantId == null) {
      if (!mounted) return;
      setState(() {
        restaurant = null; dishes = []; commandes = [];
        pendingOrders = 0; confirmedOrders = 0;
        availableDishes = 0; unavailableDishes = 0;
        totalAvailableServings = 0; soldServings = 0;
        isLoading = false;
      });
      return;
    }

    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final allDishes = await Dish.fetchDishesFromDB();
    final allCommandes = await Commande.fetchCommandesFromDB();
    final allLignes = await LigneCommande.fetchLignesCommandeFromDB();

    final current = Restaurant.getRestaurantByRestaurantId(restaurants, session.restaurantId!);
    final restDishes = allDishes.where((d) => d.restauID == session.restaurantId).toList()
      ..sort((a, b) => b.nb_orders.compareTo(a.nb_orders));
    final restCommandes = allCommandes.where((c) => c.restaurateurID == session.userId).toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    final cmdIds = restCommandes.map((c) => c.commandeID.toString()).toSet();
    final sold = allLignes.where((l) => cmdIds.contains(l.commandeID)).fold<int>(0, (s, l) => s + l.quantite);

    if (!mounted) return;
    setState(() {
      restaurant = current;
      dishes = restDishes;
      commandes = restCommandes;
      pendingOrders = restCommandes.where((c) => CommandeStatus.isPending(c.status)).length;
      confirmedOrders = restCommandes.where((c) => CommandeStatus.normalize(c.status) == CommandeStatus.confirmed).length;
      availableDishes = restDishes.where((d) => (d.status ?? 0) == 1).length;
      unavailableDishes = restDishes.where((d) => (d.status ?? 0) != 1).length;
      totalAvailableServings = restDishes.fold<int>(0, (s, d) => s + ((d.nb_servings ?? 0) > 0 ? d.nb_servings! : 0));
      soldServings = sold;
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
      Toast(context, isAvailable ? "Plat rendu disponible." : "Plat rendu indisponible.", true);
      await Dish.getAllDishesDetails();
      await _loadDashboard();
    } else {
      Toast(context, result, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: RefreshIndicator(
          color: AppColors.brand,
          backgroundColor: AppColors.card,
          onRefresh: _refreshRemoteData,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    if (restaurant == null)
                      SliverToBoxAdapter(child: _buildEmptyState())
                    else ...[
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(child: _buildStatsGrid()),
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(child: _buildQuickActions()),
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(child: _buildRecentOrders()),
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                      SliverToBoxAdapter(child: _buildDishAvailability()),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => DishFormPage()))
                .then((_) => _refreshRemoteData());
          },
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un plat'),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text('Espace restaurant',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (restaurant != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: restaurant!.isOpen == 1 ? AppColors.success : Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(restaurant!.isOpen == 1 ? 'Ouvert' : 'Fermé',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            restaurant?.name ?? 'Restaurant non configuré',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          if (restaurant != null) ...[
            const SizedBox(height: 6),
            Text('${restaurant!.location}\nLivraison : ${restaurant!.deliveryFee.toStringAsFixed(2)} € · ${restaurant!.openingHours}',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 56, color: AppColors.brand.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Aucun restaurant disponible.',
              style: AppTypography.titleMedium(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Créez ou synchronisez votre restaurant pour afficher les commandes et les plats.',
              style: AppTypography.bodyMedium(), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _refreshRemoteData, child: const Text('Rafraîchir')),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
        children: [
          _StatCard(title: 'Commandes\nen attente', value: '$pendingOrders', subtitle: 'À confirmer',
              color: AppColors.accent),
          _StatCard(title: 'Commandes\nconfirmées', value: '$confirmedOrders', subtitle: 'En cours',
              color: AppColors.success),
          _StatCard(title: 'Plats\ndisponibles', value: '$availableDishes', subtitle: '$unavailableDishes indispo.',
              color: AppColors.brand),
          _StatCard(title: 'Portions\nvendues', value: '$soldServings', subtitle: '/$totalAvailableServings portions',
              color: AppColors.inkMuted),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions rapides', style: AppTypography.titleMedium()),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _ActionChip(Icons.receipt_long_rounded, 'Voir les commandes', () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const UserOrdersPage(showRestaurantOrders: true)));
            }),
            _ActionChip(Icons.add_circle_outline_rounded, 'Ajouter un plat', () {
              Navigator.push(context, CupertinoPageRoute(builder: (_) => DishFormPage()))
                  .then((_) => _refreshRemoteData());
            }),
            _ActionChip(Icons.store_mall_directory_outlined, 'Gérer mon restaurant', () {
              if (restaurant == null) return;
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RestaurantDetails(restaurant_id: restaurant!.restaurantID)))
                  .then((_) => _refreshRemoteData());
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Dernières commandes', style: AppTypography.titleMedium()),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const UserOrdersPage(showRestaurantOrders: true))),
              child: Text('Tout voir', style: AppTypography.labelMedium(color: AppColors.brand)),
            ),
          ]),
          const SizedBox(height: 6),
          if (commandes.isEmpty)
            Text("Aucune commande reçue.", style: AppTypography.bodyMedium())
          else
            ...commandes.take(3).map((c) => Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CommandeStatus.color(c.status).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: CommandeStatus.color(c.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.receipt_rounded, color: CommandeStatus.color(c.status), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Commande #${c.commandeID}', style: AppTypography.labelMedium()),
                    Text('${c.dateCommande.toLocal().toString().split(" ")[0]} à ${c.heure}',
                        style: AppTypography.labelMedium(color: AppColors.inkSubtle).copyWith(fontSize: 11)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CommandeStatus.color(c.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(CommandeStatus.normalize(c.status),
                      style: TextStyle(color: CommandeStatus.color(c.status), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            )),
        ],
      ),
    );
  }

  Widget _buildDishAvailability() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plats et portions', style: AppTypography.titleMedium()),
          const SizedBox(height: 4),
          Text('Activez ou désactivez rapidement vos plats.', style: AppTypography.bodyMedium()),
          const SizedBox(height: 14),
          if (dishes.isEmpty)
            Text("Aucun plat enregistré.", style: AppTypography.bodyMedium())
          else
            ...dishes.take(6).map((dish) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ListTile(
                onTap: () => Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => DishDetailsMicroRestau(dish_id: dish.dishID, from_page: 1, dish_restau: dish.restauID)))
                    .then((_) => _refreshRemoteData()),
                leading: CircleAvatar(
                  backgroundColor: AppColors.card,
                  child: Icon(
                    (dish.status ?? 0) == 1 ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    color: (dish.status ?? 0) == 1 ? AppColors.success : AppColors.error,
                  ),
                ),
                title: Text(dish.name ?? 'Plat sans nom', style: AppTypography.labelMedium()),
                subtitle: Text('${dish.nb_servings ?? 0} portions · ${dish.nb_orders} commandes',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                trailing: Switch(
                  value: (dish.status ?? 0) == 1,
                  activeColor: AppColors.success,
                  onChanged: (v) => _toggleDishAvailability(dish, v),
                ),
              ),
            )),
        ],
      ),
    );
  }
}

// ── KPI Card ───────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.color});
  final String title, value, subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTypography.headlineLarge().copyWith(fontSize: 28, color: color)),
          ),
          const SizedBox(height: 4),
          Text(title, style: AppTypography.labelMedium(color: AppColors.inkMuted).copyWith(fontSize: 11), maxLines: 2),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: AppTypography.labelMedium(color: color).copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.brand, size: 18),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.labelMedium(color: AppColors.ink)),
        ]),
      ),
    );
  }
}
