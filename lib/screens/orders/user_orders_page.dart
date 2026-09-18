import 'dart:convert';
import 'dart:math';

import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_screen.dart';
import 'commande_details_page.dart';
import '../../widgets/rating_dialog.dart';

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

  List<Commande> commandes = [];
  bool isLoading = true;
  bool _restoValid = true;
  bool _canAssignLivreur = false;
  Map<int, String> dishNames = {};
  Map<int, String> restoNames = {};
  String? statusFilter;
  String _country = 'France';
  final LiveQuery liveQuery = LiveQuery();
  Subscription? sub;

  @override
  void initState() {
    super.initState();
    loadOrders();
    _listen();
  }

  Future<void> _listen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
    sub = await liveQuery.client.subscribe(query);
    sub!.on(LiveQueryEvent.create, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.update, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.delete, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
  }

  @override
  void dispose() {
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();
    _country = session.country;

    // Vérifier la validité du restaurant pour les restaurateurs
    if (widget.showRestaurantOrders && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final resto = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoValid = resto?.valid == 1;
    }

    _canAssignLivreur = session.role.isAdmin || session.role == AppRole.livreur;

    await Commande.refreshLocalCommandes(); // Refresh orders from Parse first!
    await LigneCommande
        .getAllLignesCommande(); // Refresh order items from Parse too!
    final allC = await Commande.fetchCommandesFromDB();
    final allD = await Dish.fetchDishesFromDB();
    final allR = await Restaurant.fetchRestaurantsFromDB();

    for (var i = 0; i < allC.length; i++) {}

    final dn = <int, String>{};
    for (final d in allD) {
      dn[d.dishID] = d.name ?? 'Plat ${d.dishID}';
    }
    final rn = <int, String>{};
    for (final r in allR) {
      rn[r.restaurantID] = r.name;
    }

    var filtered = <Commande>[];
    for (var c in allC) {
      if (session.role.isAdmin) {
        filtered.add(c);
      } else if (widget.showRestaurantOrders) {
        if (c.restaurateurID == session.userId) {
          filtered.add(c);
        }
      } else {
        if (c.userID == session.userId) {
          filtered.add(c);
        }
      }
    }
    if (statusFilter != null)
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    for (var i = 0; i < filtered.length; i++) {}
    filtered.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
      dishNames = dn;
      restoNames = rn;
      commandes = filtered;
      isLoading = false;
    });
  }

  Future<List<LigneCommande>> getLignes(int id) =>
      LigneCommande.fetchLignesCommandeByCommandeID(id);

  Future<void> updateStatus(int id, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmDialog(
        isConfirm: newStatus == CommandeStatus.confirmed,
        commandeId: id,
      ),
    );

    if (confirmed == true) {
      // Afficher un indicateur de chargement
      setState(() => isLoading = true);

      try {
        // Tentative de mise à jour
        await CommandeApi.updateOrderStatus(id.toString(), newStatus);

        // Rafraîchir les données
        await Commande.refreshLocalCommandes();
        await loadOrders();

        // Message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == CommandeStatus.confirmed
                  ? AppLocalizations.of(context)!.orderConfirmed
                  : AppLocalizations.of(context)!.orderCancelled),
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.resolve(AppColors.success, AppDarkColors.success)
                  : AppColors.resolve(AppColors.error, AppDarkColors.error),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Message d'erreur détaillé
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor:
                  AppColors.resolve(AppColors.error, AppDarkColors.error),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
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
              count: commandes
                  .where((c) => CommandeStatus.isPending(c.status))
                  .length,
            ),
        ],
      ),
      body: widget.showRestaurantOrders && !_restoValid
          ? _buildPendingFullPage()
          : Column(children: [
              _buildFilters(isSmallScreen),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : commandes.isEmpty
                        ? _EmptyOrders(
                            isRestaurant: widget.showRestaurantOrders)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            itemCount: commandes.length,
                            itemBuilder: (_, i) =>
                                _buildCard(commandes[i], isSmallScreen),
                          ),
              ),
            ]),
    );
  }

  Widget _buildFilters(bool isSmall) {
    final statuses = [
      AppLocalizations.of(context)!.all,
      CommandeStatus.pending,
      CommandeStatus.confirmed,
      CommandeStatus.cancelled
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) {
          final active = statusFilter ==
              (s == AppLocalizations.of(context)!.all ? null : s);
          final label = s == AppLocalizations.of(context)!.all
              ? AppLocalizations.of(context)!.all
              : s == CommandeStatus.pending
                  ? AppLocalizations.of(context)!.pending
                  : s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter =
                    s == AppLocalizations.of(context)!.all ? null : s);
                loadOrders();
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                      : AppColors.resolve(AppColors.card, AppDarkColors.card),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: active
                          ? AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand)
                          : AppColors.resolve(
                              AppColors.border, AppDarkColors.border),
                      width: 0.5),
                ),
                child: Text(label,
                    style: AppTypography.labelMedium(
                        color: active
                            ? AppColors.resolve(
                                AppColors.card, AppDarkColors.card)
                            : AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(Commande c, bool isSmall) {
    final status = CommandeStatus.normalize(c.status);
    final statusColor = CommandeStatus.color(status);
    final isRestaurantView = widget.showRestaurantOrders;

    final bool isCancelled = status == CommandeStatus.cancelled;
    final bool isConfirmed = status == CommandeStatus.confirmed;
    final bool isDelivered = status == CommandeStatus.delivered;
    final bool canCancel = !isCancelled && !isConfirmed && !isDelivered;
    final bool canConfirm = !isConfirmed && !isCancelled;
    final dateStr = c.dateCommande.toLocal().toString().split(' ')[0];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.30),
          width: 0.8,
        ),
        boxShadow: [AppShadows.subtle],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barre colorée gauche (indicateur statut) ─
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(AppRadius.xl),
                  ),
                ),
              ),
              // ── Contenu principal ────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── En-tête : ID + date + badge statut ─
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                      child: Row(
                        children: [
                          // Icône commande
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.receipt_rounded,
                                color: statusColor, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // ID + nom/date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isRestaurantView
                                      ? '${AppLocalizations.of(context)!.orders} #${c.commandeID}'
                                      : restoNames[c.restauID] ??
                                          '${AppLocalizations.of(context)!.orders} #${c.commandeID}',
                                  style: AppTypography.labelLarge(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr · ${c.heure}',
                                  style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.inkSubtle,
                                              AppDarkColors.inkSubtle))
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Badge statut
                          _StatusBadge(status: status, color: statusColor),
                        ],
                      ),
                    ),
                    // ── Actions PRIMAIRES restaurateur ───────
                    if (isRestaurantView && !isCancelled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                        child: Row(
                          children: [
                            if (!isConfirmed)
                              Expanded(
                                child: _PrimaryActionButton(
                                  label: AppLocalizations.of(context)!
                                      .user_orders_confirm,
                                  icon: Icons.check_rounded,
                                  color: AppColors.success,
                                  onTap: () => updateStatus(
                                      c.commandeID, CommandeStatus.confirmed),
                                ),
                              ),
                            if (!isConfirmed)
                              const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _PrimaryActionButton(
                                label: AppLocalizations.of(context)!.livreurs,
                                icon: Icons.delivery_dining_rounded,
                                color: AppColors.brand,
                                onTap: () => _showAssignLivreur(c.commandeID),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _IconActionButton(
                              icon: Icons.close_rounded,
                              color: AppColors.error,
                              onTap: () => updateStatus(
                                  c.commandeID, CommandeStatus.cancelled),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _IconActionButton(
                              icon: Icons.chat_rounded,
                              color: AppColors.inkMuted,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                          withUserID: c.userID,
                                          withUsername:
                                              'Client #${c.commandeID}'))),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ── Voir le détail + actions ──────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommandeDetailsPage(commande: c),
                              ),
                            ),
                            child: Text(
                                AppLocalizations.of(context)!
                                    .user_orders_see_detail,
                                style: AppTypography.labelMedium(
                                        color: AppColors.brand)
                                    .copyWith(fontSize: 12)),
                          ),
                          if (!isRestaurantView && isConfirmed) ...[
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showRate(c.commandeID, c.restauID),
                              icon: Icon(Icons.star_rounded,
                                  size: 15,
                                  color: AppColors.resolve(
                                      AppColors.accent, AppDarkColors.accent)),
                              label: Text(AppLocalizations.of(context)!
                                  .user_orders_rate),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.resolve(
                                    AppColors.accentLight,
                                    AppDarkColors.accentLight),
                                foregroundColor: AppColors.resolve(
                                    AppColors.accent, AppDarkColors.accent),
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                            if (c.livreurID != null)
                              ElevatedButton.icon(
                                onPressed: () => _showRateLivreur(c.livreurID!),
                                icon: const Icon(Icons.star_rounded,
                                    size: 15, color: AppColors.success),
                                label: Text(AppLocalizations.of(context)!
                                    .user_orders_rate_driver),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.resolve(
                                      AppColors.success.withValues(alpha: 0.12),
                                      AppDarkColors.success
                                          .withValues(alpha: 0.12)),
                                  foregroundColor: AppColors.resolve(
                                      AppColors.success, AppDarkColors.success),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    // ── Liste des plats ─────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: FutureBuilder<List<LigneCommande>>(
                        future: getLignes(c.commandeID),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          final lignes = snap.data!;
                          final subtotal = lignes.fold<double>(
                              0, (s, l) => s + l.prixUnitaire * l.quantite);
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.surfaceWarm,
                                  AppDarkColors.surfaceWarm),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...lignes.map((l) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
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
                                                  style:
                                                      AppTypography.labelMedium(
                                                              color: AppColors
                                                                  .brand)
                                                          .copyWith(
                                                              fontSize: 11)),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              (l.nomPlat?.trim().isNotEmpty == true
                                                      ? l.nomPlat!.trim()
                                                      : null) ??
                                                  dishNames[l.platID] ??
                                                  'Plat #${l.platID}',
                                              style: AppTypography.bodyMedium(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            CurrencyUtil.formatPrice(
                                                l.prixUnitaire, _country),
                                            style: AppTypography.labelMedium(
                                                color: AppColors.brand),
                                          ),
                                        ],
                                      ),
                                    )),
                                const Divider(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(AppLocalizations.of(context)!.subtotal,
                                        style: AppTypography.bodyMedium(
                                                color: AppColors.resolve(
                                                    AppColors.inkMuted,
                                                    AppDarkColors.inkMuted))
                                            .copyWith(fontSize: 12)),
                                    Text(
                                        CurrencyUtil.formatPrice(
                                            subtotal, _country),
                                        style: AppTypography.labelMedium(
                                                color: AppColors.resolve(
                                                    AppColors.ink,
                                                    AppDarkColors.ink))
                                            .copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // ── Suivi livraison client ───────────────
                    if (!isRestaurantView &&
                        c.deliveryStatus != null &&
                        c.deliveryStatus!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        child: _DeliveryTracker(
                          status: c.deliveryStatus!,
                          lat: c.livreurLat,
                          lng: c.livreurLng,
                        ),
                      ),
                  ],
                ),
              ),
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

  Future<void> _showAssignLivreur(int id) async {
    setState(() => isLoading = true);
    try {
      // 1. Fetch active command from Parse
      final commandQuery = QueryBuilder<ParseObject>(ParseObject('Commande'))
        ..whereEqualTo('commandeID', id);
      final commandResp = await commandQuery.query();
      if (!commandResp.success ||
          commandResp.results == null ||
          commandResp.results!.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final cmdObj = commandResp.results!.first as ParseObject;
      final restauID = cmdObj.get<int>('restaurateurID') ?? 0;
      final addressID = cmdObj.get<int>('addressID') ?? 0;

      // 2. Fetch addresses and calculate distance
      final addresses = await Address.fetchAddressesFromDB();
      final customerAddress = addresses
          .firstWhere((a) => a.addressID == addressID, orElse: () => Address());
      final restaurantAddress =
          Address.getAddressByObject(addresses, "User", restauID);

      final customerLat = double.tryParse(customerAddress.lat ?? '');
      final customerLng = double.tryParse(customerAddress.long ?? '');
      final restoLat = double.tryParse(restaurantAddress?.lat ?? '');
      final restoLng = double.tryParse(restaurantAddress?.long ?? '');

      double deliveryDistance = 0.0;
      if (customerLat != null &&
          customerLng != null &&
          restoLat != null &&
          restoLng != null) {
        deliveryDistance =
            _calculateDistanceKm(restoLat, restoLng, customerLat, customerLng);
      }

      // 3. Query online drivers from Parse
      final driverQuery = QueryBuilder<ParseObject>(ParseObject('Users'))
        ..whereEqualTo('roleID', 5)
        ..whereEqualTo('isOnline', true);
      final driverResp = await driverQuery.query();

      final List<Users> filteredLivreurs = [];
      if (driverResp.success && driverResp.results != null) {
        for (final obj in driverResp.results!) {
          final parseUser = obj as ParseObject;
          final maxDist =
              parseUser.get<num>('maxDeliveryDistance')?.toDouble() ?? 10.0;

          if (deliveryDistance <= maxDist) {
            final userMap = <String, dynamic>{
              'userID': parseUser.get<int>('userID'),
              'roleID': parseUser.get<int>('roleID'),
              'firstname': parseUser.get<String>('firstname') ?? '',
              'lastname': parseUser.get<String>('lastname') ?? '',
              'username': parseUser.get<String>('username') ?? '',
              'email': parseUser.get<String>('email') ?? '',
              'telephone': parseUser.get<String>('telephone') ?? '',
              'country': parseUser.get<String>('country') ?? '',
              'status': parseUser.get<String>('status') ?? '',
              'identity': parseUser.get<String>('identity') ?? '',
              'addressID': parseUser.get<int>('addressID') ?? 0,
            };
            filteredLivreurs.add(Users.fromMap(userMap));
          }
        }
      }

      if (mounted) setState(() => isLoading = false);

      if (filteredLivreurs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.user_orders_no_driver)));
        }
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => _AssignLivreurDialog(
          livreurs: filteredLivreurs,
          commandeId: id,
          onAssigned: () async {
            await Commande.refreshLocalCommandes();
            await loadOrders();
          },
        ),
      );
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $e')));
      }
    }
  }

  double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    final dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _showRate(int cmdId, int restauId) async {
    final lignes = await LigneCommande.fetchLignesCommandeByCommandeID(cmdId);
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 1,
        targetID: restauId,
        title: AppLocalizations.of(context)!.commande_details_rate_restaurant,
        lignes: lignes,
        dishNames: dishNames,
      ),
    );
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

  Future<void> _showRateLivreur(int livreurID) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 3,
        targetID: livreurID,
        title: AppLocalizations.of(context)!.user_orders_rate_driver,
      ),
    );
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

