import 'package:dios_delices/Screen/restaurants/RestaurantListPage.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/DateTime.dart';
import '../CountryPage.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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

  // Sparkline data (simulé)
  List<double> _recentOrdersDaily = [12, 18, 15, 22, 19, 25, 30];

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
                    .toList() ?? [];
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
      _pendingOrders = commandes.where((c) => CommandeStatus.isPending(c.status)).length;
      _statsLoading = false;
    });
  }

  Future<void> _loadUserRole() async {
    final session = await SessionService.readSession();
    setState(() { _userRole = session.role; _userCountry = session.country; });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: RefreshIndicator(
            color: AppColors.brand,
            backgroundColor: AppColors.card,
            onRefresh: _loadStats,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  title: Text('Dashboard Admin', style: AppTypography.titleLarge().copyWith(fontSize: 20)),
                  actions: [
                    // Filtre pays
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.language_rounded),
                      tooltip: 'Filtrer par pays',
                      onSelected: (v) => setState(() => _userCountry = v),
                      itemBuilder: (_) => ['France', 'Bénin', 'Côte d\'Ivoire']
                          .map((c) => PopupMenuItem(value: c, child: Text(c)))
                          .toList(),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: const SizedBox(height: 8)),
                if (!_statsLoading) ...[
                  SliverToBoxAdapter(child: _buildCountryChip()),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                  SliverToBoxAdapter(child: _buildKpiGrid()),
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildSparklineSection()),
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),
                ] else
                  const SliverToBoxAdapter(child: SizedBox(
                    height: 200, child: Center(child: CircularProgressIndicator()))),
                SliverToBoxAdapter(child: _buildSection('Utilisateurs', Icons.people_rounded, '$_totalUsers',
                    subtitle: _newUsersThisMonth > 0 ? '+$_newUsersThisMonth ce mois' : null, onTap: () {
                  Navigator.push(context, CupertinoPageRoute(
                      builder: (_) => CountryPage(sectionType: "utilisateurs")));
                }, onAdd: _userRole == AppRole.superAdmin ? () => _showAddUserDialog(roleID: 1) : null)),
                SliverToBoxAdapter(child: _buildSection('Restaurants', Icons.storefront_rounded, '$_totalRestaurants', onTap: () {
                  if (_userRole == AppRole.superAdmin) {
                    Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => CountryPage(sectionType: "restaurants")));
                  } else {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RestaurantListPage(country: _userCountry)));
                  }
                })),
                if (_userRole == AppRole.superAdmin)
                  SliverToBoxAdapter(child: _buildSection('Administrateurs', Icons.admin_panel_settings_rounded, '—', onTap: () {
                    Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => CountryPage(sectionType: "administrateurs")));
                  }, onAdd: () => _showAddUserDialog(roleID: 1))),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brandSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 16),
          const SizedBox(width: 8),
          Text(_userCountry, style: AppTypography.labelMedium(color: AppColors.brand)),
        ]),
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _KpiCard('Chiffre d\'affaires', '${_totalRevenue.toStringAsFixed(0)} €',
              Icons.euro_rounded, AppColors.success, trendUp: true, trendValue: '+12%'),
          _KpiCard('Commandes totales', '$_totalOrders',
              Icons.receipt_long_rounded, AppColors.accent, trendUp: true, trendValue: '+8%'),
          _KpiCard('En attente', '$_pendingOrders',
              Icons.pending_actions_rounded, AppColors.error, trendUp: false),
          _KpiCard('Confirmées', '$_confirmedOrders',
              Icons.verified_rounded, AppColors.success, subtitle: '$_cancelledOrders annulées'),
        ],
      ),
    );
  }

  Widget _buildSparklineSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Commandes cette semaine', style: AppTypography.titleMedium()),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(99)),
              child: const Text('+15%', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _SparklinePainter(data: _recentOrdersDaily, color: AppColors.brand),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
                .map((d) => Text(d, style: AppTypography.bodyMedium().copyWith(fontSize: 11)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, String count,
      {String? subtitle, VoidCallback? onTap, VoidCallback? onAdd}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                color: AppColors.brandSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.brand, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTypography.labelMedium()),
                if (subtitle != null)
                  Text(subtitle, style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              ]),
            ),
            Text(count, style: AppTypography.headlineMedium().copyWith(fontSize: 22)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
          ]),
        ),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 8),
            TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () async {
            if (usernameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
            final result = await Users.manageUser(
              roleID: roleID, telephone: '', password: passwordCtrl.text, password_crypte: passwordCtrl.text,
              firstname: '', lastname: '', email: emailCtrl.text, username: usernameCtrl.text,
              status: 'Verified', identity: 'Verified', addressID: 0, country: _userCountry,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.toString())));
              if (result == 'success') { Navigator.pop(ctx); _loadStats(); }
            }
          }, child: const Text('Créer')),
        ],
      ),
    );
  }
}

// ── KPI Card ────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon, this.color, {this.trendUp, this.trendValue, this.subtitle});
  final String title, value;
  final IconData icon;
  final Color color;
  final bool? trendUp;
  final String? trendValue;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          if (trendValue != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(trendUp == true ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendUp == true ? AppColors.success : AppColors.error, size: 14),
              const SizedBox(width: 2),
              Text(trendValue!, style: TextStyle(
                  color: trendUp == true ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
        ]),
        const Spacer(),
        Text(value, style: AppTypography.headlineMedium().copyWith(fontSize: 26)),
        const SizedBox(height: 2),
        Text(title, style: AppTypography.labelMedium(color: AppColors.inkMuted).copyWith(fontSize: 11)),
        if (subtitle != null)
          Text(subtitle!, style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
      ]),
    );
  }
}

// ── Sparkline Painter ───────────────────────────────────
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = 0.0;
    final dx = size.width / (data.length - 1);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - ((data[i] - minVal) / (maxVal - minVal)) * (size.height - 10);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
