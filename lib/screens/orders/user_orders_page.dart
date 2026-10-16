import 'dart:async';
import 'dart:convert';

import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/core/order_stage.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_screen.dart';
import 'commande_details_page.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/order_otp_widgets.dart';
import '../../utils/payment_provider_label.dart';

// ── Code OTP de remise : accès tolérant aux champs de la commande ──────────
// (ils renvoient null / false tant que le modèle Commande n'a pas
//  `retrievalOtp` et `isOtpVerified`)
String? _otpOf(Commande c) {
  try {
    final v = (c as dynamic).retrievalOtp;
    return v?.toString();
  } catch (_) {
    return null;
  }
}

bool _otpVerifiedOf(Commande c) {
  try {
    return (c as dynamic).isOtpVerified == true;
  } catch (_) {
    return false;
  }
}

bool _isPickupOrder(Commande c) =>
    orderOtpModeFrom(deliveryMode: c.deliveryMode) == OrderOtpMode.pickup;

class UserOrdersPage extends StatefulWidget {
  final bool showRestaurantOrders;
  const UserOrdersPage({super.key, this.showRestaurantOrders = false});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  String _buildAuthErrorMessage(Object e) {
    final text = e.toString().toLowerCase();
    final isInvalidAuth = RegExp(
      r'(invalid session|invalid.*session|session.*invalid|unauthorized|forbidden|invalid.*token|auth(entication)?|wrong.*password|invalid.*credentials|credentials.*invalid)',
      caseSensitive: false,
    ).hasMatch(text);

    if (isInvalidAuth) {
      // Returning raw string as this error is for debugging
      return 'Connexion impossible : identifiants de connexion incorrects. Veuillez vous reconnecter.';
    }

    return 'Erreur : ${e.toString()}';
  }

  /// Toutes les commandes de l'utilisateur (avant filtre).
  List<Commande> _allOrders = [];
  bool isLoading = true;
  bool _restoValid = true;
  bool _isAdmin = false;
  Map<int, String> dishNames = {};
  Map<int, String> restoNames = {};
  _OrderFilter _filter = _OrderFilter.all;
  String _country = 'RDC';
  final LiveQuery liveQuery = LiveQuery();
  Subscription? sub;
  Timer? _refreshTimer;

  /// Commandes affichées selon le filtre choisi.
  List<Commande> get commandes =>
      _allOrders.where((c) => _filter.matches(orderStageOf(c))).toList();

  @override
  void initState() {
    super.initState();
    loadOrders();
    _startAutoRefresh();
  }

