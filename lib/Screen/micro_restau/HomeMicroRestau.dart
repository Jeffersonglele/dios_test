import 'package:dios_delices/Screen/UserOrdersPage.dart';
import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/dish/DishFormPage.dart';
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

// ═══════════════════════════════════════════════════════════
// HomeMicroRestau — Dashboard cuisiner/vendeur
// ═══════════════════════════════════════════════════════════

class HomeMicroRestau extends StatefulWidget {
  const HomeMicroRestau({super.key});

  @override
  State<HomeMicroRestau> createState() => _HomeMicroRestauState();
}

class _HomeMicroRestauState extends State<HomeMicroRestau> {
  bool _isLoading = true;
  bool _isMounted = false;

  Restaurant? _restaurant;
  List<Dish> _dishes = [];
  List<Commande> _commandes = [];

  int _pendingOrders = 0;
  int _confirmedOrders = 0;
  int _cancelledOrders = 0;
  int _availableDishes = 0;
  int _unavailableDishes = 0;
  int _totalAvailableServings = 0;
  int _soldServings = 0;

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

  // ── Chargement ───────────────────────────────────────────
  Future<void> _loadDashboard() async {
    if (!_isMounted) return;
    _set(() => _isLoading = true);

    try {
      final session = await SessionService.readSession();
      if (session.restaurantId == null) {
        _set(() {
          _restaurant = null;
          _dishes = [];
          _commandes = [];
          _pendingOrders = _confirmedOrders = _availableDishes =
              _unavailableDishes = _totalAvailableServings = _soldServings = 0;
          _isLoading = false;
        });
        return;
      }

      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final allDishes = await Dish.fetchDishesFromDB();
      final allCommandes = await Commande.fetchCommandesFromDB();
      final allLignes = await LigneCommande.fetchLignesCommandeFromDB();

      final current = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      final restDishes = allDishes
          .where((d) => d.restauID == session.restaurantId)
          .toList()
        ..sort((a, b) => b.nb_orders.compareTo(a.nb_orders));
      final restCmds = allCommandes
          .where((c) => c.restaurateurID == session.userId)
          .toList()
        ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

      final cmdIds = restCmds.map((c) => c.commandeID.toString()).toSet();
      final sold = allLignes
          .where((l) => cmdIds.contains(l.commandeID))
          .fold<int>(0, (s, l) => s + l.quantite);

      _set(() {
        _restaurant = current;
        _dishes = restDishes;
        _commandes = restCmds;
        _pendingOrders =
            restCmds.where((c) => CommandeStatus.isPending(c.status)).length;
        _confirmedOrders = restCmds
            .where((c) =>
                CommandeStatus.normalize(c.status) == CommandeStatus.confirmed)
            .length;
        _cancelledOrders = restCmds
            .where((c) =>
                CommandeStatus.normalize(c.status) == CommandeStatus.cancelled)
            .length;
        _availableDishes = restDishes.where((d) => (d.status ?? 0) == 1).length;
        _unavailableDishes =
            restDishes.where((d) => (d.status ?? 0) != 1).length;
        _totalAvailableServings = restDishes.fold<int>(
            0, (s, d) => s + ((d.nb_servings ?? 0) > 0 ? d.nb_servings! : 0));
        _soldServings = sold;
        _isLoading = false;
      });
    } catch (_) {
      _set(() => _isLoading = false);
    }
  }

  Future<void> _refreshRemoteData() async {
    await Restaurant.getAllRestaurantsDetails();
    await Dish.getAllDishesDetails();
    await Commande.getAllCommandes();
    await LigneCommande.getAllLignesCommande();
    await _loadDashboard();
  }

  Future<void> _toggleDish(Dish dish, bool available) async {
    final result = await Dish.updateDishStatus(dish.dishID, available ? 1 : 0);
    if (!_isMounted) return;
    if (result == 'success') {
      Toast(
          context,
          available ? 'Plat rendu disponible.' : 'Plat rendu indisponible.',
          true);
      await Dish.getAllDishesDetails();
      await _loadDashboard();
    } else {
      Toast(context, result, false);
    }
  }

