import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/commande_status.dart';
import '../modeles/commande.dart';
import '../modeles/ligne_commande.dart';
import '../services/commande_api.dart';
import '../services/session_service.dart';

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

    final filtered = widget.showRestaurantOrders
        ? allCommandes.where((c) => c.restaurateurID == session.userId).toList()
        : allCommandes.where((c) => c.userID == session.userId).toList();

    filtered.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
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
      body: isLoading
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
                        title: Text('Commande #${commande.commandeID}'),
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
                                      title: Text('Plat ID: ${ligne.platID}'),
                                      subtitle: Text(
                                        'Quantité: ${ligne.quantite} | Prix unitaire: ${ligne.prixUnitaire.toStringAsFixed(2)}',
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
