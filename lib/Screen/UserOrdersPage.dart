import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modeles/commande.dart';
import '../modeles/ligne_commande.dart';

class UserOrdersPage extends StatefulWidget {
  @override
  _UserOrdersPageState createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  List<Commande> userCommandes = [];
  int? currentUserId;
  bool isLoading = true;
  LiveQuery liveQuery = LiveQuery();
  Subscription? commandeSubscription;

  @override
  void initState() {
    super.initState();
    loadUserOrders();
    listenToCommandes();
    loadUserOrders();
  }

  void listenToCommandes() async {
    final QueryBuilder<ParseObject> query = QueryBuilder<ParseObject>(ParseObject('Commande'));
    commandeSubscription = await liveQuery.client.subscribe(query);

    commandeSubscription!.on(LiveQueryEvent.create, (value) {
      print('Nouvelle commande: $value');
      loadUserOrders(); // recharge la liste
    });

    commandeSubscription!.on(LiveQueryEvent.update, (value) {
      print('Commande modifiée: $value');
      loadUserOrders();
    });

    commandeSubscription!.on(LiveQueryEvent.delete, (value) {
      print('Commande supprimée: $value');
      loadUserOrders();
    });
  }

  @override
  @override
  void dispose() {
    if (commandeSubscription != null) {
      liveQuery.client.unSubscribe(commandeSubscription!);
    }
    super.dispose();
  }

  Future<void> loadUserOrders() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt('loggedUserID');
    List<Commande> allCommandes = await Commande.fetchCommandesFromDB();
    setState(() {
      userCommandes = allCommandes.where((c) => c.userID == currentUserId).toList();
      isLoading = false;
    });
  }

  Future<List<LigneCommande>> getLignes(int commandeID) async {
    return await LigneCommande.fetchLignesCommandeByCommandeID(commandeID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mes Commandes')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : userCommandes.isEmpty
          ? Center(child: Text('Aucune commande trouvée.'))
          : ListView.builder(
        itemCount: userCommandes.length,
        itemBuilder: (context, index) {
          final commande = userCommandes[index];
          return Card(
            margin: EdgeInsets.all(12),
            child: ExpansionTile(
              title: Text('Commande #${commande.commandeID}'),
              subtitle: Text('Date : ${commande.dateCommande.toLocal().toString().split(" ")[0]}\nHeure : ${commande.heure}'),
              children: [
                FutureBuilder<List<LigneCommande>>(
                  future: getLignes(commande.commandeID),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final lignes = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...lignes.map((ligne) => ListTile(
                          title: Text('Plat ID: ${ligne.platID}'),
                          subtitle: Text('Quantité: ${ligne.quantite}  |  Prix unitaire: ${ligne.prixUnitaire.toStringAsFixed(2)}'),
                        )),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Frais livraison: ${commande.fraisLivraison.toStringAsFixed(2)}'),
                            Text('Réduction: ${commande.reduction.toStringAsFixed(2)}'),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Annuler la commande (cloud function à appeler)
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Annulation à implémenter')));
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text('Annuler'),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Confirmer la commande (cloud function à appeler)
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirmation à implémenter')));
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: Text('Confirmer'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
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