  void _set(VoidCallback fn) {
    if (_isMounted) setState(fn);
  }

  bool get _restoValid => _restaurant?.valid == 1;

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.resolve(
            AppColors.surface, AppDarkColors.surface),
        floatingActionButton: _restoValid
            ? _AddDishFAB(
                onPressed: () async {
                  await Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => DishFormPage()));
                  if (_isMounted) await _refreshRemoteData();
                },
              )
            : null,
        body: RefreshIndicator(
          color:
              AppColors.resolve(AppColors.brand, AppDarkColors.brand),
          backgroundColor:
              AppColors.resolve(AppColors.card, AppDarkColors.card),
          onRefresh: _refreshRemoteData,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header hero ───────────────────────
                    SliverToBoxAdapter(
                        child: _HeroHeader(restaurant: _restaurant)),

                    if (_restaurant == null)
                      SliverToBoxAdapter(
                          child: _EmptyState(onRefresh: _refreshRemoteData))
                    else if (!_restoValid)
                      SliverToBoxAdapter(child: _buildPendingFullPage())
                    else ...[
                      // ── KPIs ──────────────────────────
                      SliverToBoxAdapter(
                        child: _KpiGrid(
                          pending: _pendingOrders,
                          confirmed: _confirmedOrders,
                          cancelled: _cancelledOrders,
                          available: _availableDishes,
                          unavailable: _unavailableDishes,
                          sold: _soldServings,
                          totalServings: _totalAvailableServings,
                        ),
                      ),

                      // ── Actions rapides ───────────────
                      SliverToBoxAdapter(
                        child: _QuickActions(
                          restaurant: _restaurant!,
                          isMounted: _isMounted,
                          onRefresh: _refreshRemoteData,
                        ),
                      ),

                      // ── Dernières commandes ───────────
                      SliverToBoxAdapter(
                        child: _RecentOrders(commandes: _commandes),
                      ),

                      // ── Disponibilité des plats ───────
                      SliverToBoxAdapter(
                        child: _DishAvailability(
                          dishes: _dishes,
                          isMounted: _isMounted,
                          onToggle: _toggleDish,
                          onRefresh: _refreshRemoteData,
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPendingFullPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_bottom_rounded,
              color: AppColors.accent, size: 48),
        ),
        const SizedBox(height: 28),
        Text(
          'En attente de validation',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium().copyWith(fontSize: 20),
        ),
        const SizedBox(height: 12),
        Text(
          'Votre restaurant est en cours d\'examen. Vous pourrez gérer votre restaurant, ajouter des plats et recevoir des commandes dès qu\'il sera validé.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge(
            color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color:
                  AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5,
            ),
          ),
          child: Column(children: [
            _PRow(Icons.email_rounded,
                'Vous serez notifié par email'),
            const Divider(height: 24),
            _PRow(Icons.restaurant_menu_rounded,
                'Vous pourrez ajouter vos plats'),
            const Divider(height: 24),
            _PRow(Icons.receipt_long_rounded,
                'Et recevoir des commandes'),
          ]),
        ),
        const SizedBox(height: 40),
        Text(
          _restaurant?.name ?? 'Votre restaurant',
          style: AppTypography.titleMedium().copyWith(
            fontSize: 16,
            color:
                AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _HeroHeader — Bannière restaurant
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.restaurant});
  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context) {
    final isOpen = restaurant?.isOpen == 1;

    return Container(
      // ── Marge top plus généreuse pour descendre le header ──
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandLight, AppColors.brandDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.32),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Ligne 1 — large, en haut à droite
            Positioned(
              right: -30,
              top: -18,
              child: Transform.rotate(
                angle: -0.38, // ~22°
                child: Container(
                  width: 180,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                            Colors.white, AppDarkColors.surface)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
            // Ligne 2 — plus fine, décalée
            Positioned(
              right: 10,
              top: 18,
              child: Transform.rotate(
                angle: -0.38,
                child: Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                            Colors.white, AppDarkColors.surface)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            // Ligne 3 — en bas à gauche, orientée différemment
            Positioned(
              left: -20,
              bottom: -10,
              child: Transform.rotate(
                angle: 0.28,
                child: Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                            Colors.white, AppDarkColors.surface)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
            // Ligne 4 — courte, coin bas droit
            Positioned(
              right: 30,
              bottom: 10,
              child: Transform.rotate(
                angle: -0.38,
                child: Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                            Colors.white, AppDarkColors.surface)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),

            // ── Contenu ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ligne du haut ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                                  Colors.white, AppDarkColors.surface)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'Mon restaurant',
                              style: AppTypography.labelMedium(
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (restaurant != null) _StatusPill(isOpen: isOpen),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Nom du restaurant ─────────────────────
                  Text(
                    restaurant?.name ?? 'Restaurant non configuré',
                    style: AppTypography.headlineLarge(color: Colors.white)
                        .copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),

                  if (restaurant != null) ...[
                    const SizedBox(height: AppSpacing.sm),

                    // ── Séparateur ────────────────────────
                    Container(
                      width: 40,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    _MetaChip(
                      icon: Icons.location_on_rounded,
                      label: restaurant!.location,
                    ),
                    const SizedBox(height: 4),
                    _MetaChip(
                      icon: Icons.delivery_dining_rounded,
                      label:
                          '${restaurant!.deliveryFee.toStringAsFixed(2)} € livraison',
                    ),
                    const SizedBox(height: 4),
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: restaurant!.openingHours,
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ── Petite puce méta (localisation, frais, horaires) ─────
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppTypography.labelMedium(color: Colors.white)
                .copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Badge statut Ouvert / Fermé ───────────────────────────
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen
            ? AppColors.success.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOpen
              ? AppColors.success.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? AppColors.success : Colors.white54,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'Ouvert' : 'Fermé',
            style: AppTypography.labelMedium(
              color: isOpen ? AppColors.success : Colors.white70,
            ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _KpiGrid — 4 cartes métriques
// ═══════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.pending,
    required this.confirmed,
    required this.cancelled,
    required this.available,
    required this.unavailable,
    required this.sold,
    required this.totalServings,
  });

  final int pending, confirmed, cancelled, available, unavailable, sold, totalServings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vue d\'ensemble',
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(
                      AppColors.ink, AppDarkColors.ink))),
          const SizedBox(height: AppSpacing.md),

          // ── En attente + annulées ─────────────────────
          Row(children: [
            Expanded(
              child: _KpiTile(
                value: '$pending',
                label: 'Commandes en attente',
                sublabel: 'À traiter',
                icon: Icons.hourglass_top_rounded,
                color: AppColors.resolve(
                    AppColors.accent, AppDarkColors.accent),
                urgent: pending > 0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                value: '$cancelled',
                label: 'Commandes annulées',
                sublabel: 'Total',
                icon: Icons.cancel_outlined,
                color: AppColors.resolve(
                    AppColors.error, AppDarkColors.error),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // Ligne 2 : plats + portions (avec barre de progression)
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  value: '$available',
                  label: 'Plats disponibles',
                  sublabel: '$unavailable indisponibles',
                  color: AppColors.brand,
                  icon: Icons.restaurant_menu_rounded,
                  // Ratio disponibles / total
                  progress: (available + unavailable) > 0
                      ? available / (available + unavailable)
                      : null,
                  valueColor: AppColors.resolve(
                      AppColors.inkSubtle, AppDarkColors.inkSubtle),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _KpiCard(
                  value: '$sold',
                  label: 'Portions vendues',
                  sublabel: '/ $totalServings disponibles',
                  color: AppColors.inkMuted,
                  icon: Icons.trending_up_rounded,
                  // Ratio vendu / total
                  progress: totalServings > 0
                      ? (sold / totalServings).clamp(0.0, 1.0)
                      : null,
                  valueColor: AppColors.resolve(
                      AppColors.inkSubtle, AppDarkColors.inkSubtle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _KpiTile — tuile métrique compacte (commandes)
// ═══════════════════════════════════════════════════════════
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.urgent = false,
  });

  final String value, label, sublabel;
  final IconData icon;
  final Color color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: urgent
              ? color.withValues(alpha: 0.4)
              : AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: urgent ? 1.5 : 0.5,
        ),
        boxShadow: urgent ? [AppShadows.card] : [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              Text(value,
                  style: AppTypography.titleLarge(color: color)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label,
              style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.ink, AppDarkColors.ink))),
          const SizedBox(height: 2),
          Text(sublabel,
              style: AppTypography.bodySmall(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _KpiCard — carte métrique avec barre de progression
// ═══════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.progress,
    this.valueColor,
  });

  final String value, label, sublabel;
  final Color color;
  final IconData icon;
  final double? progress; // null = pas de barre
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(
                AppColors.border, AppDarkColors.border),
            width: 0.5),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne icône + valeur ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              // Valeur numérique grande
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppTypography.displayMedium().copyWith(
                    fontSize: 32,
                    color: valueColor ??
                        AppColors.resolve(
                            Colors.white, AppDarkColors.surface),
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Barre de progression (si disponible) ────────
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.resolve(
                    AppColors.border, AppDarkColors.border),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // ── Label + sous-label ───────────────────────────
          Text(
            label,
            style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.ink, AppDarkColors.ink))
                .copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkSubtle, AppDarkColors.inkSubtle))
                .copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _QuickActions — 3 boutons d'action rapide
// ═══════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.restaurant,
    required this.isMounted,
    required this.onRefresh,
  });

  final Restaurant restaurant;
  final bool isMounted;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions rapides',
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(
                      AppColors.ink, AppDarkColors.ink))),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Commandes',
                  color: AppColors.accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UserOrdersPage(showRestaurantOrders: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Ajouter plat',
                  color: AppColors.brand,
                  onTap: () async {
                    await Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const DishFormPage()));
                    if (isMounted) await onRefresh();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionTile(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Gérer',
                  color: AppColors.inkMuted,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetails(
                            restaurant_id: restaurant.restaurantID),
                      ),
                    ).then((_) {
                      if (isMounted) onRefresh();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(
                  AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [AppShadows.subtle],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.resolve(color, color),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.ink, AppDarkColors.ink))
                  .copyWith(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RecentOrders — 3 dernières commandes
// ═══════════════════════════════════════════════════════════
class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.commandes});
  final List<Commande> commandes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.resolve(
                AppColors.border, AppDarkColors.border),
            width: 0.5),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, 0),
            child: Row(
              children: [
                // Icône section
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.brandSurface,
                        AppDarkColors.brandSurface),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Dernières commandes',
                      style: AppTypography.titleMedium(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink))),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UserOrdersPage(showRestaurantOrders: true),
                    ),
                  ),
                  child: Text(
                    'Tout voir',
                    style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          if (commandes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _EmptySection(
                icon: Icons.inbox_outlined,
                message: 'Aucune commande reçue pour l\'instant.',
              ),
            )
          else
            ...commandes.take(3).map((c) => _OrderRow(commande: c)),

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.commande});
  final Commande commande;

  @override
  Widget build(BuildContext context) {
    final statusColor = CommandeStatus.color(commande.status);
    final statusLabel = CommandeStatus.normalize(commande.status);
    final dateStr = commande.dateCommande.toLocal().toString().split(' ')[0];

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Icône statut
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.receipt_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${commande.commandeID}',
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.ink, AppDarkColors.ink)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${commande.heure}',
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(AppColors.inkSubtle,
                              AppDarkColors.inkSubtle))
                      .copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // Badge statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _DishAvailability — Liste des plats avec toggle
