import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/restaurant.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});
  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  List<Map<String, dynamic>> deliveries = [];
  Map<int, String> restoNames = {};
  bool isLoading = true;
  bool isOnline = false;
  int driverID = 0;
  int? activeCommandeID;
  Timer? _locationTimer;
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    driverID = session.userId;

    final restos = await Restaurant.fetchRestaurantsFromDB();
    final rNames = <int, String>{};
    for (final r in restos) { rNames[r.restaurantID] = r.name; }

    await Future.wait([_loadDeliveries(), _loadEarnings()]);
    if (mounted) setState(() { restoNames = rNames; isLoading = false; });
  }

  Future<void> _loadDeliveries() async {
    try {
      final func = ParseCloudFunction('getMyDeliveries');
      final resp = await func.execute(parameters: {'userID': driverID});
      if (resp.success && resp.result != null && mounted) {
        setState(() {
          deliveries = List<Map<String, dynamic>>.from(resp.result as List);
          isLoading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEarnings() async {
    try {
      final func = ParseCloudFunction('getLivreurEarnings');
      final resp = await func.execute(parameters: {'userID': driverID});
      if (resp.success && resp.result != null && mounted) {
        final data = resp.result as Map<String, dynamic>;
        setState(() {
          _totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0;
          _totalDeliveries = (data['count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    try {
      final func = ParseCloudFunction('toggleOnlineStatus');
      final resp = await func.execute(parameters: {'userID': driverID, 'isOnline': !isOnline});
      if (resp.success && resp.result != null && mounted) {
        final data = resp.result as Map<String, dynamic>;
        setState(() => isOnline = data['isOnline'] == true);
      }
    } catch (_) {}
  }

  void _startSharingLocation(int commandeID) {
    _locationTimer?.cancel();
    activeCommandeID = commandeID;
    _sendLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  void _stopSharingLocation() {
    _locationTimer?.cancel();
    activeCommandeID = null;
  }

  Future<void> _sendLocation() async {
    if (activeCommandeID == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      final func = ParseCloudFunction('updateLivreurPosition');
      await func.execute(parameters: {
        'userID': driverID, 'commandeID': activeCommandeID,
        'lat': pos.latitude, 'lng': pos.longitude,
      });
    } catch (_) {}
  }

  Future<void> _updateStatus(int commandeID, String newStatus) async {
    try {
      final func = ParseCloudFunction('updateDeliveryStatus');
      await func.execute(parameters: {
        'userID': driverID, 'commandeID': commandeID, 'deliveryStatus': newStatus,
      });
      if (newStatus == 'in_transit') { _startSharingLocation(commandeID); }
      else if (newStatus == 'delivered') { _stopSharingLocation(); }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour : $newStatus')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Carte plein écran ──────────────────────
          Positioned.fill(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(48.8566, 2.3522),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.diosdelices.app',
                ),
                if (deliveries.isNotEmpty)
                  MarkerLayer(
                    markers: deliveries
                        .where((d) => d['deliveryStatus'] == 'in_transit')
                        .map((d) => Marker(
                          point: LatLng(
                            (d['livreurLat'] as num?)?.toDouble() ?? 48.85,
                            (d['livreurLng'] as num?)?.toDouble() ?? 2.35,
                          ),
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                          ),
                        ))
                        .toList(),
                  ),
              ],
            ),
          ),

          // ── Header overlay ─────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.floatingList,
                      ),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.successLight : AppColors.errorLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                            color: isOnline ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(isOnline ? 'En ligne' : 'Hors ligne',
                                style: AppTypography.titleMedium()),
                            Text('${_totalDeliveries} livraisons · ${_totalEarnings.toStringAsFixed(0)} €',
                                style: AppTypography.bodyMedium()),
                          ]),
                        ),
                        Switch(
                          value: isOnline,
                          activeColor: AppColors.success,
                          onChanged: (_) => _toggleOnline(),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Bottom sheet des livraisons ────────────
          if (deliveries.isNotEmpty || isLoading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.22,
                minChildSize: 0.1,
                maxChildSize: 0.75,
                builder: (_, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A261814),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Poignée
                        const SizedBox(height: 10),
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(children: [
                            Text('Livraisons', style: AppTypography.titleMedium()),
                            const Spacer(),
                            Text('${deliveries.length}', style: AppTypography.titleMedium(color: AppColors.brand)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : deliveries.isEmpty
                                  ? const Center(child: Text('Aucune livraison'))
                                  : ListView.builder(
                                      controller: scrollController,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: deliveries.length,
                                      itemBuilder: (_, i) => _buildDeliveryCard(deliveries[i]),
                                    ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> d) {
    final status = (d['deliveryStatus'] ?? 'assigned').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Commande #${d['commandeID']}', style: AppTypography.labelMedium()),
          const Spacer(),
          _StatusBadge(status: status),
        ]),
        const SizedBox(height: 8),
        Text('Restaurant : ${restoNames[d['restauID']] ?? 'n°${d['restauID']}'}',
            style: AppTypography.bodyMedium()),
        Text('Frais : ${(d['fraisLivraison'] ?? 0.0).toStringAsFixed(2)} €',
            style: AppTypography.bodyMedium()),
        if (status == 'in_transit') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(
                    (d['livreurLat'] as num?)?.toDouble() ?? 48.85,
                    (d['livreurLng'] as num?)?.toDouble() ?? 2.35,
                  ),
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.diosdelices.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(
                        (d['livreurLat'] as num?)?.toDouble() ?? 48.85,
                        (d['livreurLng'] as num?)?.toDouble() ?? 2.35,
                      ),
                      width: 24, height: 24,
                      child: const Icon(Icons.my_location, color: AppColors.brand, size: 20),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (status == 'assigned')
              _ActionBtn('Récupéré', Icons.shopping_bag_rounded, AppColors.accent,
                  () => _updateStatus(d['commandeID'] as int, 'picked_up')),
            if (status == 'picked_up')
              _ActionBtn('En route', Icons.directions_bike_rounded, AppColors.brand,
                  () => _updateStatus(d['commandeID'] as int, 'in_transit')),
            if (status == 'in_transit')
              _ActionBtn('Livré', Icons.check_rounded, AppColors.success,
                  () => _updateStatus(d['commandeID'] as int, 'delivered')),
          ],
        ),
      ]),
    );
  }

  Widget _ActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        elevation: 0,
        minimumSize: const Size(100, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = {
      'assigned': 'Assigné', 'picked_up': 'Récupéré',
      'in_transit': 'En route', 'delivered': 'Livré'
    }[status] ?? status;
    final color = {
      'assigned': AppColors.inkSubtle, 'picked_up': AppColors.accent,
      'in_transit': AppColors.brand, 'delivered': AppColors.success
    }[status] ?? AppColors.inkSubtle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}
