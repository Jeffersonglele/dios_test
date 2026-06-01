import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/commande_status.dart';
import '../modeles/commande.dart';
import '../modeles/dish.dart';
import '../modeles/ligne_commande.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../services/commande_api.dart';
import '../services/session_service.dart';
import 'ChatScreen.dart';

class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({
    super.key,
    this.showRestaurantOrders = false,
  });

  final bool showRestaurantOrders;

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
  Subscription? commandeSubscription;

  @override
  void initState() {
    super.initState();
    loadOrders();
    listenToCommandes();
  }

  Future<void> listenToCommandes() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
    commandeSubscription = await liveQuery.client.subscribe(query);

    commandeSubscription!.on(LiveQueryEvent.create, (_) async {
      await Commande.refreshLocalCommandes();
      await loadOrders();
    });

    commandeSubscription!.on(LiveQueryEvent.update, (_) async {
      await Commande.refreshLocalCommandes();
      await loadOrders();
    });

    commandeSubscription!.on(LiveQueryEvent.delete, (_) async {
      await Commande.refreshLocalCommandes();
      await loadOrders();
    });
  }

  @override
  void dispose() {
    if (commandeSubscription != null) {
      liveQuery.client.unSubscribe(commandeSubscription!);
    }
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();
    final allCommandes = await Commande.fetchCommandesFromDB();
    final allDishes = await Dish.fetchDishesFromDB();
    final allRestos = await Restaurant.fetchRestaurantsFromDB();

    final dNames = <int, String>{};
    for (final d in allDishes) { dNames[d.dishID] = d.name ?? 'Plat ${d.dishID}'; }
    final rNames = <int, String>{};
    for (final r in allRestos) { rNames[r.restaurantID] = r.name; }

    var filtered = widget.showRestaurantOrders
        ? allCommandes.where((c) => c.restaurateurID == session.userId).toList()
        : allCommandes.where((c) => c.userID == session.userId).toList();

    if (statusFilter != null) {
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    }

    filtered.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
      dishNames = dNames;
      restoNames = rNames;
      commandes = filtered;
      isLoading = false;
    });
  }

  Future<List<LigneCommande>> getLignes(int commandeID) async {
    return LigneCommande.fetchLignesCommandeByCommandeID(commandeID);
  }

  Future<void> updateOrderStatus(int commandeId, String status) async {
    await CommandeApi.updateOrderStatus(commandeId.toString(), status);
    await Commande.refreshLocalCommandes();
    await loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.showRestaurantOrders ? 'Commandes reçues' : 'Mes commandes';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          _buildStatusFilters(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : commandes.isEmpty
                    ? Center(
                        child: Text(
                          widget.showRestaurantOrders
                              ? 'Aucune commande reçue.'
                              : 'Aucune commande trouvée.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: commandes.length,
                        itemBuilder: (context, index) {
                    final commande = commandes[index];
                    final status = CommandeStatus.normalize(commande.status);

                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: ExpansionTile(
                        title: Text(widget.showRestaurantOrders
                            ? 'Commande #${commande.commandeID}'
                            : restoNames[commande.restauID] ?? 'Commande #${commande.commandeID}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date : ${commande.dateCommande.toLocal().toString().split(" ")[0]}\nHeure : ${commande.heure}',
                            ),
                            const SizedBox(height: 6),
                            _StatusChip(status: status),
                            if (!widget.showRestaurantOrders &&
                                CommandeStatus.isPending(status))
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Commande en attente de confirmation par le restaurant.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        children: [
                          FutureBuilder<List<LigneCommande>>(
                            future: getLignes(commande.commandeID),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final lignes = snapshot.data!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...lignes.map(
                                    (ligne) => ListTile(
                                      title: Text(dishNames[ligne.platID] ?? 'Plat #${ligne.platID}'),
                                      subtitle: Text(
                                        'Qté: ${ligne.quantite} | ${ligne.prixUnitaire.toStringAsFixed(2)} €',
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Frais livraison: ${commande.fraisLivraison.toStringAsFixed(2)}',
                                        ),
                                        Text(
                                          'Réduction: ${commande.reduction.toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (!widget.showRestaurantOrders)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatScreen(
                                                  withUserID: commande.restaurateurID,
                                                  withUsername: 'Restaurateur',
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(Icons.chat, size: 18),
                                            label: const Text('Message'),
                                          ),
                                          if (status == CommandeStatus.confirmed)
                                            ElevatedButton.icon(
                                              onPressed: () => _showRateDialog(
                                                  context,
                                                  commande.commandeID,
                                                  commande.restauID,
                                                  lignes),
                                              icon: const Icon(Icons.star, color: Colors.amber),
                                              label: const Text('Noter'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.amber.shade50,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  if (widget.showRestaurantOrders)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 16,
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatScreen(
                                                  withUserID: commande.userID,
                                                  withUsername: 'Client #${commande.commandeID}',
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(Icons.chat, size: 18),
                                            label: const Text('Message'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: status ==
                                                    CommandeStatus.cancelled
                                                ? null
                                                : () => updateOrderStatus(
                                                      commande.commandeID,
                                                      CommandeStatus.cancelled,
                                                    ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Annuler'),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: status ==
                                                    CommandeStatus.confirmed
                                                ? null
                                                : () => updateOrderStatus(
                                                      commande.commandeID,
                                                      CommandeStatus.confirmed,
                                                    ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                            child: const Text('Confirmer'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
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

  Widget _buildStatusFilters() {
    final statuses = ['Tous', CommandeStatus.pending, CommandeStatus.confirmed, CommandeStatus.cancelled];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(s == 'Tous' ? 'Tous' : s == CommandeStatus.pending ? 'En attente' : s),
            selected: statusFilter == (s == 'Tous' ? null : s),
            onSelected: (_) {
              setState(() {
                statusFilter = s == 'Tous' ? null : s;
              });
              loadOrders();
            },
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _showRateDialog(
    BuildContext context,
    int commandeID,
    int restauID,
    List<LigneCommande> lignes,
  ) async {
    final commentCtrl = TextEditingController();
    int restoNote = 5;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Noter votre commande'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note pour le restaurant :', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => IconButton(
                    icon: Icon(
                      i < restoNote ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => restoNote = i + 1),
                  )),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final session = await SessionService.readSession();
                  final cloudFunction = ParseCloudFunction('addComment');
                  await cloudFunction.execute(parameters: {
                    'userID': session.userId,
                    'targetType': 1,
                    'targetID': restauID,
                    'note': restoNote,
                    'commentaire': commentCtrl.text,
                    'username': '',
                    'userImage': '',
                  });
                  for (final ligne in lignes) {
                    await cloudFunction.execute(parameters: {
                      'userID': session.userId,
                      'targetType': 2,
                      'targetID': ligne.platID,
                      'note': restoNote,
                      'commentaire': '',
                      'username': '',
                      'userImage': '',
                    });
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Merci pour votre avis !')),
                    );
                  }
                } catch (_) {}
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: CommandeStatus.color(status),
    );
  }
}
