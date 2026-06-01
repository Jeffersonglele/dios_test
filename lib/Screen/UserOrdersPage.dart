import 'dart:convert';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/ligne_commande.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'ChatScreen.dart';

class UserOrdersPage extends StatefulWidget {
  final bool showRestaurantOrders;
  const UserOrdersPage({super.key, this.showRestaurantOrders = false});
  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  List<Commande> commandes = [];
  bool isLoading = true;
  Map<int, String> dishNames = {};
  Map<int, String> restoNames = {};
  String? statusFilter;
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
    sub!.on(LiveQueryEvent.create, (_) async { await Commande.refreshLocalCommandes(); await loadOrders(); });
    sub!.on(LiveQueryEvent.update, (_) async { await Commande.refreshLocalCommandes(); await loadOrders(); });
    sub!.on(LiveQueryEvent.delete, (_) async { await Commande.refreshLocalCommandes(); await loadOrders(); });
  }

  @override
  void dispose() {
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();
    final allC = await Commande.fetchCommandesFromDB();
    final allD = await Dish.fetchDishesFromDB();
    final allR = await Restaurant.fetchRestaurantsFromDB();

    final dn = <int, String>{};
    for (final d in allD) { dn[d.dishID] = d.name ?? 'Plat ${d.dishID}'; }
    final rn = <int, String>{};
    for (final r in allR) { rn[r.restaurantID] = r.name; }

    var filtered = widget.showRestaurantOrders
        ? allC.where((c) => c.restaurateurID == session.userId).toList()
        : allC.where((c) => c.userID == session.userId).toList();
    if (statusFilter != null) filtered = filtered.where((c) => c.status == statusFilter).toList();
    filtered.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() { dishNames = dn; restoNames = rn; commandes = filtered; isLoading = false; });
  }

  Future<List<LigneCommande>> getLignes(int id) => LigneCommande.fetchLignesCommandeByCommandeID(id);

  Future<void> updateStatus(int id, String s) async {
    await CommandeApi.updateOrderStatus(id.toString(), s);
    await Commande.refreshLocalCommandes();
    await loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.showRestaurantOrders ? 'Commandes reçues' : 'Mes commandes')),
      body: Column(children: [
        _buildFilters(),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : commandes.isEmpty
                  ? Center(child: Text(widget.showRestaurantOrders ? 'Aucune commande.' : 'Aucune commande trouvée.',
                      style: AppTypography.bodyMedium()))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      itemCount: commandes.length,
                      itemBuilder: (_, i) => _buildCard(commandes[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _buildFilters() {
    final statuses = ['Tous', CommandeStatus.pending, CommandeStatus.confirmed, CommandeStatus.cancelled];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) {
          final active = statusFilter == (s == 'Tous' ? null : s);
          final label = s == 'Tous' ? 'Tous' : s == CommandeStatus.pending ? 'En attente' : s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter = s == 'Tous' ? null : s);
                loadOrders();
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: active ? AppColors.brand : AppColors.border, width: 0.5),
                ),
                child: Text(label, style: AppTypography.labelMedium(color: active ? Colors.white : AppColors.inkMuted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(Commande c) {
    final status = CommandeStatus.normalize(c.status);
    final statusColor = CommandeStatus.color(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(widget.showRestaurantOrders
            ? 'Commande #${c.commandeID}'
            : restoNames[c.restauID] ?? 'Commande #${c.commandeID}',
            style: AppTypography.labelMedium()),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c.dateCommande.toLocal().toString().split(" ")[0]} · ${c.heure}',
              style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          if (!widget.showRestaurantOrders && c.deliveryStatus != null && c.deliveryStatus!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _DeliveryTracker(status: c.deliveryStatus!, lat: c.livreurLat, lng: c.livreurLng),
            ),
        ]),
        children: [
          FutureBuilder<List<LigneCommande>>(
            future: getLignes(c.commandeID),
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
              final lignes = snap.data!;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ...lignes.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(dishNames[l.platID] ?? 'Plat #${l.platID}', style: AppTypography.bodyMedium())),
                    Text('x${l.quantite}', style: AppTypography.labelMedium()),
                    const SizedBox(width: 12),
                    Text('${l.prixUnitaire.toStringAsFixed(2)} €', style: AppTypography.bodyMedium(color: AppColors.brand)),
                  ]),
                )),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Livraison: ${c.fraisLivraison.toStringAsFixed(2)} €', style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                  Text('Réduction: ${c.reduction.toStringAsFixed(2)} €', style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                ]),
                const SizedBox(height: 12),
                if (!widget.showRestaurantOrders)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(withUserID: c.restaurateurID, withUsername: 'Restaurateur'))),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    if (status == CommandeStatus.confirmed)
                      ElevatedButton.icon(
                        onPressed: () => _showRate(c.commandeID, c.restauID, lignes),
                        icon: const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                        label: const Text('Noter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentLight, foregroundColor: AppColors.accent,
                          minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ]),
                if (widget.showRestaurantOrders)
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(withUserID: c.userID, withUsername: 'Client #${c.commandeID}'))),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: status == CommandeStatus.cancelled ? null : () => updateStatus(c.commandeID, CommandeStatus.cancelled),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error, foregroundColor: Colors.white,
                        minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: status == CommandeStatus.confirmed ? null : () => updateStatus(c.commandeID, CommandeStatus.confirmed),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, foregroundColor: Colors.white,
                        minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Confirmer', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => _showAssignLivreur(c.commandeID),
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Livreur'),
                      style: OutlinedButton.styleFrom(minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                  ]),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignLivreur(int id) async {
    final users = await Users.fetchUsersFromDB();
    final livreurs = users.where((u) => u.roleID == 5).toList();
    if (!mounted) return;
    if (livreurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun livreur.')));
      return;
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Assigner un livreur'),
      content: SizedBox(width: double.maxFinite,
        child: ListView.builder(shrinkWrap: true, itemCount: livreurs.length, itemBuilder: (_, i) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('${livreurs[i].firstname} ${livreurs[i].lastname}'),
          onTap: () async {
            Navigator.pop(ctx);
            await ParseCloudFunction('assignLivreur').execute(parameters: {
              'userID': (await SessionService.readSession()).userId,
              'commandeID': id, 'livreurID': livreurs[i].userID,
            });
            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livreur assigné.'))); loadOrders(); }
          },
        )),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))],
    ));
  }

  Future<void> _showRate(int cmdId, int restauId, List<LigneCommande> lignes) async {
    final ctrl = TextEditingController();
    int note = 5;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Noter'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(i < note ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent, size: 36),
              onPressed: () => setD(() => note = i + 1)))),
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Commentaire'), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
        ElevatedButton(onPressed: () async {
          final session = await SessionService.readSession();
          final f = ParseCloudFunction('addComment');
          await f.execute(parameters: {'userID': session.userId, 'targetType': 1, 'targetID': restauId,
            'note': note, 'commentaire': ctrl.text, 'username': '', 'userImage': ''});
          Navigator.pop(ctx);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci !')));
        }, child: const Text('Envoyer')),
      ],
    )));
  }
}

