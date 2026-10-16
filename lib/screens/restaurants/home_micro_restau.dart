import 'package:dios_delices/screens/orders/commande_details_page.dart';
import 'package:dios_delices/screens/orders/user_orders_page.dart';
import 'package:dios_delices/screens/dish/dish_details.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/dish/dish_form_page.dart';
import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/core/order_stage.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/comment_service.dart';
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
    orderStageOf(c) == OrderStage.ready &&
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

  List<LigneCommande> _lignes = [];
  _DashPeriod _period = _DashPeriod.week;

  /// Commandes en attente d'une réponse du restaurant (à accepter / refuser).
  int _toProcess = 0;

  /// Derniers avis clients du restaurant (backend Node).
  List<CommentData> _reviews = [];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    // Affichage immédiat depuis le cache, puis synchronisation serveur.
    _loadDashboard().then((_) {
      if (_isMounted) _refreshRemoteData();
    });
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
          _lignes = [];
          _toProcess = 0;
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
      final restLignes =
          allLignes.where((l) => cmdIds.contains(l.commandeID)).toList();

      _set(() {
        _restaurant = current;
        _dishes = restDishes;
        _commandes = restCmds;
        _lignes = restLignes;
        _toProcess = restCmds
            .where((c) => orderStageOf(c) == OrderStage.received)
            .length;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (_) {
      _set(() => _isLoading = false);
    }
  }

  Future<void> _refreshRemoteData() async {
    // Chaque source est rafraîchie indépendamment : une erreur réseau sur
    // l'une n'empêche pas d'afficher les autres.
    for (final refresh in <Future<void> Function()>[
      Restaurant.getAllRestaurantsDetails,
      Dish.getAllDishesDetails,
      Commande.refreshLocalCommandes, // backend Node (et non l'ancien Parse)
      LigneCommande.getAllLignesCommande,
    ]) {
      try {
        await refresh();
      } catch (_) {}
    }
    await _loadDashboard();
    await _loadReviews();
  }

  void _openOrders() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UserOrdersPage(showRestaurantOrders: true),
        ),
      ).then((_) {
        if (_isMounted) _refreshRemoteData();
      });

  Future<void> _loadReviews() async {
    final id = _restaurant?.restaurantID;
    if (id == null) return;
    final reviews = await CommentService.getCommentsByTarget(
      targetType: 1,
      targetID: id,
      limit: 3,
    );
    _set(() => _reviews = reviews);
  }

  _DashStats get _stats => _DashStats.compute(
        commandes: _commandes,
        lignes: _lignes,
        dishes: _dishes,
        period: _period,
      );

  String get _restaurantCountry {
    final c = (_restaurant?.country ?? '').trim();
    return c.isNotEmpty ? c : _country;
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
                  if (_toProcess > 0)
                    _ToProcessBanner(count: _toProcess, onTap: _openOrders),
                  _PeriodSelector(
                    value: _period,
                    onChanged: (p) => _set(() => _period = p),
                  ),
                  _FinanceCard(stats: _stats, country: _restaurantCountry),
                  _ActivityGrid(
                    stats: _stats,
                    country: _restaurantCountry,
                    onOpenOrders: _openOrders,
                  ),
                  _QualityCard(
                    rating: _restaurant?.note ?? 0,
                    stats: _stats,
                    reviews: _reviews,
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
    final stage = orderStageOf(commande);
    final statusColor = orderStageColor(stage);
    final statusLabel = orderStageLabel(
      AppLocalizations.of(context)!,
      stage,
      pickup: orderOtpModeFrom(deliveryMode: commande.deliveryMode) ==
          OrderOtpMode.pickup,
      refused: orderWasRefused(commande),
    );
    final dateStr = commande.dateCommande.toLocal().toString().split(' ')[0];

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommandeDetailsPage(commande: commande),
        ),
      ).then((_) => onRefresh()),
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