  /// Backend Node : rafraîchissement périodique. Ancien compte Parse :
  /// abonnement LiveQuery comme avant.
  Future<void> _startAutoRefresh() async {
    if (await SessionService.hasNodeSession()) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) loadOrders();
      });
    } else {
      await _listen();
    }
  }

  Future<void> _listen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
    sub = await liveQuery.client.subscribe(query);
    sub!.on(LiveQueryEvent.create, (_) async {
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.update, (_) async {
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.delete, (_) async {
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();
    _country = session.country;
    _isAdmin = session.role.isAdmin;

    // Vérifier la validité du restaurant pour les restaurateurs
    if (widget.showRestaurantOrders && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final resto = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoValid = resto?.valid == 1;
    }

    try {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
    } catch (_) {
      // Hors ligne : on affiche le cache local.
    }
    final allC = await Commande.fetchCommandesFromDB();
    final allD = await Dish.fetchDishesFromDB();
    final allR = await Restaurant.fetchRestaurantsFromDB();

    final dn = <int, String>{};
    for (final d in allD) {
      dn[d.dishID] = d.name ?? 'Plat ${d.dishID}';
    }
    final rn = <int, String>{};
    for (final r in allR) {
      rn[r.restaurantID] = r.name;
    }

    final mine = <Commande>[];
    final restaurantId = session.restaurantId;
    for (final c in allC) {
      if (session.role.isAdmin) {
        mine.add(c);
      } else if (widget.showRestaurantOrders) {
        final matchRestaurateurId =
            c.restaurateurID == session.userId && c.restaurateurID != 0;
        final matchRestaurantId = restaurantId != null &&
            c.restauID == restaurantId &&
            c.restauID != 0;
        if (matchRestaurateurId || matchRestaurantId) mine.add(c);
      } else if (c.userID == session.userId) {
        mine.add(c);
      }
    }
    mine.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
      dishNames = dn;
      restoNames = rn;
      _allOrders = mine;
      isLoading = false;
      _loadedOnce = true;
    });
  }

  Future<List<LigneCommande>> getLignes(int id) =>
      LigneCommande.fetchLignesCommandeByCommandeID(id);

  /// Confirmation puis changement de statut (mêmes règles que le détail).
  Future<void> _changeStatus(
    Commande c, {
    required String status,
    required String title,
    required String body,
    required String confirmLabel,
    required Color color,
    required String successMessage,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(title, style: AppTypography.titleMedium(color: _ink)),
        content: Text(body,
            style: AppTypography.bodyMedium(color: _muted)
                .copyWith(height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => isLoading = true);
    try {
      await CommandeApi.updateOrderStatus(c.commandeID.toString(), status);
      await loadOrders();
      if (mounted) _snack(successMessage, AppColors.success);
    } catch (e) {
      final message = e is NodeAuthException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      if (mounted) _snack(message, AppColors.error);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(message),
      ));
  }

  bool _paidOnline(Commande c) {
    final provider = (_paymentProviderOf(c) ?? '').toUpperCase();
    return provider == 'WALLET' ||
        (provider == 'NYOLE' &&
            CommandeStatus.normalize(c.status) == CommandeStatus.paid);
  }

  void _accept(Commande c) {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(c,
        status: CommandeStatus.confirmed, // → EN_PREPARATION
        title: l10n.order_accept,
        body: l10n.order_accept_body,
        confirmLabel: l10n.order_accept,
        color: AppColors.success,
        successMessage: l10n.order_accepted_done);
  }

  void _markReady(Commande c) {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(c,
        status: CommandeStatus.ready, // → READY (recherche d'un livreur)
        title: l10n.order_mark_ready,
        body: _isPickupOrder(c)
            ? l10n.order_step_ready_pickup
            : l10n.order_mark_ready_body,
        confirmLabel: l10n.order_mark_ready,
        color: AppColors.success,
        successMessage: l10n.order_ready_done);
  }

  void _refuse(Commande c) {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(c,
        status: CommandeStatus.cancelled, // → REFUSED côté restaurant
        title: l10n.order_refuse_title,
        body: l10n.order_refuse_body,
        confirmLabel: l10n.order_refuse,
        color: AppColors.error,
        successMessage: l10n.order_refused_done);
  }

  void _cancel(Commande c) {
    final l10n = AppLocalizations.of(context)!;
    final refund = _paidOnline(c);
    _changeStatus(c,
        status: CommandeStatus.cancelled,
        title: l10n.commande_details_cancel_order,
        body: refund
            ? '${l10n.order_cancel_free_hint}\n${l10n.order_cancel_refund_wallet}'
            : l10n.order_cancel_free_hint,
        confirmLabel: l10n.user_orders_yes_cancel,
        color: AppColors.error,
        successMessage: refund
            ? l10n.order_cancelled_refunded
            : l10n.order_cancelled_done);
  }

  /// Commande « À emporter » prête, pas encore remise au client.
  bool _canValidatePickup(Commande c, OrderStage stage) =>
      widget.showRestaurantOrders &&
      !_isAdmin &&
      _isPickupOrder(c) &&
      stage == OrderStage.ready &&
      !_otpVerifiedOf(c);

  /// Dialogue « Valider le retrait du client » (code à 4 caractères).
  Future<void> _validatePickup(Commande c) async {
    final ok = await showRestaurateurOtpDialog(
      context,
      orderId: c.commandeID,
    );
    if (ok == true && mounted) await loadOrders();
  }

  // ── Raccourcis couleurs (thème clair / sombre) ───────────
  Color get _ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  Color get _muted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  Color get _subtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  Color get _cardBg => AppColors.resolve(AppColors.card, AppDarkColors.card);
  Color get _warm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  Color get _line => AppColors.resolve(AppColors.border, AppDarkColors.border);
  Color get _brandC => AppColors.resolve(AppColors.brand, AppDarkColors.brand);

  /// `true` après le premier chargement (squelettes au tout premier affichage).
  bool _loadedOnce = false;

  void _openDetails(Commande c) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CommandeDetailsPage(commande: c)),
      );

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final showSkeleton = isLoading && !_loadedOnce && commandes.isEmpty;
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(
          widget.showRestaurantOrders
              ? AppLocalizations.of(context)!.user_orders_received
              : AppLocalizations.of(context)!.user_orders_my,
        ),
        actions: [
          if (widget.showRestaurantOrders)
            _PendingBadge(
              count: _allOrders
                  .where((c) => orderStageOf(c) == OrderStage.received)
                  .length,
            ),
        ],
      ),
      body: widget.showRestaurantOrders && !_restoValid
          ? _buildPendingFullPage()
          : Column(children: [
              _buildFilters(isSmallScreen),
              // fine barre de progression pendant un rafraîchissement
              SizedBox(
                height: 2,
                child: (isLoading && !showSkeleton)
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        color: _brandC,
                        backgroundColor: Colors.transparent,
                      )
                    : null,
              ),
              Expanded(
                child: showSkeleton
                    ? ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: const [
                          _OrderSkeleton(),
                          _OrderSkeleton(),
                          _OrderSkeleton(),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: loadOrders,
                        color: _brandC,
                        child: commandes.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 60),
                                  _EmptyOrders(
                                      isRestaurant: widget.showRestaurantOrders),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 40),
                                itemCount: commandes.length,
                                itemBuilder: (_, i) =>
                                    _buildCard(commandes[i], isSmallScreen),
                              ),
                      ),
              ),
            ]),
    );
  }

  Widget _buildFilters(bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final filters = widget.showRestaurantOrders
        ? const [
            _OrderFilter.all,
            _OrderFilter.newOrders,
            _OrderFilter.preparing,
            _OrderFilter.ready,
            _OrderFilter.done,
            _OrderFilter.cancelled,
          ]
        : const [
            _OrderFilter.all,
            _OrderFilter.active,
            _OrderFilter.done,
            _OrderFilter.cancelled,
          ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final active = _filter == f;
          final count =
              _allOrders.where((c) => f.matches(orderStageOf(c))).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: active ? _brandC : _cardBg,
              shape: StadiumBorder(
                side: BorderSide(color: active ? _brandC : _line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _filter = f),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        f.label(l10n),
                        style: AppTypography.labelMedium(
                                color: active ? Colors.white : _ink)
                            .copyWith(
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w600),
                      ),
                      if (f != _OrderFilter.all && count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withValues(alpha: 0.25)
                                : _brandC.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelMedium(
                                    color: active ? Colors.white : _brandC)
                                .copyWith(
                                    fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _orderDate(Commande c) {
    try {
      final locale = Localizations.localeOf(context).toString();
      return DateFormat('d MMM · HH:mm', locale)
          .format(c.dateCommande.toLocal());
    } catch (_) {
      return '${c.dateCommande.toLocal().toString().split(' ')[0]} · ${c.heure}';
    }
  }

  Widget _buildCard(Commande c, bool isSmall) {
    final l10n = AppLocalizations.of(context)!;
    final stage = orderStageOf(c);
    final stageColor = orderStageColor(stage);
    final isPickup = _isPickupOrder(c);
    final stageLabel = orderStageLabel(l10n, stage,
        pickup: isPickup, refused: orderWasRefused(c));
    final isRestaurantView = widget.showRestaurantOrders;
    final isOwner = isRestaurantView && !_isAdmin;
    final payLabel = paymentProviderLabel(_paymentProviderOf(c));
    final country = (c.country ?? '').trim().isNotEmpty ? c.country! : _country;

    // ── Action principale (une seule à la fois) ──
    Widget? primary;
    var showRefuse = false;
    if (isOwner) {
      if (stage == OrderStage.received) {
        primary = _PrimaryActionButton(
          label: l10n.order_accept,
          icon: Icons.soup_kitchen_rounded,
          color: AppColors.success,
          onTap: () => _accept(c),
        );
        showRefuse = true;
      } else if (stage == OrderStage.preparing) {
        primary = _PrimaryActionButton(
          label: l10n.order_mark_ready,
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          onTap: () => _markReady(c),
        );
        showRefuse = true;
      } else if (_canValidatePickup(c, stage)) {
        primary = _PrimaryActionButton(
          label: l10n.order_validate_pickup,
          icon: Icons.storefront_rounded,
          color: AppColors.success,
          onTap: () => _validatePickup(c),
        );
      } else if (stage == OrderStage.ready && !isPickup) {
        primary = _InfoPill(
          icon: Icons.hourglass_top_rounded,
          label: l10n.orders_waiting_courier,
          color: _brandC,
        );
      } else if (stage == OrderStage.awaitingPayment) {
        primary = _InfoPill(
          icon: Icons.hourglass_top_rounded,
          label: l10n.order_stage_awaiting_payment,
          color: orderStageColor(OrderStage.awaitingPayment),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _line.withValues(alpha: 0.7)),
        boxShadow: [AppShadows.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Liseré de couleur de l'étape
          Container(height: 3, color: stageColor.withValues(alpha: 0.85)),

          // ── En-tête cliquable ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetails(c),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 14, AppSpacing.md, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_stageIcon(stage, isPickup),
                          color: stageColor, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRestaurantView
                                ? '${l10n.orders} #${c.commandeID}'
                                : restoNames[c.restauID] ??
                                    '${l10n.orders} #${c.commandeID}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall(color: _ink)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRestaurantView
                                ? _orderDate(c)
                                : '#${c.commandeID} · ${_orderDate(c)}',
                            style: AppTypography.bodySmall(color: _subtle),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: stageLabel, color: stageColor),
                  ],
                ),
              ),
            ),
          ),

          // ── Mode de remise · paiement · total ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: isPickup
                            ? Icons.shopping_bag_outlined
                            : Icons.delivery_dining_rounded,
                        label: isPickup ? 'À emporter' : 'Livraison',
                      ),
                      if (payLabel != null)
                        _MetaChip(
                          icon: paymentProviderIcon(_paymentProviderOf(c)),
                          label: payLabel,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyUtil.formatPrice(c.totalAmount, country),
                  style: AppTypography.titleSmall(color: _ink)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),

          // ── Paiement Mobile Money non confirmé (client) ──
          if (!isRestaurantView && stage == OrderStage.awaitingPayment)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
              child: _InfoPill(
                icon: Icons.hourglass_top_rounded,
                label: l10n.order_stage_awaiting_payment,
                color: orderStageColor(OrderStage.awaitingPayment),
              ),
            ),

          // ── Plats (repliable) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
            child: _OrderDishes(
              key: ValueKey('order_dishes_${c.commandeID}'),
              orderId: c.commandeID,
              loader: getLignes,
              dishNames: dishNames,
              country: country,
              subtotalLabel: l10n.subtotal,
            ),
          ),

          // ── Actions restaurateur ──
          if (isOwner && stage != OrderStage.cancelled &&
              stage != OrderStage.delivered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
              child: Row(
                children: [
                  if (primary != null) Expanded(child: primary),
                  if (primary == null) const Spacer(),
                  if (showRefuse) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _IconActionButton(
                      icon: Icons.block_rounded,
                      color: AppColors.error,
                      onTap: () => _refuse(c),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  _IconActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: _muted,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                orderId: c.commandeID,
                                recipientName: 'Client #${c.commandeID}'))),
                  ),
                ],
              ),
            ),

          // ── Actions client ──
          if (!isRestaurantView && orderStageCancellableByCustomer(stage))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(c),
                  icon: Icon(Icons.cancel_outlined,
                      size: 18,
                      color: AppColors.resolve(
                          AppColors.error, AppDarkColors.error)),
                  label: Text(
                    l10n.commande_details_cancel_order,
                    style: AppTypography.labelLarge(
                        color: AppColors.resolve(
                            AppColors.error, AppDarkColors.error)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.resolve(
                                AppColors.error, AppDarkColors.error)
                            .withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            ),
          if (!isRestaurantView && stage == OrderStage.delivered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
              child: Row(
                children: [
                  Expanded(
                    child: _RateButton(
                      label: l10n.user_orders_rate,
                      color: _brandC,
                      onTap: () => _showRate(c.commandeID, c.restauID),
                    ),
                  ),
                  if (c.livreurID != null && !isPickup) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RateButton(
                        label: l10n.user_orders_rate_driver,
                        color: AppColors.resolve(
                            AppColors.success, AppDarkColors.success),
                        onTap: () => _showRateLivreur(c.livreurID!, c.commandeID),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ── Suivi livraison client ──
          if (!isRestaurantView &&
              !isPickup &&
              (stage == OrderStage.preparing ||
                  stage == OrderStage.ready ||
                  stage == OrderStage.onTheWay))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 4, AppSpacing.md, AppSpacing.md),
              child: _DeliveryTracker(
                orderStatus: c.status,
                status: c.deliveryStatus,
                lat: c.livreurLat,
                lng: c.livreurLng,
              ),
            ),

          // ── Pied : voir le détail ──
          Divider(height: 1, color: _line.withValues(alpha: 0.5)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetails(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      l10n.user_orders_see_detail,
                      style: AppTypography.labelMedium(color: _brandC)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, size: 20, color: _brandC),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _stageIcon(OrderStage stage, bool pickup) {
    switch (stage) {
      case OrderStage.awaitingPayment:
        return Icons.hourglass_top_rounded;
      case OrderStage.received:
        return Icons.receipt_long_rounded;
      case OrderStage.preparing:
        return Icons.soup_kitchen_rounded;
      case OrderStage.ready:
        return pickup ? Icons.shopping_bag_rounded : Icons.check_circle_rounded;
      case OrderStage.onTheWay:
        return Icons.delivery_dining_rounded;
      case OrderStage.delivered:
        return Icons.task_alt_rounded;
      case OrderStage.cancelled:
        return Icons.cancel_rounded;
    }
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
                shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: AppColors.accent, size: 48)),
        const SizedBox(height: 28),
        Text(AppLocalizations.of(context)!.user_orders_pending_title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium().copyWith(fontSize: 20)),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.user_orders_pending_body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
        const SizedBox(height: 32),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: AppColors.resolve(
                        AppColors.border, AppDarkColors.border),
                    width: 0.5)),
            child: Column(children: [
              Row(children: [
                Icon(Icons.email_rounded,
                    size: 18,
                    color: AppColors.resolve(
                        AppColors.accent, AppDarkColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        AppLocalizations.of(context)!
                            .user_orders_notified_email,
                        style:
                            AppTypography.bodyMedium().copyWith(fontSize: 13)))
              ]),
              const Divider(height: 24),
              Row(children: [
                Icon(Icons.receipt_long_rounded,
                    size: 18,
                    color: AppColors.resolve(
                        AppColors.accent, AppDarkColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        AppLocalizations.of(context)!
                            .user_orders_receive_orders,
                        style:
                            AppTypography.bodyMedium().copyWith(fontSize: 13)))
              ]),
            ])),
      ]),
    );
  }

  Future<void> _showRate(int cmdId, int restauId) async {
    final lignes = await LigneCommande.fetchLignesCommandeByCommandeID(cmdId);
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 1,
        targetID: restauId,
        orderId: cmdId,
        title: AppLocalizations.of(context)!.commande_details_rate_restaurant,
        lignes: lignes,
        dishNames: dishNames,
      ),
    );
    if (mounted && result != null && result != "success") {
      _snack(result, AppColors.error);
    }
    if (mounted && result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.user_orders_thanks_review),
          backgroundColor:
              AppColors.resolve(AppColors.success, AppDarkColors.success),
        ),
      );
    }
  }

  Future<void> _showRateLivreur(int livreurID, int orderId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 3,
        targetID: livreurID,
        orderId: orderId,
        title: AppLocalizations.of(context)!.user_orders_rate_driver,
      ),
    );
    if (mounted && result != null && result != "success") {
      _snack(result, AppColors.error);
    }
    if (mounted && result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.user_orders_thanks_review_driver),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

