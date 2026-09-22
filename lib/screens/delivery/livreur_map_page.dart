import 'dart:math';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../orders/commande_details_page.dart';
import '../navigation/curved_navigation_livreur.dart';
import '../../l10n/app_localizations.dart';

class LivreurMapPage extends StatefulWidget {
  const LivreurMapPage({super.key});

  @override
  State<LivreurMapPage> createState() => _LivreurMapPageState();
}

class _LivreurMapPageState extends State<LivreurMapPage> {
  List<Commande> _availableOrders = [];
  Map<int, String> _restoNames = {};
  bool _isLoading = true;
  LatLng? _currentPosition;
  int _driverID = 0;
  String _country = 'France';
  bool _isDriverOnline = false;
  bool _accepting = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await SessionService.readSession();
    _driverID = session.userId;
    await _loadOnlineStatus();
    await _getPosition();
    await _loadData();
  }

  Future<void> _loadOnlineStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool('driver_online_$_driverID');
    if (cached != null && mounted) setState(() => _isDriverOnline = cached);
    try {
      final q = QueryBuilder<ParseObject>(ParseObject('Users'))
        ..whereEqualTo('userID', _driverID);
      final r = await q.query();
      if (r.success && r.results?.isNotEmpty == true) {
        final online = r.results!.first.get<bool>('isOnline') ?? false;
        await prefs.setBool('driver_online_$_driverID', online);
        if (mounted) setState(() => _isDriverOnline = online);
      }
    } catch (_) {}
  }

  Future<void> _getPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentPosition = const LatLng(48.8566, 2.3522));
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final restos = await Restaurant.fetchRestaurantsFromDB();
      final rNames = <int, String>{};
      for (final r in restos) {
        rNames[r.restaurantID] = r.name;
      }

      final maxDist = await LivreurApi.getMaxDeliveryDistance(_driverID);
      final session = await SessionService.readSession();
      _country = session.country;
      final cloudFn = ParseCloudFunction('getAvailableOrders');
      final response = await cloudFn.execute(parameters: {
        'livreurID': _driverID,
        'maxDistance': maxDist,
      });
      List<Commande> orders = [];
      if (response.success && response.result != null) {
        final data = response.result as List;
        orders = data
            .map((m) => Commande.fromMap(m as Map<String, dynamic>))
            .toList();
      }

      if (mounted) {
        setState(() {
          _availableOrders = orders;
          _restoNames = rNames;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrder(Commande cmd) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isDriverOnline) {
      Toast(context, l10n.delivery_must_be_online, false);
      return;
    }
    if (_accepting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_shipping_rounded,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.livreur_accept_title)),
        ]),
        content: Text(
          l10n.livreur_accept_body(
              cmd.commandeID.toString(),
              CurrencyUtil.formatPrice(
                  cmd.fraisLivraison + (cmd.pourboire ?? 0), _country)),
          style: AppTypography.bodyLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
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
            child: Text(l10n.livreur_map_accept),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _accepting = true);
    try {
      final ok = await LivreurApi.assignLivreur(cmd.commandeID, _driverID);
      if (!mounted) return;
      if (ok) {
        Toast(context, l10n.livreur_order_accepted(cmd.commandeID), true);
        await _loadData();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const CurvedNavigationLivreur(specified_index: 1)),
            (route) => route.isFirst,
          );
        }
      } else {
        Toast(context, l10n.livreur_order_already_in_progress, false);
      }
    } catch (_) {
      if (mounted) Toast(context, AppLocalizations.of(context)!.error, false);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  double _distanceInKm(LatLng a, LatLng b) {
    const R = 6371;
    final dLat = (b.latitude - a.latitude) * (pi / 180);
    final dLon = (b.longitude - a.longitude) * (pi / 180);
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final aVal = sinDLat * sinDLat +
        cos(a.latitude * (pi / 180)) *
            cos(b.latitude * (pi / 180)) *
            sinDLon *
            sinDLon;
    final c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.livreur_map_title(_availableOrders.length),
            style: AppTypography.titleMedium()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(child: Text(l10n.livreur_map_position_unavailable))
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 13,
                        onTap: (_, __) {},
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.diosdelices.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition!,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.resolve(
                                      AppColors.brand, AppDarkColors.brand),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black26, blurRadius: 8)
                                  ],
                                ),
                                child: const Icon(Icons.delivery_dining_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // ── Bandeau hors-ligne ──────────────────────────
                    if (!_isDriverOnline)
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.resolve(
                                AppColors.errorLight, AppDarkColors.errorLight),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: [AppShadows.subtle],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.offline_bolt_rounded,
                                  size: 20,
                                  color: AppColors.resolve(
                                      AppColors.error, AppDarkColors.error)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.delivery_offline,
                                  style: AppTypography.labelMedium(
                                      color: AppColors.resolve(AppColors.error,
                                          AppDarkColors.error)),
                                ),
                              ),
                              GestureDetector(
                                onTap: _goOnlineAndRefresh,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.resolve(
                                        AppColors.successLight,
                                        AppDarkColors.successLight),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(l10n.delivery_toggle_online,
                                      style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.success,
                                              AppDarkColors.success))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _availableOrders.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.resolve(
                                    AppColors.card, AppDarkColors.card),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                boxShadow: [AppShadows.elevated],
                              ),
                              child: Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.resolve(AppColors.success,
                                        AppDarkColors.success),
                                    size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                      AppLocalizations.of(context)!
                                          .livreur_map_no_orders,
                                      style: AppTypography.bodyMedium(
                                          color: AppColors.resolve(
                                              AppColors.ink,
                                              AppDarkColors.ink))),
                                ),
                              ]),
                            )
                          : Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.resolve(
                                    AppColors.card, AppDarkColors.card),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                boxShadow: [AppShadows.elevated],
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.all(8),
                                itemCount: _availableOrders.length,
                                itemBuilder: (_, i) =>
                                    _buildOrderCard(_availableOrders[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _goOnlineAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDriverOnline = true);
    await prefs.setBool('driver_online_$_driverID', true);
    try {
      await LivreurApi.toggleOnlineStatus(_driverID, true);
    } catch (_) {}
    if (mounted) {
      Toast(
          context, AppLocalizations.of(context)!.delivery_toggle_online, true);
    }
  }

  Widget _buildOrderCard(Commande cmd) {
    final l10n = AppLocalizations.of(context)!;
    final restoName =
        _restoNames[cmd.restauID] ?? 'Restaurant #${cmd.restauID}';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommandeDetailsPage(commande: cmd),
        ),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.resolve(
              AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.accentLight, AppDarkColors.accentLight),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.receipt_rounded,
                    size: 13,
                    color: AppColors.resolve(
                        AppColors.accent, AppDarkColors.accent)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('#${cmd.commandeID}',
                    style: AppTypography.labelMedium(
                            color: AppColors.resolve(
                                AppColors.accent, AppDarkColors.accent))
                        .copyWith(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(restoName,
                style: AppTypography.labelMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                    .copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(CurrencyUtil.formatPrice(cmd.totalAmount, _country),
                style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand))
                    .copyWith(fontSize: 12)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: AbsorbPointer(
                absorbing: !_isDriverOnline || _accepting,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDriverOnline
                        ? AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand)
                        : AppColors.resolve(
                            AppColors.inkSubtle, AppDarkColors.inkSubtle),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _acceptOrder(cmd),
                  child: Text(
                      _accepting
                          ? '…'
                          : _isDriverOnline
                              ? l10n.livreur_map_accept
                              : l10n.delivery_offline,
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
