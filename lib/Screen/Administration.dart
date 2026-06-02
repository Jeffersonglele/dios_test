import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'admin/AdminDashboard.dart';

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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Administration'),
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
                  _StatRow('Utilisateurs', '$_totalUsers', Icons.people_rounded, Colors.blue),
                  _StatRow('Restaurants', '$_totalRestaurants', Icons.storefront_rounded, AppColors.accent),
                  _StatRow('Plats', '$_totalDishes', Icons.restaurant_menu_rounded, AppColors.success),
                  _StatRow('Commandes', '$_totalOrders', Icons.receipt_long_rounded, AppColors.inkMuted),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminDashboard())),
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text('Dashboard Admin'),
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
