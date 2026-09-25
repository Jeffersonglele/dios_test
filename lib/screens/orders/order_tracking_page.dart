import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import '../../l10n/app_localizations.dart';
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
  String _country = 'RDC';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    _country = session.country;
    try {
      await Commande.refreshLocalCommandes();
    } catch (_) {
      // Le cache local reste utilisable si Parse est temporairement indisponible.
    }
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.order_tracking_title)),
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
            child:             Text(AppLocalizations.of(context)!.order_num(c.commandeID),
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
        // Parcours unique : préparation du restaurant puis livraison.
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              _Step(
                _trackingLabels[i],
                i <= _trackingStepIndex(c, status),
                status == CommandeStatus.cancelled ||
                    status == CommandeStatus.refused,
              ),
              if (i < 4)
                _StepConnector(
                    i < _trackingStepIndex(c, status) &&
                        status != CommandeStatus.cancelled &&
                        status != CommandeStatus.refused),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(AppLocalizations.of(context)!.delivery_cost(CurrencyUtil.formatPrice(c.fraisLivraison, _country)),
              style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
          Text(AppLocalizations.of(context)!.discount_amount(CurrencyUtil.formatPrice(c.reduction, _country)),
              style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
        ]),
      ]),
    );
  }

  String _statusMessage(String s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case CommandeStatus.pending: return l10n.tracking_pending_label;
      case CommandeStatus.paid: return l10n.tracking_paid_label;
      case CommandeStatus.confirmed: return l10n.tracking_confirmed_label;
      case CommandeStatus.preparing: return 'Le restaurant prépare votre commande.';
      case CommandeStatus.ready: return 'Votre commande est prête. Recherche d’un livreur en cours.';
      case CommandeStatus.delivered: return 'Commande livrée.';
      case CommandeStatus.refused: return 'Commande refusée par le restaurant.';
      case CommandeStatus.cancelled: return l10n.tracking_cancelled_label;
      default: return 'Statut mis à jour.';
    }
  }

  static const _trackingLabels = [
    'Créée',
    'Préparation',
    'Prête',
    'En livraison',
    'Livrée',
  ];

  int _trackingStepIndex(Commande commande, String status) {
    if (status == CommandeStatus.cancelled || status == CommandeStatus.refused) {
      return -1;
    }
    final delivery = commande.deliveryStatus == null
        ? null
        : DeliveryStatus.normalize(commande.deliveryStatus);
    if (status == CommandeStatus.delivered ||
        delivery == DeliveryStatus.delivered) {
      return 4;
    }
    if (delivery == DeliveryStatus.inTransit) return 3;
    if (delivery == DeliveryStatus.pickedUp) return 3;
    if (delivery == DeliveryStatus.assigned ||
        delivery == DeliveryStatus.atPickup ||
        delivery == DeliveryStatus.searching ||
        status == CommandeStatus.ready) {
      return 2;
    }
    if (status == CommandeStatus.preparing) return 1;
    return 0;
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
