import 'package:dios_delices/screens/orders/user_orders_page.dart';
import 'package:dios_delices/screens/dish/dish_details.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/dish/dish_form_page.dart';
import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/delivery_fee_calculator.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:dios_delices/widgets/dios_image.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// HomeMicroRestau — Dashboard cuisinier / vendeur
// ═══════════════════════════════════════════════════════════

// ── Retrait « À emporter » : accès tolérant aux champs de la commande ──────
// (isOtpVerified : false tant que le modèle Commande ne l'expose pas)
bool _otpVerifiedOf(Commande c) {
  try {
    return (c as dynamic).isOtpVerified == true;
  } catch (_) {
    return false;
  }
}

/// Commande « À emporter » prête, pas encore remise au client.
bool _canValidatePickup(Commande c) =>
    orderOtpModeFrom(deliveryMode: c.deliveryMode) == OrderOtpMode.pickup &&
    CommandeStatus.normalize(c.status) == CommandeStatus.ready &&
    !_otpVerifiedOf(c);

class HomeMicroRestau extends StatefulWidget {
  const HomeMicroRestau({super.key});

  @override
  State<HomeMicroRestau> createState() => _HomeMicroRestauState();
}

class _HomeMicroRestauState extends State<HomeMicroRestau> {
  /// Le skeleton n'apparaît qu'au premier chargement.
  /// Les rafraîchissements suivants (pull-to-refresh, retour d'une page,
  /// bascule d'un plat) se font en silence, sans remplacer le contenu.
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _isMounted = false;

  Restaurant? _restaurant;
  List<Dish> _dishes = [];
  List<Commande> _commandes = [];
  String _country = 'RDC';

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
    if (!_hasLoaded) _set(() => _isLoading = true);

