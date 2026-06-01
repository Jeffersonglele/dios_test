import 'package:dios_delices/Screen/restaurants/RestaurantListPage.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../services/session_service.dart';
import '../../utils/DateTime.dart';
import '../CountryPage.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  AppRole _userRole = AppRole.unknown;
  String _userCountry = "France";

  int _totalUsers = 0;
  int _totalRestaurants = 0;
  int _pendingOrders = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  int _confirmedOrders = 0;
  int _cancelledOrders = 0;
  int _newUsersThisMonth = 0;
  List<Map<String, dynamic>> _topDishes = [];
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final cloudFunction = ParseCloudFunction('getDashboardStats');
      final response = await cloudFunction.execute();
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;
          if (!mounted) return;
          setState(() {
            _totalUsers = (stats['totalUsers'] as num?)?.toInt() ?? 0;
            _totalRestaurants = (stats['totalRestaurants'] as num?)?.toInt() ?? 0;
            _totalOrders = (stats['totalOrders'] as num?)?.toInt() ?? 0;
            _totalRevenue = (stats['totalRevenue'] as num?)?.toDouble() ?? 0;
            _pendingOrders = (stats['pendingCount'] as num?)?.toInt() ?? 0;
            _confirmedOrders = (stats['confirmedCount'] as num?)?.toInt() ?? 0;
            _cancelledOrders = (stats['cancelledCount'] as num?)?.toInt() ?? 0;
            _newUsersThisMonth = (stats['newUsersThisMonth'] as num?)?.toInt() ?? 0;
            _topDishes = (stats['topDishes'] as List<dynamic>?)
                    ?.map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                [];
            _statsLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    final users = await Users.fetchUsersFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final commandes = await Commande.fetchCommandesFromDB();

    if (!mounted) return;
    setState(() {
      _totalUsers = users.length;
      _totalRestaurants = restaurants.length;
      _totalOrders = commandes.length;
      _pendingOrders = commandes
          .where((c) => CommandeStatus.isPending(c.status))
          .length;
      _statsLoading = false;
    });
  }

  // Fonction pour charger le rôle de l'utilisateur
  Future<void> _loadUserRole() async {
    final session = await SessionService.readSession();
    setState(() {
      _userRole = session.role;
      _userCountry = session.country;
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildLargeScreen(size, simpleUIController, theme);
                } else {
                  return _buildSmallScreen(size, simpleUIController, theme);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // Pour les grands écrans
  Widget _buildLargeScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(size, simpleUIController, theme),
        ),
      ],
    );
  }

  // Pour les petits écrans
  Widget _buildSmallScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, simpleUIController, theme),
    );
  }

  // Contenu principal du tableau de bord
  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
        size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          SizedBox(height: size.height * 0.02),
          // Date et heure actuelles
          DateTimeDisplay(),
          SizedBox(height: size.height * 0.03),

          // Statistiques
          if (!_statsLoading) ...[
            _buildStatsGrid(size),
            SizedBox(height: size.height * 0.03),
          ],

          // Section Utilisateurs
          _buildSection(
            size: size,
            sectionTitle: "Utilisateurs",
            onTap: () {
              // Redirige vers la page des pays pour les utilisateurs
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => CountryPage(sectionType: "utilisateurs"),
                ),
              );
            },
            onAddTap: () {
              _showAddUserDialog(roleID: 1);
            },
          ),
          SizedBox(height: size.height * 0.03),

          // Section Restaurants
          _buildSection(
            size: size,
            sectionTitle: "Restaurants",
            onTap: () {
              // Redirige vers la page des pays pour les restaurants
              // un super admin peut voir les restaus de tous les pays
              if (_userRole == AppRole.superAdmin) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => CountryPage(sectionType: "restaurants"),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantListPage(country: _userCountry),
                  ),
                );
              }
            },
            onAddTap: () {
              // Logique pour ajouter un restaurant
            },
          ),
          SizedBox(height: size.height * 0.03),

          // Section Administrateurs (si roleID == 4)
          if (_userRole == AppRole.superAdmin) ...[
            _buildSection(
              size: size,
              sectionTitle: "Administrateurs",
              onTap: () {
                // Redirige vers la page des administrateurs
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) =>
                        CountryPage(sectionType: "administrateurs"),
                  ),
                );
              },
              onAddTap: () {
                _showAddUserDialog(roleID: 1);
              },
            ),
          ],
        ]);
  }

  Widget _buildStatsGrid(Size size) {
    return GridView.count(
      crossAxisCount: size.width > 600 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: size.width > 600 ? 2.0 : 1.8,
      children: [
        _AdminStatCard(
          title: 'Utilisateurs',
          value: '$_totalUsers',
          subtitle: _newUsersThisMonth > 0 ? '+$_newUsersThisMonth ce mois' : null,
          icon: Icons.people,
          color: Colors.blue,
        ),
        _AdminStatCard(
          title: 'Restaurants',
          value: '$_totalRestaurants',
          icon: Icons.storefront,
          color: Colors.red,
        ),
        _AdminStatCard(
          title: 'Chiffre d\'affaires',
          value: '${_totalRevenue.toStringAsFixed(0)} €',
          icon: Icons.euro,
          color: Colors.purple,
        ),
        _AdminStatCard(
          title: 'Commandes',
          value: '$_totalOrders',
          subtitle: '${_confirmedOrders} confirmées',
          icon: Icons.receipt,
          color: Colors.green,
        ),
        _AdminStatCard(
          title: 'En attente',
          value: '$_pendingOrders',
          icon: Icons.pending,
          color: Colors.orange,
        ),
        _AdminStatCard(
          title: 'Annulées',
          value: '$_cancelledOrders',
          icon: Icons.cancel,
          color: Colors.grey,
        ),
        if (_topDishes.isNotEmpty) ...[
          _AdminStatCard(
            title: 'Plat n°1',
            value: '${_topDishes[0]['name'] ?? '—'}',
            subtitle: '${_topDishes[0]['totalSold']} vendus',
            icon: Icons.star,
            color: Colors.amber,
          ),
        ],
      ],
    );
  }

  // Méthode pour créer une section dans le dashboard
  Widget _buildSection({
    required Size size,
    required String sectionTitle,
    required VoidCallback onTap,
    required VoidCallback onAddTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 3,
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAddTap,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.green,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUserDialog({int roleID = 1}) async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(roleID == 1 ? 'Ajouter un administrateur' : 'Ajouter un utilisateur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (usernameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
              final result = await Users.manageUser(
                roleID: roleID,
                telephone: '',
                password: passwordCtrl.text,
                password_crypte: passwordCtrl.text,
                firstname: '',
                lastname: '',
                email: emailCtrl.text,
                username: usernameCtrl.text,
                status: 'Verified',
                identity: 'Verified',
                addressID: 0,
                country: _userCountry,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.toString())),
                );
                if (result == 'success') {
                  Navigator.pop(ctx);
                  _loadStats();
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _AdminStatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