// ── Bouton action primaire (pleine largeur) ───────────────
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.labelMedium(color: color)
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
        ),
        child: Icon(icon, color: color, size: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
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
    final l10n = AppLocalizations.of(context)!;
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

// ── Empty state ───────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.isRestaurant});
  final bool isRestaurant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.brandSurface, AppDarkColors.brandSurface),
                  shape: BoxShape.circle),
              child: Icon(Icons.receipt_long_outlined,
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 34),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isRestaurant
                  ? AppLocalizations.of(context)!.noOrderReceived
                  : AppLocalizations.of(context)!.noOrderFound,
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(
                      AppColors.surface, AppDarkColors.surface)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isRestaurant
                  ? AppLocalizations.of(context)!.user_orders_new_orders_hint
                  : AppLocalizations.of(context)!.user_orders_past_orders_hint,
              style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Dialogs
// ═══════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.isConfirm, required this.commandeId});
  final bool isConfirm;
  final int commandeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = isConfirm
        ? AppColors.resolve(AppColors.success, AppDarkColors.success)
        : AppColors.resolve(AppColors.error, AppDarkColors.error);
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Row(children: [
        Icon(
            isConfirm
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: color,
            size: 22),
        const SizedBox(width: AppSpacing.sm),
        Text(
            isConfirm
                ? AppLocalizations.of(context)!.confirm
                : AppLocalizations.of(context)!.cancel,
            style: AppTypography.titleMedium(color: color)),
      ]),
      content: Text(
        isConfirm
            ? AppLocalizations.of(context)!
                .user_orders_confirm_prompt(commandeId)
            : AppLocalizations.of(context)!
                .user_orders_cancel_prompt(commandeId),
        style: AppTypography.bodyLarge(color: color),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.no)),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: Text(isConfirm
              ? AppLocalizations.of(context)!.user_orders_yes_confirm
              : AppLocalizations.of(context)!.user_orders_yes_cancel),
        ),
      ],
    );
  }
}

