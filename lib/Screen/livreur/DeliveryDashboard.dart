import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../core/commande_status.dart';
import '../../modeles/commande.dart';
import '../../modeles/restaurant.dart';
import '../../services/session_service.dart';

class DeliveryDashboard extends StatefulWidget {
  const DeliveryDashboard({super.key});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  List<Map<String, dynamic>> deliveries = [];
  Map<int, String> restoNames = {};
  bool isLoading = true;
  int driverID = 0;
  int? activeCommandeID;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
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
        'userID': driverID,
        'commandeID': activeCommandeID,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    driverID = session.userId;

    final restos = await Restaurant.fetchRestaurantsFromDB();
    final rNames = <int, String>{};
    for (final r in restos) { rNames[r.restaurantID] = r.name; }

    try {
      final func = ParseCloudFunction('getMyDeliveries');
      final resp = await func.execute(parameters: {'userID': driverID});
      if (resp.success && resp.result != null) {
        if (mounted) setState(() {
          deliveries = List<Map<String, dynamic>>.from(resp.result as List);
          restoNames = rNames;
          isLoading = false;
        });
        return;
      }
    } catch (_) {}

    final allCmd = await Commande.fetchCommandesFromDB();
    final filtered = allCmd.where((c) => c.livreurID == driverID && c.deliveryStatus != 'delivered').toList();
    if (mounted) setState(() {
      deliveries = filtered.map((c) => {
        'commandeID': c.commandeID,
        'userID': c.userID,
        'restauID': c.restauID,
        'deliveryStatus': c.deliveryStatus ?? 'assigned',
        'fraisLivraison': c.fraisLivraison,
        'status': c.status,
        'dateCommande': c.dateCommande.toIso8601String(),
      }).toList();
      restoNames = rNames;
      isLoading = false;
    });
  }

  Future<void> _updateStatus(int commandeID, String newStatus) async {
    try {
      final func = ParseCloudFunction('updateDeliveryStatus');
      await func.execute(parameters: {
        'userID': driverID,
        'commandeID': commandeID,
        'deliveryStatus': newStatus,
      });
      if (newStatus == 'in_transit') {
        _startSharingLocation(commandeID);
      } else if (newStatus == 'delivered') {
        _stopSharingLocation();
      }
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mes livraisons'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: deliveries.isEmpty
                  ? const Center(
                      child: Text('Aucune livraison en cours.',
                          style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: deliveries.length,
                      itemBuilder: (ctx, i) {
                        final d = deliveries[i];
                        final status = d['deliveryStatus'] ?? 'assigned';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_shipping, color: Colors.teal),
                                    const SizedBox(width: 8),
                                    Text('Commande #${d['commandeID']}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    _StatusBadge(status: status.toString()),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Restaurant : ${restoNames[d['restauID']] ?? 'n°${d['restauID']}'}'),
                                Text('Frais livraison : ${(d['fraisLivraison'] ?? 0).toStringAsFixed(2)} €'),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (status == 'assigned')
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(d['commandeID'] as int, 'picked_up'),
                                        icon: const Icon(Icons.shopping_bag, size: 18),
                                        label: const Text('Récupéré'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                      ),
                                    if (status == 'picked_up')
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(d['commandeID'] as int, 'in_transit'),
                                        icon: const Icon(Icons.directions_bike, size: 18),
                                        label: const Text('En route'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                      ),
                                    if (status == 'in_transit')
                                      ElevatedButton.icon(
                                        onPressed: () => _updateStatus(d['commandeID'] as int, 'delivered'),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Livré'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
      'assigned': 'Assigné',
      'picked_up': 'Récupéré',
      'in_transit': 'En route',
      'delivered': 'Livré',
    }[status] ?? status;
    final color = {
      'assigned': Colors.grey,
      'picked_up': Colors.orange,
      'in_transit': Colors.blue,
      'delivered': Colors.green,
    }[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color as Color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