// ═══════════════════════════════════════════════════════════
class _DishAvailability extends StatelessWidget {
  const _DishAvailability({
    required this.dishes,
    required this.isMounted,
    required this.onToggle,
    required this.onRefresh,
  });

  final List<Dish> dishes;
  final bool isMounted;
  final Future<void> Function(Dish, bool) onToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.resolve(
                AppColors.border, AppDarkColors.border),
            width: 0.5),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.brandSurface,
                        AppDarkColors.brandSurface),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.restaurant_menu_rounded,
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plats & portions',
                          style: AppTypography.titleMedium(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink))),
                      Text(
                        'Activez ou désactivez vos plats',
                        style: AppTypography.bodyMedium(
                                color: AppColors.resolve(AppColors.inkSubtle,
                                    AppDarkColors.inkSubtle))
                            .copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (dishes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _EmptySection(
                icon: Icons.no_food_outlined,
                message: 'Aucun plat enregistré.',
              ),
            )
          else
            ...dishes.take(6).map(
                  (dish) => _DishRow(
                    dish: dish,
                    isMounted: isMounted,
                    onToggle: onToggle,
                    onRefresh: onRefresh,
                  ),
                ),

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.isMounted,
    required this.onToggle,
    required this.onRefresh,
  });

  final Dish dish;
  final bool isMounted;
  final Future<void> Function(Dish, bool) onToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isAvailable = (dish.status ?? 0) == 1;

    return Material(
      color: AppColors.resolve(AppColors.card, AppDarkColors.card),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => DishDetails(
                dish_id: dish.dishID,
                from_page: 1,
              ),
            ),
          );
          if (isMounted) await onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: Row(
            children: [
              // Indicateur disponibilité
              // Indicateur disponibilité
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.resolve(AppColors.successLight,
                          AppDarkColors.successLight)
                      : AppColors.resolve(AppColors.errorLight,
                          AppDarkColors.errorLight),
                  // Ajout de la forme rounded ici
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  isAvailable
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: isAvailable
                      ? AppColors.resolve(
                          AppColors.success, AppDarkColors.success)
                      : AppColors.resolve(
                          AppColors.error, AppDarkColors.error),
                ),
              ),
              const SizedBox(width: 12),
              // Nom + infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dish.name ?? 'Plat sans nom',
                      style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dish.nb_servings ?? 0} portions · ${dish.nb_orders} commandes',
                      style: AppTypography.bodyMedium(
                              color: AppColors.resolve(AppColors.inkSubtle,
                                  AppDarkColors.inkSubtle))
                          .copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Switch
              Switch(
                value: isAvailable,
                activeColor: AppColors.resolve(
                    AppColors.success, AppDarkColors.success),
                onChanged: (v) => onToggle(dish, v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets utilitaires
// ═══════════════════════════════════════════════════════════

class _AddDishFAB extends StatelessWidget {
  const _AddDishFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor:
          AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      foregroundColor:
          AppColors.resolve(AppColors.ink, AppDarkColors.ink),
      elevation: 4,
      icon: Icon(
        Icons.add_rounded,
        color: Colors.white,
      ),
      label: Text('Ajouter un plat',
          style: AppTypography.labelMedium(color: Colors.white)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.resolve(
                AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
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
            child: Icon(Icons.storefront_outlined,
                color: AppColors.resolve(
                    AppColors.brand, AppDarkColors.brand),
                size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Aucun restaurant disponible',
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(
                      AppColors.ink, AppDarkColors.ink)),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Créez ou synchronisez votre restaurant pour afficher les commandes et les plats.',
            style: AppTypography.bodyMedium(
                color: AppColors.resolve(
                    AppColors.ink, AppDarkColors.ink)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            color: AppColors.resolve(
                AppColors.inkSubtle, AppDarkColors.inkSubtle),
            size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(message,
              style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))),
        ),
      ],
    );
  }
}

class _PRow extends StatelessWidget {
  const _PRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.accent),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: AppTypography.bodyMedium().copyWith(fontSize: 13)),
      ),
    ]);
  }
}