class _AssignLivreurDialog extends StatelessWidget {
  const _AssignLivreurDialog({
    required this.livreurs,
    required this.commandeId,
    required this.onAssigned,
  });

  final List<Users> livreurs;
  final int commandeId;
  final Future<void> Function() onAssigned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(Icons.delivery_dining_rounded,
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              size: 16),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(AppLocalizations.of(context)!.user_orders_assign_driver,
            style: AppTypography.titleMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: livreurs.length,
          itemBuilder: (_, i) {
            final l = livreurs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Material(
                color: AppColors.resolve(
                    AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.resolve(
                        AppColors.brandSurface, AppDarkColors.brandSurface),
                    child: Text(
                      l.firstname.isNotEmpty
                          ? l.firstname[0].toUpperCase()
                          : '?',
                      style: AppTypography.labelLarge(
                          color: AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand)),
                    ),
                  ),
                  title: Text(
                    '${l.firstname} ${l.lastname}',
                    style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink)),
                  ),
                  subtitle: Text(
                    l.telephone.toString(),
                    style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.inkSubtle, AppDarkColors.inkSubtle))
                        .copyWith(fontSize: 11),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final fn = ParseCloudFunction('assignLivreur');
                      final resp = await fn.execute(parameters: {
                        'commandeID': commandeId,
                        'livreurID': l.userID,
                      });
                      if (resp.success) {
                        await onAssigned();
                      }
                    } catch (_) {}
                  },
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ],
    );
  }
}