    try {
      final session = await SessionService.readSession();
      _country = session.country;
      if (session.restaurantId == null) {
        _set(() {
          _restaurant = null;
          _dishes = [];
          _commandes = [];
          _pendingOrders = _confirmedOrders = _cancelledOrders =
              _availableDishes = _unavailableDishes =
                  _totalAvailableServings = _soldServings = 0;
          _isLoading = false;
          _hasLoaded = true;
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
      final matchRestaurantId = session.restaurantId;
      final restCmds = allCommandes.where((c) {
        final matchRid = c.restaurateurID == session.userId &&
            c.restaurateurID != 0;
        final matchRsid = matchRestaurantId != null &&
            c.restauID == matchRestaurantId &&
            c.restauID != 0;
        return matchRid || matchRsid;
      }).toList()
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
        _hasLoaded = true;
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
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        floatingActionButton: (_restoValid && !_isLoading)
            ? _AddDishFAB(
                onPressed: () async {
                  await Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => DishFormPage()));
                  if (_isMounted) await _refreshRemoteData();
                },
              )
            : null,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          child: _isLoading ? _buildSkeleton() : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      key: const ValueKey('content'),
      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      backgroundColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
      onRefresh: _refreshRemoteData,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Column(children: [
                _HeroHeader(restaurant: _restaurant, country: _country),
                if (_restaurant == null)
                  _EmptyState(onRefresh: _refreshRemoteData)
                else if (!_restoValid)
                  _buildPendingFullPage()
                else ...[
                  _KpiGrid(
                    pending: _pendingOrders,
                    cancelled: _cancelledOrders,
                    available: _availableDishes,
                    unavailable: _unavailableDishes,
                    sold: _soldServings,
                    totalServings: _totalAvailableServings,
                  ),
                  _QuickActions(
                    restaurant: _restaurant!,
                    onRefresh: _refreshRemoteData,
                  ),
                  _RecentOrders(
                    commandes: _commandes,
                    onRefresh: _refreshRemoteData,
                  ),
                  _DishAvailability(
                    dishes: _dishes,
                    onToggle: _toggleDish,
                    onRefresh: _refreshRemoteData,
                  ),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skeleton : même structure que la vraie page ──────────
  Widget _buildSkeleton() {
    Widget row(int n, double h) => Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: _Bone(height: h, radius: AppRadius.lg)),
            ],
          ],
        );

    return KeyedSubtree(
      key: const ValueKey('skeleton'),
      child: SafeArea(
        bottom: false,
        child: _Shimmer(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone(height: 200, radius: AppRadius.xl),
                const SizedBox(height: AppSpacing.xl),
                const _Bone(width: 110, height: 18),
                const SizedBox(height: AppSpacing.md),
                row(2, 118),
                const SizedBox(height: AppSpacing.sm),
                row(2, 118),
                const SizedBox(height: AppSpacing.xl),
                const _Bone(width: 130, height: 18),
                const SizedBox(height: AppSpacing.md),
                row(3, 92),
                const SizedBox(height: AppSpacing.xl),
                _Bone(height: 250, radius: AppRadius.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Restaurant en attente de validation ──────────────────
  Widget _buildPendingFullPage() {
    final l10n = AppLocalizations.of(context)!;
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 32),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.hourglass_bottom_rounded, color: accent, size: 44),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.store_pending_validation,
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium().copyWith(fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.store_pending_validation_body,
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge(
            color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
          ),
        ),
        const SizedBox(height: 28),
        _Surface(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(children: [
            _PRow(Icons.email_rounded, 'Vous serez notifié par email'),
            const _Hairline(indent: 0),
            _PRow(Icons.restaurant_menu_rounded,
                'Vous pourrez ajouter vos plats'),
            const _Hairline(indent: 0),
            _PRow(Icons.receipt_long_rounded, 'Et recevoir des commandes'),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _HeroHeader — Bannière restaurant
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.restaurant, required this.country});
  final Restaurant? restaurant;
  final String country;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    // Dégradé construit à partir de la couleur résolue (clair / sombre).
    final gradTop = Color.lerp(brand, Colors.white, 0.10)!;
    final gradBottom = Color.lerp(brand, Colors.black, 0.30)!;
    final r = restaurant;
    final isOpen = r?.isCurrentlyOpen ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradTop, gradBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.30),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(children: [
          // Deux disques discrets : de la profondeur sans bruit visuel.
          const Positioned(right: -50, top: -50, child: _Orb(size: 170, alpha: 0.08)),
          const Positioned(right: 30, bottom: -70, child: _Orb(size: 130, alpha: 0.06)),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 6),
                      Text(l10n.myRestaurant,
                          style:
                              AppTypography.labelMedium(color: Colors.white)),
                    ]),
                  ),
                  const Spacer(),
                  if (r != null) _StatusPill(isOpen: isOpen),
                ]),
                const SizedBox(height: AppSpacing.md),
                Text(
                  r?.name ?? 'Restaurant non configuré',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge(color: Colors.white)
                      .copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (r != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        color: Colors.white.withValues(alpha: 0.85), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium(
                                color: Colors.white.withValues(alpha: 0.9))
                            .copyWith(fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: _InfoCell(
                          icon: Icons.delivery_dining_rounded,
                          text: r.deliveryFee > 0
                              ? '${CurrencyUtil.formatPrice(r.deliveryFee, country)} livraison'
                              : '${DeliveryFeeCalculator.getStartingFeeLabel(r)} livraison',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      Expanded(
                        child: _InfoCell(
                          icon: Icons.schedule_rounded,
                          text: r.openingHours,
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.alpha});
  final double size, alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium(color: Colors.white)
              .copyWith(fontSize: 12),
        ),
      ),
    ]);
  }
}

