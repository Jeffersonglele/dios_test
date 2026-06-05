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
import 'package:dios_delices/l10n/app_localizations.dart';
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
  double totalRevenue = 0;
  int totalOrders = 0;
  List<Dish> topDishes = [];
  String country = '';

  bool _isMounted = false;

  bool get _restoValid => restaurant?.valid == 1;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadDashboard();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!_isMounted) return;
    setState(() => isLoading = true);
    try {
      final session = await SessionService.readSession();
      country = session.country;
      if (session.restaurantId == null) {
        _update(() {
          restaurant = null;
          dishes = []; commandes = [];
          pendingOrders = 0; confirmedOrders = 0;
          availableDishes = 0; unavailableDishes = 0;
          totalAvailableServings = 0; soldServings = 0;
          totalRevenue = 0; totalOrders = 0; topDishes = [];
          isLoading = false;
        });
        return;
      }

      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final allDishes = await Dish.fetchDishesFromDB();
      final allCommandes = await Commande.fetchCommandesFromDB();
      final allLignes = await LigneCommande.fetchLignesCommandeFromDB();

      final current = Restaurant.getRestaurantByRestaurantId(restaurants, session.restaurantId!);
      final restDishes = allDishes.where((d) => d.restauID == session.restaurantId).toList()..sort((a, b) => b.nb_orders.compareTo(a.nb_orders));
      final restCommandes = allCommandes.where((c) => c.restaurateurID == session.userId).toList()..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
      final cmdIds = restCommandes.map((c) => c.commandeID.toString()).toSet();
      final sold = allLignes.where((l) => cmdIds.contains(l.commandeID)).fold<int>(0, (s, l) => s + l.quantite);

      double revenue = 0;
      for (final c in restCommandes) {
        revenue += c.fraisLivraison;
      }

      _update(() {
        restaurant = current;
        dishes = restDishes;
        commandes = restCommandes;
        pendingOrders = restCommandes.where((c) => CommandeStatus.isPending(c.status)).length;
        confirmedOrders = restCommandes.where((c) => CommandeStatus.normalize(c.status) == CommandeStatus.confirmed).length;
        availableDishes = restDishes.where((d) => (d.status ?? 0) == 1).length;
        unavailableDishes = restDishes.where((d) => (d.status ?? 0) != 1).length;
        totalAvailableServings = restDishes.fold<int>(0, (s, d) => s + ((d.nb_servings ?? 0) > 0 ? d.nb_servings! : 0));
        soldServings = sold;
        totalRevenue = revenue;
        totalOrders = restCommandes.length;
        topDishes = restDishes.take(3).toList();
        isLoading = false;
      });
    } catch (_) {
      _update(() => isLoading = false);
    }
  }

  void _update(VoidCallback cb) { if (_isMounted) setState(cb); }

  Future<void> _refreshRemoteData() async {
    await Restaurant.getAllRestaurantsDetails();
    await Dish.getAllDishesDetails();
    await Commande.getAllCommandes();
    await LigneCommande.getAllLignesCommande();
    await _loadDashboard();
  }

  Future<void> _toggleDishAvailability(Dish dish, bool avail) async {
    final result = await Dish.updateDishStatus(dish.dishID, avail ? 1 : 0);
    if (!_isMounted) return;
    if (result == "success") {
      Toast(context, 'Dish ${avail ? AppLocalizations.of(context)!.available : AppLocalizations.of(context)!.unavailable}.', true);
      await Dish.getAllDishesDetails();
      await _loadDashboard();
    } else {
      Toast(context, result, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isSmall = w < 400;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: RefreshIndicator(
          color: AppColors.brand, onRefresh: _refreshRemoteData,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _buildHeader(isSmall)),
                  if (restaurant == null)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else if (!_restoValid)
                    SliverToBoxAdapter(child: _buildPendingFullPage())
                  else ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildKpiRow(isSmall)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildOrderChart()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildTopDishes(isSmall)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildQuickActions(isSmall)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildDishAvailability()),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ]),
        ),
        floatingActionButton: _restoValid ? FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context, CupertinoPageRoute(builder: (_) => const DishFormPage()));
            if (_isMounted) await _refreshRemoteData();
          },
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(isSmall ? 'Add' : AppLocalizations.of(context)!.addDish),
        ) : null,
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      margin: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 0),
      padding: EdgeInsets.all(isSmall ? 16 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(colors: [AppColors.brandDark, AppColors.brand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello', style: AppTypography.titleLarge().copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: isSmall ? 13 : 14)),
            const SizedBox(height: 4),
            Text(restaurant?.name ?? AppLocalizations.of(context)!.myRestaurant, style: AppTypography.headlineMedium().copyWith(fontSize: isSmall ? 18 : 22, color: Colors.white), overflow: TextOverflow.ellipsis),
          ])),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              onPressed: () async {
                if (restaurant == null) return;
                await Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetails(restaurant_id: restaurant!.restaurantID)));
                if (_isMounted) await _refreshRemoteData();
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _HeaderBadge(Icons.location_on_outlined, restaurant?.location ?? '', isSmall),
          const SizedBox(width: 16),
          _HeaderBadge(Icons.access_time_rounded, restaurant?.openingHours ?? '09:00 - 20:00', isSmall),
        ]),
      ]),
    );
  }

  Widget _HeaderBadge(IconData icon, String text, bool isSmall) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: isSmall ? 13 : 14),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: isSmall ? 11 : 12)),
    ]);
  }

  Widget _buildKpiRow(bool isSmall) {
    final currency = country == 'France' ? '€' : 'FCFA';
    final revText = totalRevenue >= 1000 ? '${(totalRevenue / 1000).toStringAsFixed(1)}k' : totalRevenue.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context)!.overview, style: AppTypography.titleMedium()),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BigKpi(AppLocalizations.of(context)!.pending, '$pendingOrders', AppColors.accent)),
          const SizedBox(width: 12),
          Expanded(child: _BigKpi(AppLocalizations.of(context)!.confirmed, '$confirmedOrders', AppColors.success)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BigKpi(AppLocalizations.of(context)!.revenue, '$revText $currency', AppColors.brand)),
          const SizedBox(width: 12),
          Expanded(child: _BigKpi(AppLocalizations.of(context)!.myProducts, '$availableDishes ${AppLocalizations.of(context)!.available}', AppColors.inkMuted)),
        ]),
      ]),
    );
  }

  Widget _BigKpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppTypography.headlineLarge().copyWith(fontSize: 24, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.labelMedium().copyWith(fontSize: 13, color: AppColors.inkMuted)),
      ]),
    );
  }

  Widget _buildOrderChart() {
    if (totalOrders == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(AppLocalizations.of(context)!.orders, style: AppTypography.titleMedium()),
            const Spacer(),
            Text('$totalOrders ${AppLocalizations.of(context)!.total}', style: AppTypography.bodyMedium().copyWith(fontSize: 12, color: AppColors.inkMuted)),
          ]),
          const SizedBox(height: 18),
          _BarRow(AppLocalizations.of(context)!.pending, pendingOrders, totalOrders, AppColors.accent),
          const SizedBox(height: 14),
          _BarRow(AppLocalizations.of(context)!.confirmed, confirmedOrders, totalOrders, AppColors.success),
          const SizedBox(height: 14),
          _BarRow(AppLocalizations.of(context)!.delivered, (totalOrders - pendingOrders - confirmedOrders).clamp(0, 99999), totalOrders, AppColors.brand),
        ]),
      ),
    );
  }

  Widget _BarRow(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.labelMedium().copyWith(fontSize: 13)),
        const Spacer(),
        Text('$value', style: AppTypography.labelMedium().copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Text('($pct%)', style: AppTypography.bodyMedium().copyWith(fontSize: 12, color: AppColors.inkMuted)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity, height: 10,
          color: AppColors.surfaceWarm,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: total > 0 ? (value / total).clamp(0.0, 1.0) : 0,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
          ),
        ),
      ),
    ]);
  }

  Widget _buildTopDishes(bool isSmall) {
    if (topDishes.isEmpty) return const SizedBox.shrink();
    final currency = country == 'France' ? '€' : 'FCFA';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 6),
            Text('Popular dishes', style: AppTypography.titleMedium()),
          ]),
          const SizedBox(height: 12),
          ...topDishes.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: d.image!.isNotEmpty
                    ? Image.network(d.image!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _PlaceholderIcon())
                    : _PlaceholderIcon(),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name ?? '', style: AppTypography.labelMedium(), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${d.nb_orders} ${AppLocalizations.of(context)!.orders}', style: AppTypography.bodyMedium().copyWith(fontSize: 11, color: AppColors.inkMuted)),
              ])),
              Text('${d.price?.toStringAsFixed(2)} $currency', style: AppTypography.bodyLarge(color: AppColors.brand).copyWith(fontSize: 14)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _PlaceholderIcon() => Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.surfaceWarm, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Icon(Icons.restaurant_rounded, color: AppColors.inkMuted, size: 20));

  Widget _buildQuickActions(bool isSmall) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(AppLocalizations.of(context)!.quickActions, style: AppTypography.titleMedium()),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _ActionChip(Icons.receipt_long_rounded, AppLocalizations.of(context)!.orders, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const UserOrdersPage(showRestaurantOrders: true)));
          }, isSmall: isSmall),
          _ActionChip(Icons.store_mall_directory_outlined, 'Manage', () {
            if (restaurant == null) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetails(restaurant_id: restaurant!.restaurantID))).then((_) {
              if (_isMounted) _refreshRemoteData();
            });
          }, isSmall: isSmall),
        ]),
      ]),
    );
  }

  Widget _buildDishAvailability() {
    final w = MediaQuery.of(context).size.width;
    final isSmall = w < 400;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dishes & portions', style: AppTypography.titleMedium()),
          const SizedBox(height: 4),
          Text('Toggle your dishes.', style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          if (dishes.isEmpty)
            Text('No dishes registered.', style: AppTypography.bodyMedium())
          else
            ...dishes.take(6).map((dish) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppColors.surfaceWarm, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: InkWell(
                onTap: () async {
                  await Navigator.push(context, CupertinoPageRoute(builder: (_) => DishDetailsMicroRestau(dish_id: dish.dishID, from_page: 1, dish_restau: dish.restauID)));
                  if (_isMounted) await _refreshRemoteData();
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: isSmall ? 8 : 12),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: AppColors.card, child: Icon((dish.status ?? 0) == 1 ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, color: (dish.status ?? 0) == 1 ? AppColors.success : AppColors.inkMuted)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(dish.name ?? '', style: AppTypography.labelMedium(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Switch(value: (dish.status ?? 0) == 1, activeColor: AppColors.success, onChanged: (v) => _toggleDishAvailability(dish, v)),
                  ]),
                ),
              ),
            )),
        ]),
      ),
    );
  }

  Widget _buildPendingFullPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 40),
        Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.hourglass_bottom_rounded, color: AppColors.accent, size: 48)),
        const SizedBox(height: 28),
        Text(AppLocalizations.of(context)!.pendingValidation, textAlign: TextAlign.center, style: AppTypography.headlineMedium().copyWith(fontSize: 20)),
        const SizedBox(height: 12),
        Text('Your restaurant is under review. You will be able to manage your restaurant, add dishes and receive orders once validated.', textAlign: TextAlign.center, style: AppTypography.bodyLarge(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.resolve(AppColors.card, AppDarkColors.card), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5)),
          child: Column(children: [
            _PRow(Icons.email_rounded, 'You will be notified by email'),
            const Divider(height: 24),
            _PRow(Icons.restaurant_menu_rounded, 'You will be able to add dishes'),
            const Divider(height: 24),
            _PRow(Icons.receipt_long_rounded, 'And receive orders'),
          ]),
        ),
        const SizedBox(height: 40),
        Text(restaurant?.name ?? AppLocalizations.of(context)!.myRestaurant, style: AppTypography.titleMedium().copyWith(fontSize: 16, color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
      ]),
    );
  }

  Widget _PRow(IconData icon, String text) => Row(children: [
    Icon(icon, size: 18, color: AppColors.accent),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: AppTypography.bodyMedium().copyWith(fontSize: 13))),
  ]);

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 60),
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.brandSurface, shape: BoxShape.circle), child: const Icon(Icons.restaurant_rounded, color: AppColors.brand, size: 40)),
        const SizedBox(height: 20),
        Text(AppLocalizations.of(context)!.noRestaurant, style: AppTypography.headlineMedium().copyWith(fontSize: 20)),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)!.createRestaurantPrompt, textAlign: TextAlign.center, style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
      ])),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.icon, this.label, this.onTap, {required this.isSmall});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: isSmall ? 10 : 12),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.brand, size: isSmall ? 16 : 18),
          SizedBox(width: isSmall ? 6 : 8),
          Flexible(child: Text(label, style: AppTypography.labelMedium(color: AppColors.ink).copyWith(fontSize: isSmall ? 12 : 14), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
