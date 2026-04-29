import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:flutter/material.dart';

class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({
    super.key,
    this.highlightedCommandeId,
  });

  final String? highlightedCommandeId;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool isLoading = true;
  List<Commande> commandes = [];
  Map<int, Restaurant> restaurantById = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final session = await SessionService.readSession();
    final allCommandes = await Commande.fetchCommandesFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();

    final userCommandes = allCommandes
        .where((commande) => commande.userID == session.userId)
        .toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
      commandes = userCommandes;
      restaurantById = {
        for (final restaurant in restaurants) restaurant.restaurantID: restaurant,
      };
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de commande')),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : commandes.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          "Aucune commande à suivre pour l'instant.",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: commandes.map(_buildOrderCard).toList(),
                  ),
      ),
    );
  }

  Widget _buildOrderCard(Commande commande) {
    final restaurant = restaurantById[commande.restauID];
    final status = CommandeStatus.normalize(commande.status);
    final highlighted =
        widget.highlightedCommandeId == commande.commandeID.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: highlighted ? const Color(0xFFFFF4EC) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Commande #${commande.commandeID}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: CommandeStatus.color(status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(restaurant?.name ?? 'Restaurant inconnu'),
            Text(
              '${commande.dateCommande.toLocal().toString().split(" ")[0]} à ${commande.heure}',
            ),
            const SizedBox(height: 8),
            Text(_statusMessage(status)),
            const SizedBox(height: 12),
            _TrackingStepRow(status: status),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Livraison ${commande.fraisLivraison.toStringAsFixed(2)}',
                ),
                Text(
                  'Réduction ${commande.reduction.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusMessage(String status) {
    switch (status) {
      case CommandeStatus.pending:
        return 'Votre commande a bien été créée et attend la confirmation du restaurant.';
      case CommandeStatus.paid:
        return 'Votre paiement est confirmé. Le restaurant va traiter la commande.';
      case CommandeStatus.confirmed:
        return 'Le restaurant a confirmé la commande. Elle est en préparation ou en cours de retrait.';
      case CommandeStatus.cancelled:
        return 'Cette commande a été annulée. Si besoin, contactez le restaurant ou le support.';
      default:
        return 'Le statut de votre commande a été mis à jour.';
    }
  }
}

class _TrackingStepRow extends StatelessWidget {
  const _TrackingStepRow({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPendingComplete = true;
    final isPaidComplete = status == CommandeStatus.paid ||
        status == CommandeStatus.confirmed;
    final isConfirmedComplete = status == CommandeStatus.confirmed;
    final isCancelled = status == CommandeStatus.cancelled;

    return Row(
      children: [
        Expanded(
          child: _TrackingStep(
            label: 'Créée',
            completed: isPendingComplete,
            cancelled: isCancelled,
          ),
        ),
        Expanded(
          child: _TrackingStep(
            label: 'Payée',
            completed: isPaidComplete,
            cancelled: isCancelled,
          ),
        ),
        Expanded(
          child: _TrackingStep(
            label: 'Confirmée',
            completed: isConfirmedComplete,
            cancelled: isCancelled,
          ),
        ),
      ],
    );
  }
}

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({
    required this.label,
    required this.completed,
    required this.cancelled,
  });

  final String label;
  final bool completed;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final color = cancelled
        ? Colors.red
        : completed
            ? Colors.green
            : Colors.grey;

    return Column(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
