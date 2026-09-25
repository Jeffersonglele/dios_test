import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/commande_status.dart';
import '../../models/commande.dart';
import '../../models/dish.dart';
import '../../models/ligne_commande.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../services/livreur_api.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/toast.dart';
import '../orders/commande_details_page.dart';
import '../chat/chat_screen.dart';
import '../../l10n/app_localizations.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  List<Commande> deliveries = [];
  Map<int, String> restoNames = {};
  Map<int, String> dishNames = {};
  bool isLoading = true;
  String _country = 'RDC';
  bool isOnline = false;
  int driverID = 0;
  int? activeCommandeID;
  Timer? _locationTimer;
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  String? statusFilter;

  final LiveQuery liveQuery = LiveQuery();
  Subscription? sub;

  @override
  void initState() {
    super.initState();
    _load();
    _listen();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  // ── LiveQuery pour rafraîchir en temps réel ──────────────
  Future<void> _listen() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
      sub = await liveQuery.client.subscribe(query);
      sub!.on(LiveQueryEvent.create, (_) async {
        await Commande.refreshLocalCommandes();
        await LigneCommande.getAllLignesCommande();
        await _load();
      });
      sub!.on(LiveQueryEvent.update, (_) async {
        await Commande.refreshLocalCommandes();
        await LigneCommande.getAllLignesCommande();
        await _load();
      });
    } catch (_) {}
  }

  // ── Chargement principal ─────────────────────────────────
  Future<void> _load() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final session = await SessionService.readSession();
      _country = session.country;
      driverID = session.userId;

      // Charger les restaurants
      final restos = await Restaurant.fetchRestaurantsFromDB();
      final rNames = <int, String>{};
      for (final r in restos) {
        rNames[r.restaurantID] = r.name;
      }

      // Charger les noms des plats
      final allDishes = await Dish.fetchDishesFromDB();
      final dNames = <int, String>{};
      for (final d in allDishes) {
        dNames[d.dishID] = d.name ?? 'Plat ${d.dishID}';
      }

      // Charger les commandes du livreur
      await _loadDeliveries();
      await _loadEarnings();
      await _loadOnlineStatus();

      if (mounted) {
        setState(() {
          restoNames = rNames;
          dishNames = dNames;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (mounted) {
        Toast(context, '${AppLocalizations.of(context)!.error}: $e', false);
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadDeliveries() async {
    try {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();

      final cloudDeliveries = await LivreurApi.getLivreurDeliveries(driverID);
      List<Commande> list = [];
      if (cloudDeliveries.isNotEmpty) {
        list = cloudDeliveries.map((m) => Commande.fromMap(m)).toList();
      } else {
        final allC = await Commande.fetchCommandesFromDB();
        list = allC.where((c) => c.livreurID == driverID).toList();
      }

      if (statusFilter != null) {
        list = list.where((c) {
          final s = DeliveryStatus.normalize(c.deliveryStatus);
          return s == statusFilter;
        }).toList();
      }

      list.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
      if (mounted) setState(() => deliveries = list);
    } catch (_) {
      final allC = await Commande.fetchCommandesFromDB();
      var myDeliveries = allC.where((c) => c.livreurID == driverID).toList();
      if (statusFilter != null) {
        myDeliveries = myDeliveries.where((c) {
          final s = DeliveryStatus.normalize(c.deliveryStatus);
          return s == statusFilter;
        }).toList();
      }
      myDeliveries.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
      if (mounted) setState(() => deliveries = myDeliveries);
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final result = await LivreurApi.getLivreurEarnings(driverID);
      if (mounted) {
        _totalDeliveries = (result['totalLivraisons'] as num?)?.toInt() ?? 0;
        _totalEarnings = (result['totalGains'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _loadOnlineStatus() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final settings = await LivreurApi.getSettings(driverID);
      if (settings != null) {
        final online = settings['isOnline'] == true;
        await prefs.setBool('driver_online_$driverID', online);
        if (mounted) {
          setState(() => isOnline = online);
        }
        if (online) {
          _startSharingLocation(_currentActiveDeliveryId());
        } else {
          _stopSharingLocation();
        }
      } else if (mounted) {
        // Le cache ne doit jamais reconnecter automatiquement un livreur.
        await prefs.setBool('driver_online_$driverID', false);
        setState(() => isOnline = false);
        _stopSharingLocation();
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement statut: $e');
      if (mounted) setState(() => isOnline = false);
      _stopSharingLocation();
    }
  }

  // ── Actions ──────────────────────────────────────────────
  Future<void> _toggleOnline() async {
    final nextOnline = !isOnline;
    setState(() => isOnline = nextOnline);
    final prefs = await SharedPreferences.getInstance();

    try {
      final ok = await LivreurApi.toggleOnlineStatus(driverID, nextOnline);
      if (!ok && mounted) {
        setState(() => isOnline = !nextOnline);
        Toast(context, AppLocalizations.of(context)!.error, false);
      } else if (mounted) {
        await prefs.setBool('driver_online_$driverID', nextOnline);
        if (nextOnline) {
          _startSharingLocation(_currentActiveDeliveryId());
        } else {
          _stopSharingLocation();
        }
        Toast(
            context,
            nextOnline
                ? AppLocalizations.of(context)!.delivery_toggle_online
                : AppLocalizations.of(context)!.delivery_toggle_offline,
            true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => isOnline = !nextOnline);
        await prefs.setBool('driver_online_$driverID', !nextOnline);
      }
    }
  }

  void _startSharingLocation([int? commandeID]) {
    _locationTimer?.cancel();
    if (commandeID != null) activeCommandeID = commandeID;
    _sendLocation();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  void _stopSharingLocation() {
    _locationTimer?.cancel();
    activeCommandeID = null;
  }

  Future<void> _sendLocation() async {
    if (!isOnline) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await LivreurApi.updatePosition(driverID, pos.latitude, pos.longitude,
          commandeID: activeCommandeID);
    } catch (_) {}
  }

  int? _currentActiveDeliveryId() {
    for (final delivery in deliveries) {
      final status = DeliveryStatus.normalize(delivery.deliveryStatus);
      if (status == DeliveryStatus.assigned ||
          status == DeliveryStatus.atPickup ||
          status == DeliveryStatus.pickedUp ||
          status == DeliveryStatus.inTransit) {
        return delivery.commandeID;
      }
    }
    return null;
  }

  Future<void> _acceptAndUpdateStatus(Commande commande, String newStatus,
      {String? confirmTitle,
      String? confirmBody,
      IconData? confirmIcon}) async {
    final l10n = AppLocalizations.of(context)!;
    if (!isOnline) {
      Toast(context, l10n.delivery_must_be_online, false);
      return;
    }
    if (isLoading) return;
    if (confirmTitle != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(confirmIcon ?? Icons.check_circle_rounded,
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(confirmTitle)),
          ]),
          content: confirmBody != null
              ? Text(confirmBody,
                  style: AppTypography.bodyLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink)))
              : null,
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel,
                    style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.validate),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => isLoading = true);
    try {
      final normalized = DeliveryStatus.normalize(newStatus);
      final ok = await LivreurApi.updateDeliveryStatus(
          commande.commandeID, normalized);
      if (ok) {
        if (normalized == DeliveryStatus.assigned ||
            normalized == DeliveryStatus.atPickup ||
            normalized == DeliveryStatus.pickedUp ||
            normalized == DeliveryStatus.inTransit) {
          _startSharingLocation(commande.commandeID);
        }
        if (normalized == DeliveryStatus.delivered) _stopSharingLocation();
        await _load();
        if (mounted) {
          final label = _deliveryStatusLabel(normalized);
          Toast(context, '✅ $label', true);
        }
      } else {
        if (mounted)
          Toast(
              context, AppLocalizations.of(context)!.store_update_error, false);
      }
    } catch (_) {
      if (mounted)
        Toast(context, AppLocalizations.of(context)!.store_update_error, false);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _dropDelivery(Commande commande) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(ctx)!.delivery_abandon_confirm),
        content: Text(AppLocalizations.of(ctx)!.delivery_abandon_body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(ctx)!.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.delivery_abandon),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => isLoading = true);
    try {
      final ok = await LivreurApi.dropDelivery(commande.commandeID, driverID);
      if (ok) {
        _stopSharingLocation();
        await _load();
        if (mounted)
          Toast(
              context, AppLocalizations.of(context)!.delivery_abandoned, true);
      } else {
        if (mounted)
          Toast(context, AppLocalizations.of(context)!.delivery_abandon_error,
              false);
      }
    } catch (_) {
      if (mounted)
        Toast(context, AppLocalizations.of(context)!.delivery_abandon_error,
            false);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<LigneCommande>> _getLignes(int id) =>
      LigneCommande.fetchLignesCommandeByCommandeID(id);

  // ── Helpers ──────────────────────────────────────────────
  String _deliveryStatusLabel(String? status) {
    final l10n = AppLocalizations.of(context)!;
    final s = DeliveryStatus.normalize(status);
    return {
          DeliveryStatus.assigned: l10n.delivery_status_assigned,
          DeliveryStatus.atPickup: 'Au restaurant',
          DeliveryStatus.pickedUp: l10n.delivery_status_picked_up,
          DeliveryStatus.inTransit: l10n.delivery_status_in_transit,
          DeliveryStatus.delivered: l10n.delivery_status_delivered,
        }[s] ??
        l10n.delivery_status_assigned;
  }

  static Color _deliveryStatusColor(String? status) {
    final s = DeliveryStatus.normalize(status);
    return {
          DeliveryStatus.assigned: Colors.orange,
          DeliveryStatus.atPickup: AppColors.accent,
          DeliveryStatus.pickedUp: AppColors.accent,
          DeliveryStatus.inTransit: AppColors.brand,
          DeliveryStatus.delivered: AppColors.success,
        }[s] ??
        AppColors.inkSubtle;
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.myDeliveries),
        actions: [
          // Badge nombre de livraisons actives
          if (deliveries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${deliveries.length} ${l10n.myDeliveries}',
                  style: AppTypography.labelMedium(color: Colors.white)
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Header statut en ligne ───────────────────────
          _buildOnlineHeader(),
          // ── Filtres ──────────────────────────────────────
          _buildFilters(),
          // ── Liste ────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : deliveries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.brand,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          itemCount: deliveries.length,
                          itemBuilder: (_, i) => _buildCard(deliveries[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Header en ligne / hors ligne ─────────────────────────
  Widget _buildOnlineHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: (isOnline ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.30),
          width: 0.8,
        ),
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_rounded,
              color: isOnline ? AppColors.success : AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? l10n.delivery_online : l10n.delivery_offline,
                  style: AppTypography.labelLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_totalDeliveries ${l10n.myDeliveries} · ${CurrencyUtil.formatPrice(_totalEarnings, _country)}',
                  style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.inkSubtle, AppDarkColors.inkSubtle))
                      .copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            activeColor: AppColors.success,
            onChanged: (_) => _toggleOnline(),
          ),
        ],
      ),
    );
  }

  // ── Filtres de statut ────────────────────────────────────
  Widget _buildFilters() {
    final l10n = AppLocalizations.of(context)!;
    final statuses = [
      '__all__',
      DeliveryStatus.assigned,
      DeliveryStatus.atPickup,
      DeliveryStatus.pickedUp,
      DeliveryStatus.inTransit,
      DeliveryStatus.delivered,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) {
          final active = statusFilter == (s == '__all__' ? null : s);
          final label = s == '__all__' ? l10n.all : _deliveryStatusLabel(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter = s == '__all__' ? null : s);
                _loadDeliveries();
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.brand
                      : AppColors.resolve(AppColors.card, AppDarkColors.card),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: active
                          ? AppColors.brand
                          : AppColors.resolve(
                              AppColors.border, AppDarkColors.border),
                      width: 0.5),
                ),
                child: Text(label,
                    style: AppTypography.labelMedium(
                        color: active
                            ? Colors.white
                            : AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Carte de livraison (même modèle que UserOrdersPage) ──
  Widget _buildCard(Commande c) {
    final status = DeliveryStatus.normalize(c.deliveryStatus);
    final statusColor = _deliveryStatusColor(status);
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
                    // ── En-tête : Icône + infos + badge statut ─
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.delivery_dining_rounded,
                                color: statusColor, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restoNames[c.restauID] ??
                                      'Commande #${c.commandeID}',
                                  style: AppTypography.labelLarge(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${c.commandeID} · $dateStr · ${c.heure}',
                                  style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.inkSubtle,
                                              AppDarkColors.inkSubtle))
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          _DeliveryStatusBadge(
                              status: status, color: statusColor),
                        ],
                      ),
                    ),

                    // ── Delivery details (distance, tip, etc.) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                              AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Distance
                            if (c.distance != null)
                              Row(
                                children: [
                                  Icon(Icons.route_rounded,
                                      size: 14,
                                      color: AppColors.resolve(
                                          AppColors.inkMuted,
                                          AppDarkColors.inkMuted)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${c.distance!.toStringAsFixed(1)} km',
                                    style: AppTypography.labelMedium(
                                        color: AppColors.resolve(
                                            AppColors.ink, AppDarkColors.ink)),
                                  ),
                                ],
                              ),
                            // Frais client avant livraison, puis revenus du livreur
                            Row(
                              children: [
                                Icon(Icons.money_rounded,
                                    size: 14,
                                    color: AppColors.resolve(AppColors.inkMuted,
                                        AppDarkColors.inkMuted)),
                                const SizedBox(width: 4),
                                Text(
                                  c.delivererEarningsStatus == 'recorded'
                                      ? CurrencyUtil.formatPrice(
                                          (c.delivererBasePay ?? 0) +
                                              (c.delivererDistancePay ?? 0) +
                                              (c.pourboire ?? 0),
                                          _country)
                                      : CurrencyUtil.formatPrice(
                                          c.fraisLivraison, _country),
                                  style: AppTypography.labelMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink)),
                                ),
                              ],
                            ),
                            // Tip
                            if (c.pourboire != null && c.pourboire! > 0)
                              Row(
                                children: [
                                  Icon(Icons.emoji_events_rounded,
                                      size: 14, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${CurrencyUtil.formatPrice(c.pourboire!, _country)}',
                                    style: AppTypography.labelMedium(
                                        color: AppColors.accent),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Payment status ──────────────────────────
                    if (c.paymentStatus != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                size: 14,
                                color: AppColors.resolve(AppColors.inkMuted,
                                    AppDarkColors.inkMuted)),
                            const SizedBox(width: 4),
                            _PaymentStatusBadge(
                                paymentStatus: c.paymentStatus!),
                            if (c.paymentDate != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                c.paymentDate!
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0],
                                style: AppTypography.labelMedium(
                                        color: AppColors.resolve(
                                            AppColors.inkSubtle,
                                            AppDarkColors.inkSubtle))
                                    .copyWith(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // ── Boutons d'action livreur ───────────────
                    if (status != DeliveryStatus.delivered)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                        child: Row(
                          children: [
                            if (status == DeliveryStatus.assigned)
                              Expanded(
                                child: _PrimaryActionButton(
                                  label: 'Aller au restaurant',
                                  icon: Icons.storefront_rounded,
                                  color: AppColors.accent,
                                  onTap: () => _acceptAndUpdateStatus(
                                    c,
                                    DeliveryStatus.atPickup,
                                    confirmTitle: 'Se rendre au restaurant ?',
                                    confirmBody:
                                        'Confirmez que vous prenez en charge la commande #${c.commandeID}.',
                                    confirmIcon: Icons.storefront_rounded,
                                  ),
                                ),
                              ),
                            if (status == DeliveryStatus.atPickup)
                              Expanded(
                                child: _PrimaryActionButton(
                                  label: AppLocalizations.of(context)!
                                      .delivery_status_picked_up,
                                  icon: Icons.shopping_bag_rounded,
                                  color: AppColors.accent,
                                  onTap: () => _acceptAndUpdateStatus(
                                    c,
                                    DeliveryStatus.pickedUp,
                                    confirmTitle: AppLocalizations.of(context)!
                                        .delivery_confirm_picked_title,
                                    confirmBody: AppLocalizations.of(context)!
                                        .delivery_confirm_picked_body(
                                            c.commandeID.toString()),
                                    confirmIcon: Icons.shopping_bag_rounded,
                                  ),
                                ),
                              ),
                            if (status == DeliveryStatus.pickedUp)
                              Expanded(
                                child: _PrimaryActionButton(
                                  label: AppLocalizations.of(context)!
                                      .delivery_status_in_transit,
                                  icon: Icons.directions_bike_rounded,
                                  color: AppColors.brand,
                                  onTap: () => _acceptAndUpdateStatus(
                                    c,
                                    DeliveryStatus.inTransit,
                                    confirmTitle: AppLocalizations.of(context)!
                                        .delivery_confirm_transit_title,
                                    confirmBody: AppLocalizations.of(context)!
                                        .delivery_confirm_transit_body(
                                            c.commandeID.toString()),
                                    confirmIcon: Icons.directions_bike_rounded,
                                  ),
                                ),
                              ),
                            if (status == DeliveryStatus.inTransit)
                              Expanded(
                                child: _PrimaryActionButton(
                                  label: AppLocalizations.of(context)!
                                      .delivery_status_delivered,
                                  icon: Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  onTap: () => _acceptAndUpdateStatus(
                                    c,
                                    DeliveryStatus.delivered,
                                    confirmTitle: AppLocalizations.of(context)!
                                        .delivery_confirm_delivered_title,
                                    confirmBody: AppLocalizations.of(context)!
                                        .delivery_confirm_delivered_body(
                                            c.commandeID.toString()),
                                    confirmIcon: Icons.local_shipping_rounded,
                                  ),
                                ),
                              ),
                            const SizedBox(width: AppSpacing.xs),
                            if (status != DeliveryStatus.delivered)
                              _IconActionButton(
                                icon: Icons.chat_rounded,
                                color: AppColors.resolve(
                                    AppColors.inkMuted, AppDarkColors.inkMuted),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                            withUserID: c.userID,
                                            withUsername:
                                                'Client #${c.userID}'))),
                              ),
                            if (status == DeliveryStatus.assigned ||
                                status == DeliveryStatus.atPickup ||
                                status == DeliveryStatus.pickedUp)
                              _IconActionButton(
                                icon: Icons.cancel_outlined,
                                color: AppColors.resolve(
                                    AppColors.error, AppDarkColors.error),
                                onTap: () => _dropDelivery(c),
                              ),
                          ],
                        ),
                      ),

                    // ── Voir le détail ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: Row(
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
                          const Spacer(),
                          Text(
                            CurrencyUtil.formatPrice(
                                c.fraisLivraison + (c.pourboire ?? 0),
                                _country),
                            style: AppTypography.labelMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))
                                .copyWith(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),

                    // ── Liste des plats ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                      child: FutureBuilder<List<LigneCommande>>(
                        future: _getLignes(c.commandeID),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          final lignes = snap.data!;
                          if (lignes.isEmpty) return const SizedBox.shrink();
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
                                              child: Text(
                                                '${l.quantite}',
                                                style:
                                                    AppTypography.labelMedium(
                                                            color:
                                                                AppColors.brand)
                                                        .copyWith(fontSize: 11),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              (l.nomPlat?.trim().isNotEmpty ==
                                                          true
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

                    // ── Infos client ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 14,
                              color: AppColors.resolve(AppColors.inkSubtle,
                                  AppDarkColors.inkSubtle)),
                          const SizedBox(width: 4),
                          Text(
                            'Client #${c.userID}',
                            style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.inkSubtle,
                                        AppDarkColors.inkSubtle))
                                .copyWith(fontSize: 12),
                          ),
                        ],
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

  // ── Empty state ──────────────────────────────────────────
  Widget _buildEmptyState() {
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
              child: Icon(Icons.delivery_dining_outlined,
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 34),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.delivery_no_data,
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Composants extraits
// ═══════════════════════════════════════════════════════════

// ── Badge statut livraison ─────────────────────────────────
class _DeliveryStatusBadge extends StatelessWidget {
  const _DeliveryStatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = DeliveryStatus.normalize(status);
    final label = {
          DeliveryStatus.assigned: l10n.delivery_status_assigned,
          DeliveryStatus.pickedUp: l10n.delivery_status_picked_up,
          DeliveryStatus.inTransit: l10n.delivery_status_in_transit,
          DeliveryStatus.delivered: l10n.delivery_status_delivered,
        }[s] ??
        l10n.delivery_status_assigned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Badge statut paiement ─────────────────────────────────
class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.paymentStatus});
  final String paymentStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Color bgColor;
    Color textColor;
    String label;

    switch (paymentStatus) {
      case 'paid':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        label = l10n.admin_delivery_status_validated;
        break;
      case 'pending':
      default:
        bgColor = AppColors.accentLight;
        textColor = AppColors.accent;
        label = l10n.admin_delivery_status_pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Bouton action primaire ─────────────────────────────────
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

// ── Bouton action icône seule ──────────────────────────────
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
