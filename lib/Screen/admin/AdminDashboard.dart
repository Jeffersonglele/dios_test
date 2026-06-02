import 'package:dios_delices/Screen/livreur/LivreurListPage.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantListPage.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/DateTime.dart';
import '../CountryPage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  AppRole _userRole = AppRole.unknown;
  String _userCountry = "France";

  int _totalUsers = 0, _totalRestaurants = 0, _totalOrders = 0;
  double _totalRevenue = 0;
  int _pendingUsers = 0, _pendingRestaurants = 0, _pendingOrders = 0;
  int _confirmedOrders = 0, _cancelledOrders = 0, _newUsersThisMonth = 0;
  int _totalLivreurs = 0;
  double _revenuePercent = 0;
  bool _statsLoading = true;
  String _userName = '';

  List<Commande> _recentOrders = [];
  List<Map<String, dynamic>> _topDishes = [];

  List<double> _recentOrdersDaily = [12, 18, 15, 22, 19, 25, 30];

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadUserRole();
    _loadStats();
    dataVersionNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _glowController.dispose();
    dataVersionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadStats();
  }

  Future<void> _loadStats({String? country}) async {
    final targetCountry = country ?? _userCountry;
    try {
      final cloudFunction = ParseCloudFunction('getDashboardStats');
      final response = await cloudFunction.execute(parameters: {
        if (targetCountry.isNotEmpty) 'country': targetCountry,
      });
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;
          final commandes = await Commande.fetchCommandesFromDB();
          final users = await Users.fetchUsersFromDB();
          if (!mounted) return;
          setState(() {
            _totalUsers = (stats['totalUsers'] as num?)?.toInt() ?? 0;
            _totalLivreurs = (stats['totalLivreurs'] as num?)?.toInt()
                ?? users.where((u) => u.roleID == 5 && u.country == targetCountry).length;
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
            commandes.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
            _recentOrders = commandes.take(5).toList();
            _statsLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    final allUsers = await Users.fetchUsersFromDB();
    final allRestaurants = await Restaurant.fetchRestaurantsFromDB();
    final commandes = await Commande.fetchCommandesFromDB();
    if (!mounted) return;
    setState(() {
      final countryUsers = allUsers.where((u) => u.country == targetCountry).toList();
      final countryRestos = allRestaurants.where((r) {
        final owner = Users.getUsersByUserId(allUsers, r.userID);
        return owner?.country == targetCountry;
      }).toList();
      _totalUsers = countryUsers.length;
      _totalLivreurs = countryUsers.where((u) => u.roleID == 5).length;
      _totalRestaurants = countryRestos.length;
      _totalOrders = commandes.length;
      _pendingOrders = commandes.where((c) => CommandeStatus.isPending(c.status)).length;
      commandes.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
      _recentOrders = commandes.take(5).toList();
      _statsLoading = false;
    });
  }

  Future<void> _loadUserRole() async {
    final session = await SessionService.readSession();
    setState(() {
      _userRole = session.role;
      _userCountry = session.country;
      _userName = session.userId.toString();
    });
    final users = await Users.fetchUsersFromDB();
    final user = Users.getUsersByUserId(users, session.userId);
    if (user != null && mounted) {
      setState(() => _userName = '${user.firstname} ${user.lastname}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
          body: RefreshIndicator(
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            backgroundColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
            onRefresh: _loadStats,
            child: CustomScrollView(
              slivers: [
                _buildHeader(),
                if (!_statsLoading) ...[
                  SliverToBoxAdapter(child: _buildKpiGrid()),
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildSparklineSection()),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                  if (_topDishes.isNotEmpty)
                    SliverToBoxAdapter(child: _buildTopDishes()),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                  if (_recentOrders.isNotEmpty)
                    SliverToBoxAdapter(child: _buildRecentOrders()),
                  SliverToBoxAdapter(child: const SizedBox(height: 16)),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildSection(
                    'Utilisateurs', Icons.people_rounded, Colors.blue,
                    '$_totalUsers',
                    subtitle: _newUsersThisMonth > 0 ? '+$_newUsersThisMonth ce mois' : null,
                    onTap: () {
                      Navigator.push(context, CupertinoPageRoute(
                          builder: (_) => CountryPage(sectionType: "utilisateurs")));
                    },
                    onAdd: _userRole == AppRole.superAdmin ? () => _showAddUserDialog(roleID: 1) : null,
                  )),
                  SliverToBoxAdapter(child: const SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _buildSection(
                    'Restaurants', Icons.storefront_rounded, AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                    '$_totalRestaurants', onTap: () {
                    if (_userRole == AppRole.superAdmin) {
                      Navigator.push(context, CupertinoPageRoute(
                          builder: (_) => CountryPage(sectionType: "restaurants")));
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RestaurantListPage(country: _userCountry)));
                    }
                  })),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _buildSection(
                    'Livreurs', Icons.delivery_dining_rounded, AppColors.resolve(AppColors.success, AppDarkColors.success),
                    '$_totalLivreurs', onTap: () {
                    Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => const LivreurListPage()));
                  })),
                  if (_userRole == AppRole.superAdmin) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                    SliverToBoxAdapter(child: _buildSection(
                      'Administrateurs', Icons.admin_panel_settings_rounded, AppColors.resolve(AppColors.error, AppDarkColors.error),
                      '—', onTap: () {
                      Navigator.push(context, CupertinoPageRoute(
                          builder: (_) => CountryPage(sectionType: "administrateurs")));
                    }, onAdd: () => _showAddUserDialog(roleID: 1))),
                  ],
                ] else
                  const SliverToBoxAdapter(child: SizedBox(
                    height: 400, child: Center(child: CircularProgressIndicator()))),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final monthNames = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    final dateStr = '${dayNames[now.weekday - 1]} ${now.day} ${monthNames[now.month - 1]} ${now.year}';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                AppColors.resolve(AppColors.brandLight, AppDarkColors.brandLight),
                AppColors.resolve(AppColors.brandDark, AppDarkColors.brandDark),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -60, left: -30,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                top: 40, right: 80,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 50,
                  left: 20, right: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour, $_userName',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      color: Colors.white.withValues(alpha: 0.8), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.location_on_rounded,
                                      color: Colors.white.withValues(alpha: 0.8), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _userCountry,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, _) {
                            final glow = 0.6 + 0.4 * _glowController.value;
                            return Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: glow * 0.3),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.language_rounded,
                                    color: Colors.white, size: 22),
                                color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                onSelected: (v) {
                                  setState(() => _userCountry = v);
                                  _loadStats(country: v);
                                },
                                itemBuilder: (_) => ['France', 'Bénin', "Côte d'Ivoire"]
                                    .map((c) => PopupMenuItem(
                                      value: c,
                                      child: Row(children: [
                                        Text(
                                          c == 'France' ? '🇫🇷' : c == 'Bénin' ? '🇧🇯' : '🇨🇮',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(c, style: AppTypography.bodyLarge()),
                                      ]),
                                    ))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Vue d\'ensemble', style: AppTypography.titleLarge().copyWith(fontSize: 18)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _KpiCard(
            'Revenus',
            '${_totalRevenue.toStringAsFixed(0)} €',
            Icons.euro_rounded,
            AppColors.resolve(AppColors.success, AppDarkColors.success),
            trendUp: true,
            trendValue: '+12%',
          ),
          _KpiCard(
            'Commandes',
            '$_totalOrders',
            Icons.receipt_long_rounded,
            AppColors.resolve(AppColors.accent, AppDarkColors.accent),
            trendUp: true,
            trendValue: '+8%',
          ),
          _KpiCard(
            'En attente',
            '$_pendingOrders',
            Icons.pending_actions_rounded,
            AppColors.resolve(AppColors.error, AppDarkColors.error),
          ),
          _KpiCard(
            'Confirmées',
            '$_confirmedOrders',
            Icons.verified_rounded,
            AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            subtitle: '$_cancelledOrders annulées',
          ),
        ],
          ),
        ],
      ),
    );
  }

  Widget _buildSparklineSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.trending_up_rounded, color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Commandes cette semaine',
                  style: AppTypography.titleMedium(), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.successLight, AppDarkColors.successLight),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up_rounded, color: AppColors.resolve(AppColors.success, AppDarkColors.success), size: 14),
                  const SizedBox(width: 3),
                  Text('+15%', style: TextStyle(
                      color: AppColors.resolve(AppColors.success, AppDarkColors.success), fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _SparklinePainter(
                data: _recentOrdersDaily,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                glowController: _glowController,
              ),
            ),
          ),
          const SizedBox(height: 6),
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

  Widget _buildTopDishes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.restaurant_menu_rounded, color: AppColors.resolve(AppColors.accent, AppDarkColors.accent), size: 20),
            const SizedBox(width: 8),
            Text('Plats les plus commandés', style: AppTypography.titleMedium()),
          ]),
          const SizedBox(height: 16),
          ..._topDishes.take(5).toList().asMap().entries.map((entry) {
            final dish = entry.value;
            final rank = entry.key + 1;
            final name = dish['name'] ?? 'Plat inconnu';
            final count = dish['count'] ?? 0;
            final revenue = dish['revenue'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight) : AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text('#$rank', style: AppTypography.labelMedium(
                        color: rank <= 3 ? AppColors.resolve(AppColors.accent, AppDarkColors.accent) : AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)).copyWith(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name, style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                ),
                Text('$count commandes', style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                const SizedBox(width: 8),
                if (revenue > 0)
                  Text('${revenue}€', style: AppTypography.labelMedium(color: AppColors.resolve(AppColors.success, AppDarkColors.success)).copyWith(fontSize: 12)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history_rounded, color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 20),
            const SizedBox(width: 8),
            Text('Dernières commandes', style: AppTypography.titleMedium()),
            const Spacer(),
            Text('Voir tout', style: AppTypography.labelMedium(color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)).copyWith(fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          ..._recentOrders.map((order) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CommandeStatus.color(order.status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commande #${order.commandeID}',
                        style: AppTypography.bodyLarge().copyWith(fontSize: 13)),
                    Text(order.dateCommande.toString().substring(0, 10),
                        style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CommandeStatus.color(order.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(order.status,
                    style: TextStyle(
                      color: CommandeStatus.color(order.status),
                      fontSize: 10, fontWeight: FontWeight.w600,
                    )),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flash_on_rounded, color: AppColors.resolve(AppColors.accent, AppDarkColors.accent), size: 20),
            const SizedBox(width: 8),
            Text('Actions rapides', style: AppTypography.titleLarge().copyWith(fontSize: 18)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickActionCard(
              icon: Icons.person_add_rounded,
              label: 'Ajouter',
              subtitle: 'utilisateur',
              color: Colors.blue,
              onTap: _userRole == AppRole.superAdmin
                  ? () => _showAddUserDialog(roleID: 2)
                  : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionCard(
              icon: Icons.add_business_rounded,
              label: 'Nouveau',
              subtitle: 'restaurant',
              color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
              onTap: null,
            )),
            Expanded(child: _QuickActionCard(
              icon: Icons.refresh_rounded,
              label: 'Actualiser',
              subtitle: 'les données',
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              onTap: _loadStats,
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color iconColor, String count,
      {String? subtitle, VoidCallback? onTap, VoidCallback? onAdd}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
            boxShadow: AppShadows.cardList,
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppTypography.titleMedium().copyWith(fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle, style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(count, style: AppTypography.labelMedium(color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))
                  .copyWith(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
          ]),
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog({int roleID = 1}) async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool showPassword = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.person_add_rounded, color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 20),
            ),
            const SizedBox(width: 12),
            Text(roleID == 1 ? 'Ajouter un admin' : 'Ajouter un utilisateur',
                style: AppTypography.titleMedium()),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              TextField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setDialogState(() => showPassword = !showPassword),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: AppTypography.labelMedium(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (usernameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
                final result = await Users.manageUser(
                  roleID: roleID, telephone: '', password: passwordCtrl.text, password_crypte: passwordCtrl.text,
                  firstname: '', lastname: '', email: emailCtrl.text, username: usernameCtrl.text,
                  status: 'Verified', identity: 'Verified', addressID: 0, country: _userCountry,
                );
                if (mounted) {
                  final isSuccess = result is int && result > 0;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isSuccess ? 'Utilisateur créé avec succès' : result.toString()),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ));
                  if (isSuccess) { Navigator.pop(ctx); _loadStats(); }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KPI Card ────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon, this.color,
      {this.trendUp, this.trendValue, this.subtitle});
  final String title, value;
  final IconData icon;
  final Color color;
  final bool? trendUp;
  final String? trendValue;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 4),
            if (trendValue != null)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (trendUp == true ? AppColors.resolve(AppColors.successLight, AppDarkColors.successLight) : AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      trendUp == true
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: trendUp == true ? AppColors.resolve(AppColors.success, AppDarkColors.success) : AppColors.resolve(AppColors.error, AppDarkColors.error),
                      size: 10,
                    ),
                    const SizedBox(width: 1),
                    Flexible(
                      child: Text(
                        trendValue!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: trendUp == true ? AppColors.resolve(AppColors.success, AppDarkColors.success) : AppColors.resolve(AppColors.error, AppDarkColors.error),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: AppTypography.headlineMedium().copyWith(fontSize: 22, height: 1.1)),
          const SizedBox(height: 1),
          Text(title,
              style: AppTypography.labelMedium(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)).copyWith(fontSize: 10)),
          if (subtitle != null)
            Text(subtitle!,
                style: AppTypography.bodyMedium().copyWith(fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Quick Action Card ──────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
          boxShadow: AppShadows.cardList,
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppTypography.labelMedium().copyWith(fontSize: 12)),
            Text(subtitle,
                style: AppTypography.bodyMedium().copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Sparkline Painter (amélioré avec glow) ─────────────
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.color,
    required this.glowController,
  });
  final List<double> data;
  final Color color;
  final Animation<double> glowController;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = 0.0;
    final dx = size.width / (data.length - 1);

    final path = Path();
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height -
          ((data[i] - minVal) / (maxVal - minVal)) * (size.height - 20) -
          10;
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Lueur derrière la ligne
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15 + 0.1 * glowController.value)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Ligne principale
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Remplissage dégradé
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Points sur la ligne
    for (final point in points) {
      canvas.drawCircle(
        point,
        3,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.glowController != glowController;
}