// ── Badge statut Ouvert / Fermé ───────────────────────────
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOpen ? success : Colors.white54,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOpen ? l10n.open : l10n.closed,
          style: AppTypography.labelMedium(color: Colors.white)
              .copyWith(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _KpiGrid — 4 cartes métriques (même design pour toutes)
// ═══════════════════════════════════════════════════════════
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.pending,
    required this.cancelled,
    required this.available,
    required this.unavailable,
    required this.sold,
    required this.totalServings,
  });

  final int pending, cancelled, available, unavailable, sold, totalServings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.overview),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _StatCard(
                  value: '$pending',
                  label: l10n.pending_orders,
                  sublabel: l10n.to_process,
                  icon: Icons.hourglass_top_rounded,
                  color:
                      AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                  highlight: pending > 0,
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
                child: _StatCard(
                  value: '$cancelled',
                  label: l10n.cancelled_orders,
                  sublabel: l10n.total,
                  icon: Icons.cancel_outlined,
                  color: AppColors.resolve(AppColors.error, AppDarkColors.error),
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _StatCard(
                  value: '$available',
                  label: l10n.available_dishes,
                  sublabel: l10n.unavailable_dishes_num(unavailable),
                  icon: Icons.restaurant_menu_rounded,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  progress: (available + unavailable) > 0
                      ? available / (available + unavailable)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  value: '$sold',
                  label: l10n.servings_sold,
                  sublabel: l10n.available_servings_of(totalServings),
                  icon: Icons.trending_up_rounded,
                  color:
                      AppColors.resolve(AppColors.success, AppDarkColors.success),
                  progress: totalServings > 0
                      ? (sold / totalServings).clamp(0.0, 1.0)
                      : null,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.progress,
    this.highlight = false,
    this.onTap,
  });

  final String value, label, sublabel;
  final IconData icon;
  final Color color;
  final double? progress; // null = pas de barre
  final bool highlight; // met la carte en avant (ex : commandes à traiter)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return _Surface(
      radius: AppRadius.lg,
      onTap: onTap,
      color: highlight ? Color.alphaBlend(color.withValues(alpha: 0.08), card) : card,
      borderColor: highlight ? color.withValues(alpha: 0.45) : null,
      borderWidth: highlight ? 1.5 : 0.5,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _IconChip(icon: icon, color: color, size: 34),
            const Spacer(),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: muted.withValues(alpha: 0.7), size: 20),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.displayMedium().copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: highlight ? color : ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium(color: ink)
                  .copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(color: muted)),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor:
                    AppColors.resolve(AppColors.border, AppDarkColors.border),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _QuickActions — 3 actions rapides
// ═══════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.restaurant, required this.onRefresh});

  final Restaurant restaurant;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.quickActions),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.receipt_long_rounded,
                label: l10n.orders,
                color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
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
                label: l10n.addDish,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                onTap: () async {
                  await Navigator.push(context,
                      CupertinoPageRoute(builder: (_) => const DishFormPage()));
                  await onRefresh();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionTile(
                icon: Icons.store_mall_directory_outlined,
                label: l10n.manage,
                color:
                    AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestaurantDetails(
                          restaurant_id: restaurant.restaurantID),
                    ),
                  ).then((_) => onRefresh());
                },
              ),
            ),
          ]),
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
    return _Surface(
      radius: AppRadius.lg,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(children: [
        _IconChip(icon: icon, color: color, size: 44, iconSize: 22),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
              .copyWith(fontSize: 12),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RecentOrders — 3 dernières commandes
// ═══════════════════════════════════════════════════════════
class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.commandes, required this.onRefresh});
  final List<Commande> commandes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Les retraits à valider passent en premier : une commande « À emporter »
    // prête ne doit pas disparaître sous les 3 dernières commandes.
    final toValidate = commandes.where(_canValidatePickup).toList();
    final others = commandes.where((c) => !_canValidatePickup(c)).toList();
    final limit = toValidate.length > 3 ? toValidate.length : 3;
    final recent = [...toValidate, ...others].take(limit).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: _Surface(
        radius: AppRadius.xl,
        child: Column(children: [
          _PanelHeader(
            icon: Icons.receipt_long_rounded,
            title: l10n.last_orders,
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const UserOrdersPage(showRestaurantOrders: true),
                ),
              ),
              child: Text(
                l10n.see_all,
                style: AppTypography.labelMedium(
                    color:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
              ),
            ),
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
              child: _EmptySection(
                icon: Icons.inbox_outlined,
                message: l10n.no_order_received_yet,
              ),
            )
          else
            for (var i = 0; i < recent.length; i++) ...[
              const _Hairline(),
              _OrderRow(commande: recent[i], onRefresh: onRefresh),
            ],
        ]),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.commande, required this.onRefresh});
  final Commande commande;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = CommandeStatus.color(commande.status);
    final statusLabel = CommandeStatus.normalize(commande.status);
    final dateStr = commande.dateCommande.toLocal().toString().split(' ')[0];

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UserOrdersPage(showRestaurantOrders: true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(children: [
          Row(children: [
          _IconChip(icon: Icons.receipt_rounded, color: statusColor, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.order_num(commande.commandeID),
                  style: AppTypography.labelMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${commande.heure}',
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.inkSubtle, AppDarkColors.inkSubtle))
                      .copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                  color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          ]),
          // « À emporter » prête : le client donne son code, on valide le retrait
          if (_canValidatePickup(commande)) ...[
            const SizedBox(height: AppSpacing.md),
            OtpGradientButton(
              label: 'Valider le retrait client',
              icon: Icons.storefront_rounded,
              onPressed: () async {
                final ok = await showRestaurateurOtpDialog(
                  context,
                  orderId: commande.commandeID,
                );
                if (ok == true) await onRefresh(); // recharge le statut
              },
            ),
          ],
        ]),
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
    required this.onToggle,
    required this.onRefresh,
  });

  final List<Dish> dishes;
  final Future<void> Function(Dish, bool) onToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = dishes.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: _Surface(
        radius: AppRadius.xl,
        child: Column(children: [
          _PanelHeader(
            icon: Icons.restaurant_menu_rounded,
            title: l10n.dishes_and_servings,
            subtitle: l10n.activate_deactivate_dishes,
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
              child: _EmptySection(
                icon: Icons.no_food_outlined,
                message: l10n.no_dish_registered,
              ),
            )
          else
            for (final dish in shown) ...[
              const _Hairline(),
              _DishRow(dish: dish, onToggle: onToggle, onRefresh: onRefresh),
            ],
        ]),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.onToggle,
    required this.onRefresh,
  });

  final Dish dish;
  final Future<void> Function(Dish, bool) onToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final isAvailable = (dish.status ?? 0) == 1;
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => DishDetails(dish_id: dish.dishID, from_page: 1),
          ),
        );
        await onRefresh();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(children: [
          // Un plat indisponible est visuellement estompé.
          Expanded(
            child: Opacity(
              opacity: isAvailable ? 1 : 0.55,
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: DiosImage(url: dish.image, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name ?? 'Plat sans nom',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dish.nb_servings ?? 0} portions · ${dish.nb_orders} commandes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                                color: AppColors.resolve(AppColors.inkSubtle,
                                    AppDarkColors.inkSubtle))
                            .copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          Switch(
            value: isAvailable,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? success : null,
            ),
            onChanged: (v) => onToggle(dish, v),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// États vides & utilitaires
// ═══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _Surface(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_outlined, color: brand, size: 34),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.no_restaurant_available,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Créez ou synchronisez votre restaurant pour afficher les commandes et les plats.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted)),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.refresh),
          ),
        ]),
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
    return Row(children: [
      Icon(icon,
          color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle),
          size: 20),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(message,
            style: AppTypography.bodyMedium(
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted))),
      ),
    ]);
  }
}