class _DeliveryTracker extends StatelessWidget {
  final String status;
  final double? lat, lng;
  const _DeliveryTracker({required this.status, this.lat, this.lng});

  @override
  Widget build(BuildContext context) {
    final steps = ['assigned', 'picked_up', 'in_transit', 'delivered'];
    final labels = ['Prépa.', 'Récupéré', 'En route', 'Livré'];
    final icons = [Icons.restaurant_rounded, Icons.shopping_bag_rounded, Icons.directions_bike_rounded, Icons.check_rounded];
    final idx = steps.indexOf(status);
    final hasMap = status == 'in_transit' && lat != null && lng != null;

    return Column(children: [
      Row(
        children: List.generate(4, (i) {
          final done = i <= idx;
          return Expanded(child: Column(children: [
            Container(width: 24, height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: done ? AppColors.brand : AppColors.border),
              child: Icon(icons[i], size: 13, color: done ? Colors.white : AppColors.inkSubtle)),
            Text(labels[i], style: TextStyle(fontSize: 9, color: done ? AppColors.brand : AppColors.inkSubtle, fontWeight: FontWeight.w600)),
          ]));
        }),
      ),
      if (hasMap)
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => DeliveryMapPage(livreurLat: lat!, livreurLng: lng!))),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            height: 160,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.brand.withValues(alpha: 0.3))),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(options: MapOptions(initialCenter: LatLng(lat!, lng!), initialZoom: 14,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.diosdelices.app'),
                  MarkerLayer(markers: [Marker(point: LatLng(lat!, lng!), width: 40, height: 40,
                      child: const Icon(Icons.delivery_dining, color: AppColors.brand, size: 28))]),
                ],
              ),
              Positioned(bottom: 4, right: 8,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Toucher pour agrandir', style: TextStyle(color: Colors.white, fontSize: 10)))),
            ]),
          ),
        ),
    ]);
  }
}

class DeliveryMapPage extends StatefulWidget {
  final double livreurLat, livreurLng;
  final double? clientLat, clientLng;
  const DeliveryMapPage({super.key, required this.livreurLat, required this.livreurLng, this.clientLat, this.clientLng});
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
      final url = 'https://router.project-osrm.org/route/v1/driving/${widget.livreurLng},${widget.livreurLat};${widget.clientLng},${widget.clientLat}?overview=full&geometries=geojson';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final coords = (jsonDecode(resp.body)['routes']?[0]?['geometry']?['coordinates'] as List?) ?? [];
        if (mounted) setState(() { _route = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList(); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _route.isNotEmpty ? LatLngBounds.fromPoints(_route) : null;
    final center = bounds?.center ?? LatLng(widget.livreurLat, widget.livreurLng);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Suivi livraison')),
      body: Stack(children: [
        FlutterMap(options: MapOptions(initialCenter: center, initialZoom: 14,
            initialCameraFit: bounds != null ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)) : null),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.diosdelices.app'),
            if (_route.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _route, color: AppColors.brand, strokeWidth: 4)]),
            MarkerLayer(markers: [
              Marker(point: LatLng(widget.livreurLat, widget.livreurLng), width: 50, height: 50,
                  child: Column(children: const [Icon(Icons.delivery_dining, color: AppColors.brand, size: 32),
                      Text('Livreur', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))])),
              if (widget.clientLat != null)
                Marker(point: LatLng(widget.clientLat!, widget.clientLng!), width: 50, height: 50,
                    child: Column(children: const [Icon(Icons.home_rounded, color: AppColors.accent, size: 32),
                        Text('Client', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))])),
            ]),
          ],
        ),
        if (_loading) const Positioned(top: 16, left: 0, right: 0, child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
