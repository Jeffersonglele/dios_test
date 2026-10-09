import 'dart:async';
import 'dart:io' show File;
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
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/toast.dart';
import '../orders/commande_details_page.dart';
import '../chat/chat_screen.dart';
import '../../l10n/app_localizations.dart';
import 'available_deliveries_tab.dart';
import 'active_delivery_screen.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Commande> deliveries = [];
  Map<int, String> restoNames = {};
  Map<int, String> dishNames = {};
  bool isLoading = true;
  String _country = 'RDC';
  bool isOnline = false;
  int driverID = 0;
  int? activeCommandeID;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStreamSub;
  DateTime _lastApiSave = DateTime(2000);
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  String? statusFilter;

  final LiveQuery liveQuery = LiveQuery();
  Subscription? sub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    _listen();
    _initSocket();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _locationTimer?.cancel();
    _positionStreamSub?.cancel();
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    // Ne pas déconnecter le socket car c'est un singleton partagé
    // Le socket restera connecté tant que l'application est ouverte
    super.dispose();
  }

  // ── Socket.io initialization ─────────────────────────────
  Future<void> _initSocket() async {
    await SocketService().connect();
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
          _loadedOnce = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (mounted) {
        Toast(context, '${AppLocalizations.of(context)!.error}: $e', false);
        setState(() {
          isLoading = false;
          _loadedOnce = true;
        });
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

  Future<void> _startSharingLocation([int? commandeID]) async {
    _locationTimer?.cancel();
    _positionStreamSub?.cancel();
    if (commandeID != null) activeCommandeID = commandeID;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Ensure Socket.io connection is ready
      unawaited(SocketService().connect());

      // Force instant API save on startup / online toggle
      _lastApiSave = DateTime(2000);

      // 1. Immediate position capture right now when going online
      await _sendLocationOnce();

      // 2. Continuous GPS stream with 5m filter for real-time movement
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPositionUpdate, onError: (_) {});

      // 3. Fallback heartbeat timer every 15s to keep location fresh
      _locationTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sendLocationOnce(),
      );
    } catch (e) {
      debugPrint('⚠️ Erreur partage position livreur: $e');
    }
  }

  void _stopSharingLocation() {
    _locationTimer?.cancel();
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    activeCommandeID = null;
  }

  /// Called on every GPS position update from stream or heartbeat.
  void _onPositionUpdate(Position pos) {
    if (!isOnline) return;

    // 1. Emit real-time via Socket.io (instant, every update) if order active
    final currentOrderId = activeCommandeID ?? _currentActiveDeliveryId();
    if (currentOrderId != null) {
      SocketService().emit('courier_location_update', {
        'orderId': currentOrderId.toString(),
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracyM': pos.accuracy,
        'heading': pos.heading,
      });
    }

    // 2. Throttled HTTP API save to update PostGIS location (every 15s)
    final now = DateTime.now();
    if (now.difference(_lastApiSave).inSeconds >= 15) {
      _lastApiSave = now;
      LivreurApi.updatePosition(
        driverID,
        pos.latitude,
        pos.longitude,
        accuracyM: pos.accuracy,
        commandeID: activeCommandeID,
      );
    }
  }

  /// Single-shot location push (instant fetch & fallback heartbeat).
  Future<void> _sendLocationOnce() async {
    if (!isOnline) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _onPositionUpdate(last);

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _onPositionUpdate(pos);
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

  /// Ouvre l'écran de course active : « Je suis arrivé » → chrono 10 min →
  /// photo + code OTP → « Valider la livraison » (ou client injoignable).
  Future<void> _validateRide(Commande c) async {
    final l10n = AppLocalizations.of(context)!;
    if (!isOnline) {
      Toast(context, l10n.delivery_must_be_online, false);
      return;
    }
    if (isLoading) return;
    final result = await Navigator.push<ActiveDeliveryResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveDeliveryScreen(
          orderId: c.commandeID,
          clientName: 'Client #${c.userID}',
          restaurantName: restoNames[c.restauID],
          uploadPhoto: (photo) => _uploadProofPhoto(c.commandeID, photo),
        ),
      ),
    );
    if (result != null && mounted) {
      _stopSharingLocation();
      await _load();
      if (mounted) {
        Toast(
          context,
          result == ActiveDeliveryResult.delivered
              ? '✅ ${_deliveryStatusLabel(DeliveryStatus.delivered)}'
              : 'Course clôturée : client injoignable',
          result == ActiveDeliveryResult.delivered,
        );
      }
    }
  }

  /// Envoi de la photo de preuve (stockage Parse, comme les autres images
  /// de l'app) → renvoie l'URL à poster dans `proofPhotoUrl`.
  /// Remplacez le corps si votre upload passe par un autre service.
  Future<String> _uploadProofPhoto(int commandeID, File photo) async {
    final file = ParseFile(
      photo,
      name: 'proof_${commandeID}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final res = await file.save();
    final url = file.url;
    if (!res.success || url == null || url.isEmpty) {
      throw Exception("Échec de l'envoi de la photo");
    }
    return url;
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

  /// Devenu `true` après le premier chargement (sert à n'afficher les
  /// squelettes qu'au tout premier affichage).
  bool _loadedOnce = false;

  void _openDetails(Commande c) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CommandeDetailsPage(commande: c)),
      );

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(title: Text(l10n.myDeliveries)),
      body: Column(
        children: [
          // ── Statut en ligne + chiffres du jour (commun aux 2 onglets) ──
          _buildOnlineHeader(),
          _buildTabSwitcher(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildMyDeliveriesTab(),
                AvailableDeliveriesTab(
                  isOnline: isOnline,
                  // course acceptée → on recharge et on revient sur « Mes courses »
                  onAccepted: (_) async {
                    await _load();
                    if (mounted) _tabs.animateTo(0);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sélecteur d'onglets en « pilule » ────────────────────
  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _warm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: TabBar(
        controller: _tabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(AppRadius.md),
        indicator: BoxDecoration(
          color: _brandC,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: _brandC.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(height: 38, text: 'Mes courses'),
          Tab(height: 38, text: 'Disponibles'),
        ],
      ),
    );
  }

  // ── Onglet « Mes courses » (filtres + liste) ─────────────
  Widget _buildMyDeliveriesTab() {
    final showSkeleton = isLoading && !_loadedOnce && deliveries.isEmpty;
    return Column(
      children: [
        _buildFilters(),
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
                    _SkeletonCard(),
                    _SkeletonCard(),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _brandC,
                  child: deliveries.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: deliveries.length,
                          itemBuilder: (_, i) => _buildCard(deliveries[i]),
                        ),
                ),
        ),
      ],
    );
  }

  // ── Carte « en ligne / hors ligne » + chiffres ───────────
  Widget _buildOnlineHeader() {
    final l10n = AppLocalizations.of(context)!;
    final on = isOnline;
    final deep = Color.lerp(_brandC, Colors.black, 0.25)!;
    final fg = on ? Colors.white : _ink;
    final sub = on ? Colors.white.withValues(alpha: 0.80) : _muted;

    return AnimatedContainer(
      duration: AppMotion.fast,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: on
            ? LinearGradient(
                colors: [_brandC, deep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: on ? null : _cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: on ? null : Border.all(color: _line, width: 0.8),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: on
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  on ? Icons.bolt_rounded : Icons.pause_rounded,
                  color: on ? Colors.white : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on ? l10n.delivery_online : l10n.delivery_offline,
                      style: AppTypography.labelLarge(color: fg)
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      on
                          ? 'Votre position est partagée'
                          : 'Passez en ligne pour recevoir des courses',
                      style: AppTypography.bodyMedium(color: sub)
                          .copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: (_) => _toggleOnline(),
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackOutlineColor:
                    WidgetStateProperty.all(Colors.transparent),
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white.withValues(alpha: 0.38)
                        : _subtle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  icon: Icons.delivery_dining_rounded,
                  value: '$_totalDeliveries',
                  label: l10n.myDeliveries,
                  onDark: on,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  icon: Icons.payments_rounded,
                  value: CurrencyUtil.formatPrice(_totalEarnings, _country),
                  label: 'Gains',
                  onDark: on,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses.map((s) {
          final isAll = s == '__all__';
          final active = statusFilter == (isAll ? null : s);
          final label = isAll ? l10n.all : _deliveryStatusLabel(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter = isAll ? null : s);
                _loadDeliveries();
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _brandC : _cardBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: active ? _brandC : _line, width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isAll) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : _deliveryStatusColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppTypography.labelMedium(
                              color: active ? Colors.white : _muted)
                          .copyWith(
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Barre de progression de la course (5 étapes) ─────────
  Widget _buildProgress(String status, Color color) {
    final flow = [
      DeliveryStatus.assigned,
      DeliveryStatus.atPickup,
      DeliveryStatus.pickedUp,
      DeliveryStatus.inTransit,
      DeliveryStatus.delivered,
    ];
    final idx = flow.indexOf(status);
    return Row(
      children: List.generate(flow.length, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 4,
            margin: EdgeInsets.only(right: i == flow.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: i <= idx ? color : _line.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  // ── Bouton principal selon l'étape (logique inchangée) ───
  Widget? _primaryActionFor(Commande c, String status) {
    final l10n = AppLocalizations.of(context)!;
    if (status == DeliveryStatus.assigned) {
      return _PrimaryActionButton(
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
      );
    }
    if (status == DeliveryStatus.atPickup) {
      return _PrimaryActionButton(
        label: l10n.delivery_status_picked_up,
        icon: Icons.shopping_bag_rounded,
        color: AppColors.accent,
        onTap: () => _acceptAndUpdateStatus(
          c,
          DeliveryStatus.pickedUp,
          confirmTitle: l10n.delivery_confirm_picked_title,
          confirmBody: l10n.delivery_confirm_picked_body(c.commandeID.toString()),
          confirmIcon: Icons.shopping_bag_rounded,
        ),
      );
    }
    if (status == DeliveryStatus.pickedUp) {
      return _PrimaryActionButton(
        label: l10n.delivery_status_in_transit,
        icon: Icons.directions_bike_rounded,
        color: AppColors.brand,
        onTap: () => _acceptAndUpdateStatus(
          c,
          DeliveryStatus.inTransit,
          confirmTitle: l10n.delivery_confirm_transit_title,
          confirmBody:
              l10n.delivery_confirm_transit_body(c.commandeID.toString()),
          confirmIcon: Icons.directions_bike_rounded,
        ),
      );
    }
    if (status == DeliveryStatus.inTransit) {
      return _PrimaryActionButton(
        label: 'Terminer la course',
        icon: Icons.flag_rounded,
        color: AppColors.success,
        onTap: () => _validateRide(c),
      );
    }
    return null;
  }

  // ── Carte de course ──────────────────────────────────────
  Widget _buildCard(Commande c) {
    final l10n = AppLocalizations.of(context)!;
    final status = DeliveryStatus.normalize(c.deliveryStatus);
    final statusColor = _deliveryStatusColor(status);
    final dateStr = c.dateCommande.toLocal().toString().split(' ')[0];

    // Frais client avant livraison, puis revenus du livreur (logique d'origine)
    final bool recorded = c.delivererEarningsStatus == 'recorded';
    final double gain = recorded
        ? (c.delivererBasePay ?? 0) +
            (c.delivererDistancePay ?? 0) +
            (c.pourboire ?? 0)
        : c.fraisLivraison;
    final double tip = c.pourboire ?? 0;

    // Cellules de chiffres (distance · gain · pourboire)
    final cells = <Widget>[
      if (c.distance != null)
        _StatCell(
          icon: Icons.route_rounded,
          label: 'Distance',
          value: '${c.distance!.toStringAsFixed(1)} km',
          valueColor: _ink,
          muted: _muted,
        ),
      _StatCell(
        icon: Icons.payments_rounded,
        label: recorded ? 'Gain' : 'Frais',
        value: CurrencyUtil.formatPrice(gain, _country),
        valueColor: _ink,
        muted: _muted,
      ),
      if (tip > 0)
        _StatCell(
          icon: Icons.emoji_events_rounded,
          label: 'Pourboire',
          value: '+${CurrencyUtil.formatPrice(tip, _country)}',
          valueColor: AppColors.accent,
          muted: _muted,
        ),
    ];
    final statRow = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        statRow.add(Container(
            width: 1, height: 30, color: _line.withValues(alpha: 0.6)));
      }
      statRow.add(Expanded(child: cells[i]));
    }

    final primary = _primaryActionFor(c, status);
    final canDrop = status == DeliveryStatus.assigned ||
        status == DeliveryStatus.atPickup ||
        status == DeliveryStatus.pickedUp;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: _line.withValues(alpha: 0.7), width: 0.8),
        boxShadow: [AppShadows.subtle],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête cliquable : restaurant, n°, statut, progression ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openDetails(c),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(Icons.delivery_dining_rounded,
                                color: statusColor, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restoNames[c.restauID] ??
                                      'Commande #${c.commandeID}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge(color: _ink)
                                      .copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${c.commandeID} · $dateStr · ${c.heure}',
                                  style:
                                      AppTypography.labelMedium(color: _subtle)
                                          .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DeliveryStatusBadge(
                            label: _deliveryStatusLabel(status),
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildProgress(status, statusColor),
                    ],
                  ),
                ),
              ),
            ),

            // ── Chiffres clés ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _warm,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: statRow),
              ),
            ),

            // ── Client + paiement ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 2, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 15, color: _subtle),
                  const SizedBox(width: 4),
                  Text(
                    'Client #${c.userID}',
                    style: AppTypography.bodyMedium(color: _muted)
                        .copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  if (c.paymentStatus != null) ...[
                    _PaymentStatusBadge(paymentStatus: c.paymentStatus!),
                    if (c.paymentDate != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        c.paymentDate!.toLocal().toString().split(' ')[0],
                        style: AppTypography.labelMedium(color: _subtle)
                            .copyWith(fontSize: 10),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // ── Plats (repliable) ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: _DishesSection(
                key: ValueKey('dishes_${c.commandeID}'),
                orderId: c.commandeID,
                loader: _getLignes,
                dishNames: dishNames,
                country: _country,
                subtotalLabel: l10n.subtotal,
              ),
            ),

            // ── Actions livreur ──────────────────────────────
            if (primary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: primary),
                    const SizedBox(width: AppSpacing.sm),
                    _IconActionButton(
                      icon: Icons.chat_rounded,
                      color: _muted,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                  orderId: c.commandeID,
                                  recipientName: 'Client #${c.userID}'))),
                    ),
                    if (canDrop) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _IconActionButton(
                        icon: Icons.cancel_outlined,
                        color: AppColors.resolve(
                            AppColors.error, AppDarkColors.error),
                        onTap: () => _dropDelivery(c),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Pied : voir le détail ────────────────────────
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
                            .copyWith(
                                fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: _brandC),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── État vide ────────────────────────────────────────────
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final filtered = statusFilter != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 48, AppSpacing.xl, 40),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delivery_dining_outlined,
                color: _brandC, size: 40),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          filtered ? 'Aucune course avec ce statut' : l10n.delivery_no_data,
          textAlign: TextAlign.center,
          style: AppTypography.titleMedium(color: _ink),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          filtered
              ? 'Essayez un autre filtre.'
              : isOnline
                  ? 'Consultez l’onglet « Disponibles » pour prendre une course.'
                  : 'Passez en ligne pour voir les courses disponibles.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium(color: _muted),
        ),
        if (!filtered) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: SizedBox(
              width: 240,
              child: _PrimaryActionButton(
                label: isOnline ? 'Voir les courses disponibles' : 'Passer en ligne',
                icon: isOnline ? Icons.search_rounded : Icons.bolt_rounded,
                color: AppColors.brand,
                onTap: () => isOnline ? _tabs.animateTo(1) : _toggleOnline(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Composants extraits
// ═══════════════════════════════════════════════════════════

// ── Chiffre de l'en-tête (courses / gains) ─────────────────
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.onDark,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark
        ? Colors.white
        : AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final sub = onDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.resolve(
                AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 1),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: sub, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cellule de chiffre dans la carte de course ─────────────
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.muted,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: muted),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: muted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ── Liste des plats repliable ──────────────────────────────
class _DishesSection extends StatefulWidget {
  const _DishesSection({
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
  State<_DishesSection> createState() => _DishesSectionState();
}

class _DishesSectionState extends State<_DishesSection> {
  late final Future<List<LigneCommande>> _future;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    // chargé une seule fois (avant : rechargé à chaque rebuild de la page)
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

// ── Squelette de carte (premier chargement) ────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
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
                  children: [box(150, 14), const SizedBox(height: 6), box(100, 10)],
                ),
              ),
              box(70, 22, 999),
            ]),
            const SizedBox(height: 14),
            box(double.infinity, 4, 999),
            const SizedBox(height: 14),
            box(double.infinity, 52, 12),
            const SizedBox(height: 12),
            box(double.infinity, 46, 12),
          ],
        ),
      ),
    );
  }
}

// ── Badge statut livraison ─────────────────────────────────
class _DeliveryStatusBadge extends StatelessWidget {
  const _DeliveryStatusBadge({required this.label, required this.color});
  final String label;
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
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
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
        bgColor =
            AppColors.resolve(AppColors.successLight, AppDarkColors.successLight);
        textColor = AppColors.success;
        label = l10n.admin_delivery_status_validated;
        break;
      case 'pending':
      default:
        bgColor =
            AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight);
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

// ── Bouton action primaire (plein, plus visible) ───────────
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