// ── Valeur `paymentProvider` de la commande (accès tolérant) ─────────────
String? _paymentProviderOf(Commande c) {
  try {
    final v = (c as dynamic).paymentProvider;
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  } catch (_) {
    return null;
  }
}

// ── Bouton action primaire (plein) ────────────────────────
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton action icône seule ─────────────────────────────
class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Bouton « noter » (étoile) ─────────────────────────────
class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 17, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Petite pastille d'information (mode de remise, paiement) ─
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Badge statut ──────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Badge commandes en attente dans l'AppBar ──────────────
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count ${AppLocalizations.of(context)!.pending.toLowerCase()}',
          style: AppTypography.labelMedium(color: AppColors.ink)
              .copyWith(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ── Liste des plats repliable ─────────────────────────────
class _OrderDishes extends StatefulWidget {
  const _OrderDishes({
    super.key,
    required this.orderId,
    required this.loader,
    required this.dishNames,
    required this.country,
    required this.subtotalLabel,
  });
  final int orderId;
  final Future<List<LigneCommande>> Function(int id) loader;
  final Map<int, String> dishNames;
  final String country;
  final String subtotalLabel;

  @override
  State<_OrderDishes> createState() => _OrderDishesState();
}

class _OrderDishesState extends State<_OrderDishes> {
  late final Future<List<LigneCommande>> _future;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    // chargé une seule fois (avant : rechargé à chaque rebuild de la liste)
    _future = widget.loader(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final warm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    return FutureBuilder<List<LigneCommande>>(
      future: _future,
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final lignes = snap.data!;
        final count = lignes.fold<int>(0, (s, l) => s + l.quantite.toInt());
        final subtotal =
            lignes.fold<double>(0, (s, l) => s + l.prixUnitaire * l.quantite);

        return Container(
          decoration: BoxDecoration(
            color: warm,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded,
                          size: 16, color: brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$count article${count > 1 ? 's' : ''} · ${CurrencyUtil.formatPrice(subtotal, widget.country)}',
                          style: AppTypography.labelMedium(color: ink)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: AppMotion.fast,
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: AppMotion.fast,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        child: Column(
                          children: [
                            ...lignes.map((l) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.resolve(
                                              AppColors.brandSurface,
                                              AppDarkColors.brandSurface),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text('${l.quantite}',
                                              style: AppTypography.labelMedium(
                                                      color: brand)
                                                  .copyWith(fontSize: 11)),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          (l.nomPlat?.trim().isNotEmpty == true
                                                  ? l.nomPlat!.trim()
                                                  : null) ??
                                              widget.dishNames[l.platID] ??
                                              'Plat #${l.platID}',
                                          style: AppTypography.bodyMedium(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        CurrencyUtil.formatPrice(
                                            l.prixUnitaire, widget.country),
                                        style: AppTypography.labelMedium(
                                            color: brand),
                                      ),
                                    ],
                                  ),
                                )),
                            const Divider(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(widget.subtotalLabel,
                                    style: AppTypography.bodyMedium(
                                            color: muted)
                                        .copyWith(fontSize: 12)),
                                Text(
                                    CurrencyUtil.formatPrice(
                                        subtotal, widget.country),
                                    style: AppTypography.labelMedium(
                                            color: ink)
                                        .copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Squelette de carte (premier chargement) ───────────────
class _OrderSkeleton extends StatefulWidget {
  const _OrderSkeleton();

  @override
  State<_OrderSkeleton> createState() => _OrderSkeletonState();
}

class _OrderSkeletonState extends State<_OrderSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bone = AppColors.resolve(AppColors.border, AppDarkColors.border)
        .withValues(alpha: 0.55);
    Widget box(double w, double h, [double r = 8]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: bone, borderRadius: BorderRadius.circular(r)),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              box(42, 42, 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(150, 14),
                    const SizedBox(height: 6),
                    box(100, 10)
                  ],
                ),
              ),
              box(70, 22, 999),
            ]),
            const SizedBox(height: 14),
            Row(children: [box(80, 22, 999), const SizedBox(width: 6), box(110, 22, 999)]),
            const SizedBox(height: 14),
            box(double.infinity, 44, 12),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.isRestaurant});
  final bool isRestaurant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 40),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isRestaurant ? l10n.noOrderReceived : l10n.noOrderFound,
            // (avant : couleur « surface » = texte invisible)
            style: AppTypography.titleMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isRestaurant
                ? l10n.user_orders_new_orders_hint
                : l10n.user_orders_past_orders_hint,
            style: AppTypography.bodyMedium(
                color:
                    AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Filtres de la liste (par étape de commande) ───────────
enum _OrderFilter { all, active, newOrders, preparing, ready, done, cancelled }

extension on _OrderFilter {
  bool matches(OrderStage stage) {
    switch (this) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.active:
        return orderStageIsActive(stage);
      case _OrderFilter.newOrders:
        return stage == OrderStage.received ||
            stage == OrderStage.awaitingPayment;
      case _OrderFilter.preparing:
        return stage == OrderStage.preparing;
      case _OrderFilter.ready:
        return stage == OrderStage.ready || stage == OrderStage.onTheWay;
      case _OrderFilter.done:
        return stage == OrderStage.delivered;
      case _OrderFilter.cancelled:
        return stage == OrderStage.cancelled;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _OrderFilter.all:
        return l10n.all;
      case _OrderFilter.active:
        return l10n.orders_filter_active;
      case _OrderFilter.newOrders:
        return l10n.orders_filter_new;
      case _OrderFilter.preparing:
        return l10n.order_step_preparing;
      case _OrderFilter.ready:
        return l10n.orders_filter_ready;
      case _OrderFilter.done:
        return l10n.orders_filter_done;
      case _OrderFilter.cancelled:
        return l10n.orders_filter_cancelled;
    }
  }
}