class _PRow extends StatelessWidget {
  const _PRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon,
            size: 18,
            color: AppColors.resolve(AppColors.accent, AppDarkColors.accent)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: AppTypography.bodyMedium().copyWith(fontSize: 13)),
        ),
      ]),
    );
  }
}

class _AddDishFAB extends StatelessWidget {
  const _AddDishFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(AppLocalizations.of(context)!.addDish,
          style: AppTypography.labelMedium(color: Colors.white)),
    );
  }
}

// ── Briques de design partagées ───────────────────────────

/// Surface "carte" unique : fond, bordure fine, ombre légère, ripple.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.onTap,
    this.radius,
    this.color,
    this.borderColor,
    this.borderWidth = 0.5,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? radius;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? AppRadius.lg);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: r,
        border: Border.all(
          color: borderColor ??
              AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: borderWidth,
        ),
        boxShadow: [AppShadows.subtle],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Pastille d'icône teintée (fond = couleur à 12 %).
class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.color,
    required this.size,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.titleMedium(
          color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, trailing == null ? AppSpacing.lg : AppSpacing.sm, AppSpacing.md),
      child: Row(children: [
        _IconChip(
          icon: icon,
          color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
          size: 34,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.titleMedium(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.inkSubtle, AppDarkColors.inkSubtle))
                      .copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = AppSpacing.lg});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      endIndent: indent,
      color: AppColors.resolve(AppColors.border, AppDarkColors.border),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Skeleton : shimmer sans dépendance externe
// ═══════════════════════════════════════════════════════════

/// Bloc neutre (blanc) : c'est le [_Shimmer] parent qui le colore.
class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Reflet lumineux qui balaye tous les enfants en même temps.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final highlight = Color.lerp(base, Colors.white, isDark ? 0.10 : 0.65)!;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: _SlideGradient(_controller.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);
  final double progress;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}