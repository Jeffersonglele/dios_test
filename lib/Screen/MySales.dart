import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/ligne_commande.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

class MySales extends StatefulWidget {
  const MySales({super.key});
  @override
  State<MySales> createState() => _MySalesState();
}

class _MySalesState extends State<MySales> {
  List<Commande> _commandes = [];
  Map<int, String> _dishNames = {};
  bool _isLoading = true;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final allCmd = await Commande.fetchCommandesFromDB();
    final allDishes = await Dish.fetchDishesFromDB();
    final myCmd = allCmd.where((c) => c.restaurateurID == session.userId).toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    final names = <int, String>{};
    for (final d in allDishes) { names[d.dishID] = d.name ?? 'Plat ${d.dishID}'; }

    final total = myCmd.fold<double>(0, (s, c) => s + c.fraisLivraison);

    if (mounted) setState(() { _commandes = myCmd; _dishNames = names; _totalRevenue = total; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Mes ventes')),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _commandes.isEmpty
                ? Center(child: Text('Aucune vente.', style: AppTypography.bodyMedium()))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: _commandes.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.brandDark, AppColors.brand],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Column(children: [
                            const Text('Chiffre d\'affaires', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('${_totalRevenue.toStringAsFixed(2)} €',
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          ]),
                        );
                      }
                      final c = _commandes[i - 1];
                      final status = CommandeStatus.normalize(c.status);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: ListTile(
                          title: Text('Commande #${c.commandeID}', style: AppTypography.labelMedium()),
                          subtitle: Text('Frais livraison: ${c.fraisLivraison.toStringAsFixed(2)} € · ${c.dateCommande.toLocal().toString().split(" ")[0]}',
                              style: AppTypography.bodyMedium()),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CommandeStatus.color(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(status, style: TextStyle(color: CommandeStatus.color(status), fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
