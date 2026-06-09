import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../admin/admin_dashboard.dart';

class Administration extends StatefulWidget {
  const Administration({super.key});
  @override
  State<Administration> createState() => _AdministrationState();
}

class _AdministrationState extends State<Administration> {
  int _totalUsers = 0, _totalRestaurants = 0, _totalDishes = 0, _totalOrders = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await Users.fetchUsersFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final dishes = await Dish.fetchDishesFromDB();
    final commandes = await Commande.fetchCommandesFromDB();
    if (mounted) setState(() {
      _totalUsers = users.length;
      _totalRestaurants = restaurants.where((r) => r.valid == 1).length;
      _totalDishes = dishes.length;
      _totalOrders = commandes.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l10n.admin_dashboard_title),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatRow(l10n.users, '$_totalUsers', Icons.people_rounded, Colors.blue),
                  _StatRow(l10n.restaurants, '$_totalRestaurants', Icons.storefront_rounded, AppColors.accent),
                  _StatRow(l10n.dishes, '$_totalDishes', Icons.restaurant_menu_rounded, AppColors.success),
                  _StatRow(l10n.orders, '$_totalOrders', Icons.receipt_long_rounded, AppColors.inkMuted),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminDashboard())),
                      icon: const Icon(Icons.dashboard_rounded),
                      label: Text(l10n.dashboard),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _StatRow(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: AppTypography.labelMedium())),
        Text(value, style: AppTypography.headlineMedium().copyWith(fontSize: 24, color: color)),
      ]),
    );
  }
}