// ── Pastille d'information (attente livreur, paiement…) ───
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTracker extends StatelessWidget {
  final String orderStatus;
  final String? status;
  final double? lat, lng;
  const _DeliveryTracker({
    required this.orderStatus,
    this.status,
    this.lat,
    this.lng,
  });

  static List<String> _labels(BuildContext context) => [
        AppLocalizations.of(context)!.delivery_tracking_steps_preparation,
        'Prête',
        AppLocalizations.of(context)!.delivery_tracking_steps_picked,
        AppLocalizations.of(context)!.delivery_tracking_steps_transit,
        AppLocalizations.of(context)!.delivery_tracking_steps_delivered,
      ];
  static const _icons = [
    Icons.restaurant_rounded,
    Icons.inventory_2_rounded,
    Icons.shopping_bag_rounded,
    Icons.directions_bike_rounded,
    Icons.check_circle_rounded,
  ];

  int _stepIndex() {
    final order = CommandeStatus.normalize(orderStatus);
    final delivery = status == null ? null : DeliveryStatus.normalize(status);
    if (delivery == DeliveryStatus.delivered || order == CommandeStatus.delivered) {
      return 4;
    }
    if (delivery == DeliveryStatus.inTransit) return 3;
    if (delivery == DeliveryStatus.pickedUp) return 2;
    if (delivery == DeliveryStatus.assigned ||
        delivery == DeliveryStatus.atPickup ||
        delivery == DeliveryStatus.searching ||
        order == CommandeStatus.ready) return 1;
    if (order == CommandeStatus.preparing || order == CommandeStatus.confirmed) {
      return 0;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _stepIndex();
    final labels = _labels(context);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final off = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final offIcon =
        AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
    final hasMap = DeliveryStatus.normalize(status) == DeliveryStatus.inTransit &&
        lat != null &&
        lng != null;

    Widget segment(bool done) => AnimatedContainer(
          duration: AppMotion.fast,
          height: 3,
          decoration: BoxDecoration(
            color: done ? brand : off,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return Column(
      children: [
        // Étapes : le trait relie bien les pastilles entre elles
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(5, (i) {
            final done = i <= idx;
            final current = i == idx;
            return Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        Expanded(
                            child: i == 0
                                ? const SizedBox.shrink()
                                : segment(i <= idx)),
                        AnimatedContainer(
                          duration: AppMotion.fast,
                          width: current ? 34 : 28,
                          height: current ? 34 : 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? brand : off,
                            boxShadow: current
                                ? [
                                    BoxShadow(
                                      color: brand.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(_icons[i],
                              size: current ? 17 : 14,
                              color: done ? Colors.white : offIcon),
                        ),
                        Expanded(
                            child: i == 4
                                ? const SizedBox.shrink()
                                : segment(i + 1 <= idx)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: done ? brand : offIcon,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        if (hasMap)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DeliveryMapPage(livreurLat: lat!, livreurLng: lng!),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.md),
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: brand.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat!, lng!),
                    initialZoom: 14,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.diosdelices.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(lat!, lng!),
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.delivery_dining_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('En direct',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_full_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                            AppLocalizations.of(context)!
                                .user_orders_tap_to_enlarge,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class DeliveryMapPage extends StatefulWidget {
  final double livreurLat, livreurLng;
  final double? clientLat, clientLng;
  const DeliveryMapPage(
      {super.key,
      required this.livreurLat,
      required this.livreurLng,
      this.clientLat,
      this.clientLng});
  @override
  State<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends State<DeliveryMapPage> {
  List<LatLng> _route = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientLat != null) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${widget.livreurLng},${widget.livreurLat};${widget.clientLng},${widget.clientLat}?overview=full&geometries=geojson';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final coords = (jsonDecode(resp.body)['routes']?[0]?['geometry']
                ?['coordinates'] as List?) ??
            [];
        if (mounted)
          setState(() {
            _route = coords
                .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                .toList();
            _loading = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _route.isNotEmpty ? LatLngBounds.fromPoints(_route) : null;
    final center =
        bounds?.center ?? LatLng(widget.livreurLat, widget.livreurLng);
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.commande_details_tracking)),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              initialCameraFit: bounds != null
                  ? CameraFit.bounds(
                      bounds: bounds, padding: const EdgeInsets.all(40))
                  : null),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.diosdelices.app'),
            if (_route.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                    points: _route,
                    color:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                    strokeWidth: 4),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: LatLng(widget.livreurLat, widget.livreurLng),
                width: 50,
                height: 50,
                child: Column(children: [
                  Icon(Icons.delivery_dining,
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      size: 32),
                  Text(AppLocalizations.of(context)!.livreurs,
                      style:
                          TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                ]),
              ),
              if (widget.clientLat != null)
                Marker(
                  point: LatLng(widget.clientLat!, widget.clientLng!),
                  width: 50,
                  height: 50,
                  child: Column(children: [
                    Icon(Icons.home_rounded,
                        color: AppColors.resolve(
                            AppColors.accent, AppDarkColors.accent),
                        size: 32),
                    Text(AppLocalizations.of(context)!.commande_details_client,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.resolve(
                              AppColors.surface, AppDarkColors.surface),
                        )),
                  ]),
                ),
            ]),
          ],
        ),
        if (_loading)
          const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}