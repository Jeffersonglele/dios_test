import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';

class OrderTrackingPage extends StatefulWidget {
  final String? highlightedCommandeId;
  const OrderTrackingPage({super.key, this.highlightedCommandeId});
  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool isLoading = true;
  List<Commande> commandes = [];
  Map<int, Restaurant> restaurantById = {};
  String _country = 'France';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    _country = session.country;
    final allC = await Commande.fetchCommandesFromDB();
    final restos = await Restaurant.fetchRestaurantsFromDB();
    final userC = allC.where((c) => c.userID == session.userId).toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
    if (!mounted) return;
    setState(() {
      commandes = userC;
      restaurantById = {for (final r in restos) r.restaurantID: r};
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Suivi de commande')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : commandes.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Text("Aucune commande à suivre.",
                        style: AppTypography.bodyMedium())),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: commandes.map(_buildCard).toList(),
                  ),
      ),
    );
  }

  Widget _buildCard(Commande c) {
    final resto = restaurantById[c.restauID];
    final status = CommandeStatus.normalize(c.status);
    final isHighlighted = widget.highlightedCommandeId == c.commandeID.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.brandSurface.withValues(alpha: 0.5) : AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isHighlighted ? AppColors.brand.withValues(alpha: 0.3) : AppColors.border,
          width: isHighlighted ? 1 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Commande #${c.commandeID}',
                style: AppTypography.titleMedium()),
          ),
          _StatusChip(status: status),
        ]),
        const SizedBox(height: 8),
        Text(resto?.name ?? 'Restaurant inconnu', style: AppTypography.bodyMedium()),
        Text('${c.dateCommande.toLocal().toString().split(" ")[0]} à ${c.heure}',
            style: AppTypography.bodyMedium(color: AppColors.inkSubtle).copyWith(fontSize: 12)),
        const SizedBox(height: 12),
        Text(_statusMessage(status), style: AppTypography.bodyMedium()),
        const SizedBox(height: 16),
        // Étapes
        Row(children: [
          _Step('Créée', status != CommandeStatus.cancelled, status == CommandeStatus.cancelled),
          _StepConnector(status != CommandeStatus.cancelled && (status == CommandeStatus.paid || status == CommandeStatus.confirmed)),
          _Step('Payée', status == CommandeStatus.paid || status == CommandeStatus.confirmed, status == CommandeStatus.cancelled),
          _StepConnector(status == CommandeStatus.confirmed),
          _Step('Confirmée', status == CommandeStatus.confirmed, status == CommandeStatus.cancelled),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Livraison ${CurrencyUtil.formatPrice(c.fraisLivraison, _country)}',
              style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
          Text('Réduction ${CurrencyUtil.formatPrice(c.reduction, _country)}',
              style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
        ]),
      ]),
    );
  }

  String _statusMessage(String s) {
    switch (s) {
      case CommandeStatus.pending: return 'Commande créée, en attente de confirmation.';
      case CommandeStatus.paid: return 'Paiement confirmé, le restaurant traite la commande.';
      case CommandeStatus.confirmed: return 'Commande confirmée, en préparation.';
      case CommandeStatus.cancelled: return 'Commande annulée.';
      default: return 'Statut mis à jour.';
    }
  }

  Widget _Step(String label, bool done, bool cancelled) {
    final color = cancelled ? AppColors.error : done ? AppColors.success : AppColors.inkSubtle;
    return Expanded(
      child: Column(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }

  Widget _StepConnector(bool active) => Expanded(
    child: Container(height: 2, color: active ? AppColors.success : AppColors.border),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = CommandeStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
