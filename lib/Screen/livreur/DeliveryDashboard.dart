import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/commande.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  List<Commande> deliveries = [];
  Map<int, String> restoNames = {};
  bool isLoading = true;
  bool isOnline = false;
  int driverID = 0;
  int? activeCommandeID;
  Timer? _locationTimer;
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

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
    setState(() => isLoading = true);

    try {
      final session = await SessionService.readSession();
      driverID = session.userId;

      // Charger les restaurants
      final restos = await Restaurant.fetchRestaurantsFromDB();
      final rNames = <int, String>{};
      for (final r in restos) {
        rNames[r.restaurantID] = r.name;
      }

      // Charger les commandes du livreur
      await _loadDeliveries();
      await _loadEarnings();
      await _loadOnlineStatus();

      if (mounted) {
        setState(() {
          restoNames = rNames;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (mounted) {
        Toast(context, 'Erreur de chargement: $e', false);
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadDeliveries() async {
    try {
      // Récupérer les commandes depuis la base locale
      final allCommandes = await Commande.fetchCommandesFromDB();

      // Filtrer les commandes assignées à ce livreur
      final myDeliveries = allCommandes
          .where((c) =>
              c.livreurID == driverID &&
              c.deliveryStatus != 'delivered' &&
              c.deliveryStatus != 'cancelled')
          .toList();

      // Trier par date
      myDeliveries.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

      if (mounted) {
        setState(() {
          deliveries = myDeliveries;
        });
      }

      debugPrint('📦 Livraisons chargées: ${myDeliveries.length}');
    } catch (e) {
      debugPrint('❌ Erreur chargement livraisons: $e');
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final allCommandes = await Commande.fetchCommandesFromDB();
      final deliveredCommandes = allCommandes
          .where(
              (c) => c.livreurID == driverID && c.deliveryStatus == 'delivered')
          .toList();

      _totalDeliveries = deliveredCommandes.length;
      _totalEarnings = deliveredCommandes.fold<double>(
          0, (sum, c) => sum + c.fraisLivraison);
    } catch (e) {
      debugPrint('❌ Erreur chargement gains: $e');
    }
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final users = await Users.fetchUsersFromDB();
      final driver = users.firstWhere(
        (u) => u.userID == driverID,
        orElse: () => users.isNotEmpty ? users.first : Users.fromMap(const {}),
      );

      if (mounted) {
        setState(() {
          // Le modèle Users utilise le champ `isOnline` (bool).
          isOnline = driver.isOnline;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement statut: $e');
    }
  }

  Future<void> _toggleOnline() async {
    setState(() => isOnline = !isOnline);

    try {
      final cloudFunction = ParseCloudFunction('toggleOnlineStatus');
      final response = await cloudFunction.execute(parameters: {
        'userID': driverID,
        'isOnline': isOnline,
      });

      if (!response.success) {
        setState(() => isOnline = !isOnline);
        Toast(context, 'Erreur: ${response.error?.message}', false);
      } else {
        Toast(
            context,
            isOnline
                ? '✅ Vous êtes maintenant en ligne'
                : '⛔ Vous êtes hors ligne',
            true);
      }
    } catch (e) {
      setState(() => isOnline = !isOnline);
      Toast(context, 'Erreur lors du changement de statut', false);
    }
  }

  void _startSharingLocation(int commandeID) {
    _locationTimer?.cancel();
    activeCommandeID = commandeID;
    _sendLocation();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _sendLocation());
  }

  void _stopSharingLocation() {
    _locationTimer?.cancel();
    activeCommandeID = null;
  }

  Future<void> _sendLocation() async {
    if (activeCommandeID == null) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final cloudFunction = ParseCloudFunction('updateLivreurPosition');
      await cloudFunction.execute(parameters: {
        'commandeID': activeCommandeID,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (e) {
      debugPrint('❌ Erreur envoi position: $e');
    }
  }

  Future<void> _updateStatus(Commande commande, String newStatus) async {
    try {
      final cloudFunction = ParseCloudFunction('updateDeliveryStatus');
      final response = await cloudFunction.execute(parameters: {
        'commandeID': commande.commandeID,
        'deliveryStatus': newStatus,
      });

      if (response.success) {
        if (newStatus == 'in_transit') {
          _startSharingLocation(commande.commandeID);
        } else if (newStatus == 'delivered') {
          _stopSharingLocation();
        }

        await _load();

        if (mounted) {
          Toast(context, '✅ Statut mis à jour : $newStatus', true);
        }
      } else {
        Toast(context, '❌ Erreur: ${response.error?.message}', false);
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour statut: $e');
      Toast(context, 'Erreur lors de la mise à jour', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerLat =
        deliveries.isNotEmpty && deliveries.first.livreurLat != null
            ? deliveries.first.livreurLat!
            : 48.8566;
    final centerLng =
        deliveries.isNotEmpty && deliveries.first.livreurLng != null
            ? deliveries.first.livreurLng!
            : 2.3522;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Carte
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLng),
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
                        .where((d) =>
                            d.deliveryStatus == 'in_transit' &&
                            d.livreurLat != null)
                        .map((d) => Marker(
                              point: LatLng(d.livreurLat!, d.livreurLng!),
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.brand
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.delivery_dining,
                                    color: Colors.white, size: 22),
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.successLight
                                : AppColors.errorLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_rounded,
                            color:
                                isOnline ? AppColors.success : AppColors.error,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isOnline ? 'En ligne' : 'Hors ligne',
                                    style: AppTypography.titleMedium()),
                                const SizedBox(height: 2),
                                Text(
                                    '${_totalDeliveries} livraisons · ${_totalEarnings.toStringAsFixed(0)} €',
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

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: deliveries.isEmpty ? 0.15 : 0.25,
              minChildSize: 0.1,
              maxChildSize: 0.75,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          Text('Mes livraisons',
                              style: AppTypography.titleMedium()),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brandSurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${deliveries.length}',
                                style: AppTypography.labelMedium(
                                    color: AppColors.brand)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : deliveries.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.delivery_dining_outlined,
                                            size: 48, color: AppColors.border),
                                        const SizedBox(height: 12),
                                        Text('Aucune livraison',
                                            style: AppTypography.bodyMedium()),
                                        const SizedBox(height: 4),
                                        Text('Les commandes apparaîtront ici',
                                            style: AppTypography.bodyMedium(
                                                color: AppColors.inkSubtle)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    itemCount: deliveries.length,
                                    itemBuilder: (_, i) =>
                                        _buildDeliveryCard(deliveries[i]),
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

  Widget _buildDeliveryCard(Commande commande) {
    final status = commande.deliveryStatus ?? 'assigned';

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Commande #${commande.commandeID}',
                style: AppTypography.labelMedium()),
          ),
          _StatusBadge(status: status),
        ]),
        const SizedBox(height: 8),
        Text(
            'Restaurant : ${restoNames[commande.restauID] ?? 'Resto #${commande.restauID}'}',
            style: AppTypography.bodyMedium()),
        Text('Livraison : ${commande.fraisLivraison.toStringAsFixed(2)} €',
            style: AppTypography.bodyMedium()),
        Text('Client : #${commande.userID}', style: AppTypography.bodyMedium()),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (status == 'assigned')
              _ActionBtn('Récupérer', Icons.shopping_bag_rounded,
                  AppColors.accent, () => _updateStatus(commande, 'picked_up')),
            if (status == 'picked_up')
              _ActionBtn('En route', Icons.directions_bike_rounded,
                  AppColors.brand, () => _updateStatus(commande, 'in_transit')),
            if (status == 'in_transit')
              _ActionBtn('Livré', Icons.check_rounded, AppColors.success,
                  () => _updateStatus(commande, 'delivered')),
          ],
        ),
      ]),
    );
  }

  Widget _ActionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
        ),
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
          'assigned': 'Assignée',
          'picked_up': 'Récupérée',
          'in_transit': 'En route',
          'delivered': 'Livrée',
        }[status] ??
        status;

    final color = {
          'assigned': AppColors.inkSubtle,
          'picked_up': AppColors.accent,
          'in_transit': AppColors.brand,
          'delivered': AppColors.success,
        }[status] ??
        AppColors.inkSubtle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}