// ═══════════════════════════════════════════════════════════
// _ToProcessBanner — commandes en attente d'une réponse
// ═══════════════════════════════════════════════════════════
class _ToProcessBanner extends StatelessWidget {
  const _ToProcessBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: _Surface(
        radius: AppRadius.lg,
        onTap: onTap,
        color: Color.alphaBlend(brand.withValues(alpha: 0.07),
            AppColors.resolve(AppColors.card, AppDarkColors.card)),
        borderColor: brand.withValues(alpha: 0.45),
        borderWidth: 1.4,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: brand, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$count',
                style: AppTypography.titleMedium(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dash_to_process_title(count),
                    style: AppTypography.titleSmall(color: ink)),
                const SizedBox(height: 2),
                Text(l10n.dash_to_process_body,
                    style: AppTypography.bodySmall(color: muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: brand),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _PeriodSelector — Aujourd'hui / 7 jours / 30 jours
// ═══════════════════════════════════════════════════════════
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});
  final _DashPeriod value;
  final ValueChanged<_DashPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: border.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            for (final p in _DashPeriod.values)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(p),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == value
                          ? AppColors.resolve(AppColors.card, AppDarkColors.card)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: p == value ? [AppShadows.subtle] : null,
                    ),
                    child: Text(
                      p.label(l10n),
                      style: AppTypography.labelMedium(
                              color: p == value ? brand : ink)
                          .copyWith(
                              fontWeight: p == value
                                  ? FontWeight.w800
                                  : FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _FinanceCard — CA plats, livrées / en cours, ratio paiements
// ═══════════════════════════════════════════════════════════
class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.stats, required this.country});
  final _DashStats stats;
  final String country;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final share = stats.onlineShare;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: _Surface(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _IconChip(
                  icon: Icons.account_balance_wallet_rounded,
                  color: brand,
                  size: 34),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.dash_finances,
                  style: AppTypography.titleMedium(color: ink)),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.dash_revenue,
                style: AppTypography.labelMedium(color: muted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyUtil.formatPrice(stats.revenue, country),
                style: AppTypography.headlineLarge(color: ink)
                    .copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 2),
            Text(l10n.dash_revenue_hint,
                style: AppTypography.bodySmall(color: muted)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: _MoneyCell(
                  label: l10n.dash_revenue_done,
                  value: CurrencyUtil.formatPrice(stats.revenueDone, country),
                  color: success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MoneyCell(
                  label: l10n.dash_revenue_in_progress,
                  value:
                      CurrencyUtil.formatPrice(stats.revenueInProgress, country),
                  color: brand,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.dash_payment_mix,
                style: AppTypography.labelMedium(color: ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: share == null
                    ? ColoredBox(color: border)
                    : Row(children: [
                        if (share > 0)
                          Expanded(
                            flex: (share * 1000).round(),
                            child: ColoredBox(color: brand),
                          ),
                        if (share < 1)
                          Expanded(
                            flex: ((1 - share) * 1000).round(),
                            child: ColoredBox(color: accent),
                          ),
                      ]),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Wrap : sur un écran étroit, la seconde légende passe à la ligne.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              runSpacing: 6,
              children: [
              _Legend(
                color: brand,
                label:
                    '${l10n.dash_online} · ${share == null ? l10n.dash_no_data : '${(share * 100).round()} %'}',
              ),
              _Legend(
                color: accent,
                label:
                    '${l10n.dash_cash} · ${share == null ? l10n.dash_no_data : '${((1 - share) * 100).round()} %'}',
              ),
            ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall(
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted))),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// _ActivityGrid — volume, acceptation, panier moyen, refus
// ═══════════════════════════════════════════════════════════
class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.stats,
    required this.country,
    required this.onOpenOrders,
  });
  final _DashStats stats;
  final String country;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rate = stats.acceptanceRate;
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.dash_activity),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _StatCard(
                  value: '${stats.orders}',
                  label: l10n.dash_orders,
                  sublabel: l10n.see_all,
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  onTap: onOpenOrders,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  value: rate == null
                      ? l10n.dash_no_data
                      : '${(rate * 100).round()} %',
                  label: l10n.dash_acceptance,
                  sublabel: '${stats.accepted} / ${stats.accepted + stats.refused}',
                  icon: Icons.thumb_up_alt_rounded,
                  color: success,
                  progress: rate,
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: _StatCard(
                  value: stats.avgBasket > 0
                      ? CurrencyUtil.formatPrice(stats.avgBasket, country)
                      : l10n.dash_no_data,
                  label: l10n.dash_avg_basket,
                  sublabel: l10n.dash_avg_basket_hint,
                  icon: Icons.shopping_basket_rounded,
                  color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  value: '${stats.refused}',
                  label: l10n.dash_refused,
                  sublabel: l10n.dash_refused_hint,
                  icon: Icons.block_rounded,
                  color: AppColors.resolve(AppColors.error, AppDarkColors.error),
                  highlight: stats.refused >= 3,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _QualityCard — note moyenne (seuil 3,2) + top / flop des plats
// ═══════════════════════════════════════════════════════════
class _QualityCard extends StatelessWidget {
  const _QualityCard({
    required this.rating,
    required this.stats,
    required this.reviews,
  });
  final double rating;
  final _DashStats stats;
  final List<CommentData> reviews;

  static const double _exclusionThreshold = 3.2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final hasRating = rating > 0;
    final atRisk = hasRating && rating < _exclusionThreshold;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.dash_quality),
          const SizedBox(height: AppSpacing.md),
          _Surface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _IconChip(icon: Icons.star_rounded, color: accent, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.dash_rating,
                            style: AppTypography.labelMedium(color: muted)),
                        Text(
                          hasRating
                              ? '${rating.toStringAsFixed(1)} / 5'
                              : l10n.dash_rating_none,
                          style: AppTypography.titleLarge(
                              color: atRisk ? error : ink),
                        ),
                      ],
                    ),
                  ),
                  if (hasRating)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final filled = rating >= i + 0.75;
                        final half = !filled && rating >= i + 0.25;
                        return Icon(
                          filled
                              ? Icons.star_rounded
                              : half
                                  ? Icons.star_half_rounded
                                  : Icons.star_outline_rounded,
                          size: 18,
                          color: accent,
                        );
                      }),
                    ),
                ]),
                if (atRisk) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.dash_rating_warning,
                              style: AppTypography.bodySmall(color: ink)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _DishRanking(
                  title: l10n.dash_top_dishes,
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  items: stats.topDishes,
                ),
                const SizedBox(height: AppSpacing.md),
                _DishRanking(
                  title: l10n.dash_flop_dishes,
                  icon: Icons.trending_down_rounded,
                  color: muted,
                  items: stats.flopDishes,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RecentReviews(reviews: reviews),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RecentReviews — fil des derniers avis clients (cahier §2)
// ═══════════════════════════════════════════════════════════
class _RecentReviews extends StatelessWidget {
  const _RecentReviews({required this.reviews});
  final List<CommentData> reviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final brandSurface =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.forum_rounded, size: 16, color: brand),
          const SizedBox(width: 6),
          Text(l10n.dash_recent_reviews,
              style: AppTypography.labelMedium(color: ink)
                  .copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        if (reviews.isEmpty)
          Text(l10n.dash_no_reviews,
              style: AppTypography.bodySmall(color: muted))
        else
          for (final r in reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: brandSurface,
                    child: Text(
                      r.username.isNotEmpty ? r.username[0].toUpperCase() : '?',
                      style: AppTypography.labelMedium(color: brand)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              r.username.isNotEmpty ? r.username : 'Client',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMedium(color: ink)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          for (var i = 0; i < 5; i++)
                            Icon(
                              i < r.note
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 13,
                              color: accent,
                            ),
                        ]),
                        Text(
                          '${r.createdAt.day.toString().padLeft(2, '0')}/${r.createdAt.month.toString().padLeft(2, '0')}/${r.createdAt.year}',
                          style: AppTypography.bodySmall(color: muted)
                              .copyWith(fontSize: 11),
                        ),
                        if (r.commentaire.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            r.commentaire.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(color: ink)
                                .copyWith(height: 1.4),
                          ),
                        ],
                        if (r.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: r.tags
                                .take(3)
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: brandSurface,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(t,
                                          style: AppTypography.labelMedium(
                                                  color: brand)
                                              .copyWith(fontSize: 11)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _DishRanking extends StatelessWidget {
  const _DishRanking({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<_DishSales> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: AppTypography.labelMedium(color: ink)
                  .copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Text(l10n.dash_no_sales, style: AppTypography.bodySmall(color: muted))
        else
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${i + 1}',
                      style: AppTypography.labelMedium(color: color)
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(items[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(color: ink)),
                ),
                Text(l10n.dash_sold_count(items[i].quantity),
                    style: AppTypography.labelMedium(color: muted)),
              ]),
            ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════
// Indicateurs du tableau de bord vendeur (cahier des charges §2)
// Calculés à partir des commandes et lignes synchronisées depuis Node.
// ═══════════════════════════════════════════════════════════
enum _DashPeriod { today, week, month }

extension on _DashPeriod {
  DateTime get start {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _DashPeriod.today:
        return today;
      case _DashPeriod.week:
        return today.subtract(const Duration(days: 6));
      case _DashPeriod.month:
        return today.subtract(const Duration(days: 29));
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _DashPeriod.today:
        return l10n.dash_period_today;
      case _DashPeriod.week:
        return l10n.dash_period_week;
      case _DashPeriod.month:
        return l10n.dash_period_month;
    }
  }
}

class _DishSales {
  const _DishSales(this.name, this.quantity);
  final String name;
  final int quantity;
}

class _DashStats {
  const _DashStats({
    required this.orders,
    required this.accepted,
    required this.refused,
    required this.revenueDone,
    required this.revenueInProgress,
    required this.avgBasket,
    required this.onlineAmount,
    required this.cashAmount,
    required this.topDishes,
    required this.flopDishes,
  });

  final int orders, accepted, refused;
  final double revenueDone, revenueInProgress, avgBasket;
  final double onlineAmount, cashAmount;
  final List<_DishSales> topDishes, flopDishes;

  double get revenue => revenueDone + revenueInProgress;

  /// Part acceptée parmi les commandes déjà tranchées (acceptées ou refusées).
  double? get acceptanceRate =>
      (accepted + refused) == 0 ? null : accepted / (accepted + refused);

  /// Part des paiements en ligne (Mobile Money / portefeuille).
  double? get onlineShare {
    final total = onlineAmount + cashAmount;
    return total <= 0 ? null : onlineAmount / total;
  }


  static _DashStats compute({
    required List<Commande> commandes,
    required List<LigneCommande> lignes,
    required List<Dish> dishes,
    required _DashPeriod period,
  }) {
    final start = period.start;
    final inPeriod =
        commandes.where((c) => !c.dateCommande.toLocal().isBefore(start));

    var accepted = 0, refused = 0, orders = 0;
    var done = 0.0, inProgress = 0.0, basketSum = 0.0, basketCount = 0;
    var online = 0.0, cash = 0.0;
    final validIds = <String>{};

    for (final c in inPeriod) {
      orders++;
      final stage = orderStageOf(c);
      if (stage == OrderStage.cancelled) {
        if (orderWasRefused(c)) refused++;
        continue;
      }
      if (stage == OrderStage.awaitingPayment) continue; // rien d'encaissé
      if (stage != OrderStage.received) accepted++;

      final amount = orderFoodAmount(c);
      if (stage == OrderStage.delivered) {
        done += amount;
      } else {
        inProgress += amount;
      }
      basketSum += amount;
      basketCount++;
      validIds.add(c.commandeID.toString());

      final provider = (c.paymentProvider ?? '').toUpperCase();
      if (provider == 'NYOLE' || provider == 'WALLET') {
        online += amount;
      } else {
        cash += amount;
      }
    }

    // Ventes par plat sur la période (commandes valides uniquement).
    final names = {for (final d in dishes) d.dishID: d.name ?? 'Plat #${d.dishID}'};
    final sold = <int, int>{};
    final lineNames = <int, String>{};
    for (final l in lignes) {
      if (!validIds.contains(l.commandeID)) continue;
      sold[l.platID] = (sold[l.platID] ?? 0) + l.quantite;
      final n = l.nomPlat?.trim();
      if (n != null && n.isNotEmpty) lineNames[l.platID] = n;
    }
    String nameOf(int id) => names[id] ?? lineNames[id] ?? 'Plat #$id';

    final ranked = sold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked
        .take(3)
        .map((e) => _DishSales(nameOf(e.key), e.value))
        .toList();
    final topIds = ranked.take(3).map((e) => e.key).toSet();
    // Peu demandés : plats disponibles les moins vendus (y compris 0 vente).
    final flop = dishes
        .where((d) => (d.status ?? 0) == 1 && !topIds.contains(d.dishID))
        .map((d) => _DishSales(nameOf(d.dishID), sold[d.dishID] ?? 0))
        .toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));

    return _DashStats(
      orders: orders,
      accepted: accepted,
      refused: refused,
      revenueDone: done,
      revenueInProgress: inProgress,
      avgBasket: basketCount == 0 ? 0 : basketSum / basketCount,
      onlineAmount: online,
      cashAmount: cash,
      topDishes: top,
      flopDishes: flop.take(3).toList(),
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