class _DeliveryTracker extends StatelessWidget {
  final String status;
  final double? lat, lng;
  const _DeliveryTracker({required this.status, this.lat, this.lng});

  static const _steps = ['assigned', 'picked_up', 'in_transit', 'delivered'];
  static List<String> _labels(BuildContext context) => [
        AppLocalizations.of(context)!.delivery_tracking_steps_preparation,
        AppLocalizations.of(context)!.delivery_tracking_steps_picked,
        AppLocalizations.of(context)!.delivery_tracking_steps_transit,
        AppLocalizations.of(context)!.delivery_tracking_steps_delivered,
      ];
  static const _icons = [
    Icons.restaurant_rounded,
    Icons.shopping_bag_rounded,
    Icons.directions_bike_rounded,
    Icons.check_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final idx = _steps.indexOf(status);
    final hasMap = status == 'in_transit' && lat != null && lng != null;

    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
            final done = i <= idx;
            return Expanded(
              child: Column(
                children: [
                  if (i > 0)
                    Row(children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i <= idx
                              ? AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)
                              : AppColors.resolve(
                                  AppColors.border, AppDarkColors.border),
                        ),
                      ),
                    ]),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand)
                          : AppColors.resolve(
                              AppColors.border, AppDarkColors.border),
                    ),
                    child: Icon(_icons[i],
                        size: 14,
                        color: done
                            ? AppColors.resolve(
                                AppColors.surface, AppDarkColors.surface)
                            : AppColors.resolve(
                                AppColors.border, AppDarkColors.inkSubtle)),
                  ),
                  const SizedBox(height: 4),
                  Text(_labels(context)[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: done
                              ? AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)
                              : AppColors.resolve(
                                  AppColors.border, AppDarkColors.inkSubtle))),
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
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                            .withValues(alpha: 0.3)),
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
                        width: 40,
                        height: 40,
                        child: Icon(Icons.delivery_dining,
                            color: AppColors.resolve(
                                AppColors.brand, AppDarkColors.brand),
                            size: 28),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                        AppLocalizations.of(context)!
                            .user_orders_tap_to_enlarge,
                        style: TextStyle(
                            color: AppColors.resolve(
                                AppColors.surface, AppDarkColors.surface),
                            fontSize: 10)),
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
