import 'dart:io';
import 'package:dios_delices/Screen/livreur/LivreurListPage.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantListPage.dart';
import 'package:dios_delices/Screen/utilisateurs/UsersListPage.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/app_role.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/strings.dart';
import '../../utils/toast.dart';
import '../CountryPage.dart';
import 'AdminSupportMessagerie.dart';
import 'AuditLogPage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AppRole _userRole = AppRole.unknown;
  String _userCountry = "France";
  String _userName = '';

  int _totalUsers = 0, _totalRestaurants = 0, _totalOrders = 0;
  double _totalRevenue = 0;
  int _pendingOrders = 0, _confirmedOrders = 0, _cancelledOrders = 0;
  int _newUsersThisMonth = 0, _totalLivreurs = 0;
  bool _statsLoading = true;

  List<Map<String, dynamic>> _pendingRestaurants = [];
  List<Users> _allUsers = [];
  List<Restaurant> _allRestaurants = [];
  int _pendingRestaurantCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadStats();
    dataVersionNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadStats();
  }

  Future<void> _loadStats({String? country}) async {
    final targetCountry = country ?? _userCountry;
    setState(() => _statsLoading = true);

    try {
      final cloudFunction = ParseCloudFunction('getDashboardStats');
      final response = await cloudFunction.execute(parameters: {
        if (targetCountry.isNotEmpty) 'country': targetCountry,
      });
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;
          final users = await Users.fetchUsersFromDB();
          final restaurants = await Restaurant.fetchRestaurantsFromDB();
          final commandes = await Commande.fetchCommandesFromDB();
          if (!mounted) return;
          setState(() {
            _applyLocalData(users, restaurants, commandes, targetCountry, stats);
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
      _applyLocalData(allUsers, allRestaurants, commandes, targetCountry, null);
    });
  }

  void _applyLocalData(List<Users> users, List<Restaurant> restaurants,
      List<Commande> commandes, String targetCountry,
      Map<String, dynamic>? stats) {
    _allUsers = users;
    _allRestaurants = restaurants;

    final countryUsers = users.where((u) => u.country == targetCountry).toList();
    final countryRestos = restaurants.where((r) {
      final owner = Users.getUsersByUserId(users, r.userID);
      return owner?.country == targetCountry;
    }).toList();

    _totalUsers = stats != null
        ? (stats['totalUsers'] as num?)?.toInt() ?? countryUsers.length
        : countryUsers.length;
    _totalLivreurs = countryUsers.where((u) => u.roleID == 5).length;
    _totalRestaurants = stats != null
        ? (stats['totalRestaurants'] as num?)?.toInt() ?? countryRestos.length
        : countryRestos.length;
    _totalOrders = stats != null
        ? (stats['totalOrders'] as num?)?.toInt() ?? commandes.length
        : commandes.length;
    _totalRevenue = stats != null
        ? (stats['totalRevenue'] as num?)?.toDouble() ?? 0
        : 0;
    _pendingOrders = stats != null
        ? (stats['pendingCount'] as num?)?.toInt() ?? 0
        : commandes.where((c) => CommandeStatus.isPending(c.status)).length;
    _confirmedOrders = stats != null
        ? (stats['confirmedCount'] as num?)?.toInt() ?? 0
        : commandes.where((c) => CommandeStatus.isConfirmed(c.status)).length;
    _cancelledOrders = stats != null
        ? (stats['cancelledCount'] as num?)?.toInt() ?? 0
        : commandes.where((c) => CommandeStatus.isCancelled(c.status)).length;
    _newUsersThisMonth = (stats != null
        ? (stats['newUsersThisMonth'] as num?)?.toInt()
        : null) ?? 0;

    _pendingRestaurants = restaurants
        .where((r) => r.valid == 0)
        .where((r) {
          final owner = Users.getUsersByUserId(users, r.userID);
          return owner?.country == targetCountry;
        })
        .map((r) {
          final owner = Users.getUsersByUserId(users, r.userID);
          return {
            'restaurant': r,
            'ownerName': owner != null
                ? '${owner.firstname} ${owner.lastname}'
                : 'Utilisateur #${r.userID}',
          };
        })
        .toList();
    _pendingRestaurantCount = _pendingRestaurants.length;

    _statsLoading = false;
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

  Future<void> _validateRestaurant(Restaurant restaurant) async {
    final result = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 1);
    if (!mounted) return;
    if (result == 'success') {
      Toast(context, '${restaurant.name} ${Strings.validatedWithSuccess}', true);
      _loadStats();
    } else {
      Toast(context, '${Strings.error} : $result', false);
    }
  }

  Future<void> _rejectRestaurant(Restaurant restaurant) async {
    final remarkCtrl = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(Strings.rejectReason, style: AppTypography.titleMedium()),
        content: TextField(
          controller: remarkCtrl,
          decoration: InputDecoration(
            hintText: Strings.rejectReasonHint,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, remarkCtrl.text),
            child: Text(Strings.reject),
          ),
        ],
      ),
    );
    if (remark == null || !mounted) return;
    final result = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 2);
    if (!mounted) return;
    if (result == 'success') {
      Toast(context, '${restaurant.name} ${Strings.rejectedStatus}', false);
      _loadStats();
    } else {
      Toast(context, '${Strings.error} : $result', false);
    }
  }

  void _showSearchDialog() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          List<Users> userResults = [];
          List<Restaurant> restoResults = [];
          if (searchCtrl.text.length >= 2) {
            final q = searchCtrl.text.toLowerCase();
            userResults = _allUsers.where((u) =>
                u.firstname.toLowerCase().contains(q) ||
                u.lastname.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q)).toList();
            restoResults = _allRestaurants.where((r) =>
                r.name.toLowerCase().contains(q)).toList();
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            title: TextField(
              controller: searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: Strings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            content: searchCtrl.text.length >= 2
                ? SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userResults.isNotEmpty) ...[
                          Text('Utilisateurs (${userResults.length})',
                              style: AppTypography.labelMedium(
                                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                          const SizedBox(height: 6),
                          ...userResults.take(5).map((u) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.resolve(
                                      AppColors.brandSurface, AppDarkColors.brandSurface),
                                  child: Text(
                                    '${u.firstname.isNotEmpty ? u.firstname[0] : ''}${u.lastname.isNotEmpty ? u.lastname[0] : ''}',
                                    style: AppTypography.labelMedium(
                                        color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
                                  ),
                                ),
                                title: Text('${u.firstname} ${u.lastname}',
                                    style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                                subtitle: Text(u.email,
                                    style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                              )),
                        ],
                        if (restoResults.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Restaurants (${restoResults.length})',
                              style: AppTypography.labelMedium(
                                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                          const SizedBox(height: 6),
                          ...restoResults.take(5).map((r) => ListTile(
                                dense: true,
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(Icons.storefront_rounded, size: 18,
                                      color: AppColors.resolve(AppColors.accent, AppDarkColors.accent)),
                                ),
                                title: Text(r.name,
                                    style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                                subtitle: Text(r.categories,
                                    style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                              )),
                        ],
                        if (userResults.isEmpty && restoResults.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(Strings.noResults,
                                style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                          ),
                      ],
                    ),
                  )
                : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Strings.close),
              ),
            ],
          );
        },
      ),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Icon(Icons.file_download_rounded,
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
          const SizedBox(width: 10),
          Text(Strings.exportData, style: AppTypography.titleMedium()),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ExportTile(Icons.people_rounded, Strings.users,
              Strings.completeUserList, Colors.blue, () {
            Navigator.pop(ctx);
            _doExport('users');
          }),
          const SizedBox(height: 8),
          _ExportTile(Icons.storefront_rounded, Strings.restaurants,
              Strings.completeRestaurantList, AppColors.resolve(AppColors.accent, AppDarkColors.accent), () {
            Navigator.pop(ctx);
            _doExport('restaurants');
          }),
          const SizedBox(height: 8),
          _ExportTile(Icons.receipt_long_rounded, Strings.orders,
              Strings.ordersHistory, AppColors.resolve(AppColors.success, AppDarkColors.success), () {
            Navigator.pop(ctx);
            _doExport('orders');
          }),
          const SizedBox(height: 8),
          _ExportTile(Icons.description_rounded, Strings.completeReport,
              Strings.usersRestaurantsOrders, AppColors.resolve(AppColors.brand, AppDarkColors.brand), () {
            Navigator.pop(ctx);
            _doExport('report');
          }),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Strings.cancel, style: AppTypography.labelMedium(
                color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(String type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      String filename;
      String csv;

      if (type == 'users') {
        filename = 'utilisateurs_$ts.csv';
        csv = _generateCsv(
          ['ID', 'Nom', 'Prénom', 'Email', 'Username', 'Rôle', 'Pays', 'Téléphone', 'Statut'],
          _allUsers.map((u) => [
            u.userID.toString(), _esc(u.lastname), _esc(u.firstname), _esc(u.email),
            _esc(u.username), _roleLabel(u.roleID), _esc(u.country),
            _esc(u.telephone), _esc(u.status),
          ]).toList(),
        );
      } else if (type == 'restaurants') {
        filename = 'restaurants_$ts.csv';
        csv = _generateCsv(
          ['ID', 'Nom', 'Propriétaire', 'Catégories', 'Validé'],
          _allRestaurants.map((r) {
            final owner = Users.getUsersByUserId(_allUsers, r.userID);
            return [
              r.restaurantID.toString(), _esc(r.name),
              _esc(owner != null ? '${owner.firstname} ${owner.lastname}' : '#${r.userID}'),
              _esc(r.categories),
              r.valid == 1 ? 'Oui' : r.valid == 2 ? 'Rejeté' : Strings.pending,
            ];
          }).toList(),
        );
      } else if (type == 'orders') {
        final commandes = await Commande.fetchCommandesFromDB();
        filename = 'commandes_$ts.csv';
        csv = _generateCsv(
          ['ID', 'Client', 'Status', 'Livraison (€)', 'Réduction (€)', 'Date'],
          commandes.map((c) {
            final user = Users.getUsersByUserId(_allUsers, c.userID);
            return [
              c.commandeID.toString(),
              _esc(user != null ? '${user.firstname} ${user.lastname}' : '#${c.userID}'),
              _esc(c.status), c.fraisLivraison.toStringAsFixed(2),
              c.reduction.toStringAsFixed(2),
              c.dateCommande.toIso8601String().split('T')[0],
            ];
          }).toList(),
        );
      } else {
        filename = 'rapport_dashboard_$ts.csv';
        final commandes = await Commande.fetchCommandesFromDB();
        csv = [
          'RAPPORT DASHBOARD — ${_userCountry} — $ts',
          '',
          'RÉSUMÉ',
          'Utilisateurs;$_totalUsers',
          'Restaurants;$_totalRestaurants',
          'Livreurs;$_totalLivreurs',
          'Commandes;$_totalOrders',
          'En attente;$_pendingOrders',
          'Confirmées;$_confirmedOrders',
          'Annulées;$_cancelledOrders',
          'Revenus;${_totalRevenue.toStringAsFixed(0)} €',
          '',
          'UTILISATEURS',
          'ID;Nom;Prénom;Email;Rôle;Pays;Téléphone',
          ..._allUsers.map((u) => [
            u.userID.toString(), _esc(u.lastname), _esc(u.firstname), _esc(u.email),
            _roleLabel(u.roleID), _esc(u.country), _esc(u.telephone),
          ].join(';')),
          '',
          'RESTAURANTS',
          'ID;Nom;Propriétaire;Catégories;Validé',
          ..._allRestaurants.map((r) {
            final owner = Users.getUsersByUserId(_allUsers, r.userID);
            return [
              r.restaurantID.toString(), _esc(r.name),
              _esc(owner != null ? '${owner.firstname} ${owner.lastname}' : '#${r.userID}'),
              _esc(r.categories),
              r.valid == 1 ? 'Oui' : r.valid == 2 ? 'Rejeté' : Strings.pending,
            ].join(';');
          }),
          '',
          'COMMANDES',
          'ID;Client;Status;Livraison;Réduction;Date',
          ...commandes.map((c) {
            final user = Users.getUsersByUserId(_allUsers, c.userID);
            return [
              c.commandeID.toString(),
              _esc(user != null ? '${user.firstname} ${user.lastname}' : '#${c.userID}'),
              _esc(c.status), c.fraisLivraison.toStringAsFixed(2),
              c.reduction.toStringAsFixed(2),
              c.dateCommande.toIso8601String().split('T')[0],
            ].join(';');
          }),
        ].join('\n');
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.resolve(AppColors.success, AppDarkColors.success)),
              const SizedBox(width: 10),
              Flexible(child: Text(Strings.exportSuccess, style: AppTypography.titleMedium())),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(filename, style: AppTypography.bodyLarge()),
              const SizedBox(height: 6),
              Text(dir.path, style: AppTypography.bodyMedium(color:
                  AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)).copyWith(fontSize: 11)),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Strings.close),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Toast(context, '${Strings.exportErrorLabel} : $e', false);
    }
  }

  String _esc(String s) => '"${s.replaceAll('"', '""')}"';
  String _roleLabel(int id) => ['', 'Admin', 'Client', 'Restaurateur', 'Super Admin', 'Livreur'][id >= 0 && id <= 5 ? id : 0];

  String _generateCsv(List<String> headers, List<List<String>> rows) {
    final buf = StringBuffer();
    buf.writeln('\uFEFF');
    buf.writeln(headers.join(';'));
    for (final row in rows) {
      buf.writeln(row.join(';'));
    }
    return buf.toString();
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
                if (_statsLoading)
                  const SliverToBoxAdapter(child: SizedBox(
                    height: 400, child: Center(child: CircularProgressIndicator()))),
                if (!_statsLoading) ...[
                  SliverToBoxAdapter(child: _buildKpiGrid()),
                  if (_pendingRestaurantCount > 0) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(child: _buildValidationSection()),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(child: _buildNavigationSections()),
                ],
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandLight, AppColors.brandDark],
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -40, right: -40,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(bottom: -60, left: -30,
                child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(top: 40, right: 80,
                child: Container(width: 40, height: 40,
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
                              Text('${Strings.hello}, $_userName',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24, fontWeight: FontWeight.w700,
                                  color: Colors.white, height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    color: Colors.white.withValues(alpha: 0.8), size: 14),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(dateStr, style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  )),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_userRole == AppRole.superAdmin)
                      Wrap(spacing: 8, children: ['France', 'Bénin', "Côte d'Ivoire"].map((c) {
                        final active = _userCountry == c;
                        final flag = c == 'France' ? '🇫🇷' : c == 'Bénin' ? '🇧🇯' : '🇨🇮';
                        return GestureDetector(
                          onTap: () {
                            setState(() => _userCountry = c);
                            _loadStats(country: c);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? Colors.white : Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(flag, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(c, style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: active ? const Color(0xFF261814) : Colors.white,
                              )),
                            ]),
                          ),
                        );
                      }).toList())
                    else
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 14),
                        const SizedBox(width: 4),
                        Text(_userCountry, style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        )),
                      ]),
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
          Row(children: [
            Expanded(
              child: Text(Strings.overview,
                  style: AppTypography.titleLarge().copyWith(fontSize: 18)),
            ),
            IconButton(
              icon: Icon(Icons.search_rounded,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted), size: 22),
              onPressed: _showSearchDialog,
              tooltip: Strings.search,
            ),
            if (_pendingRestaurantCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$_pendingRestaurantCount ${Strings.pending.toLowerCase()}',
                    style: AppTypography.labelMedium(
                        color: AppColors.resolve(AppColors.error, AppDarkColors.error)).copyWith(fontSize: 10)),
              ),
          ]),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _KpiCard(Strings.revenue, '${_totalRevenue.toStringAsFixed(0)} €',
                  Icons.euro_rounded,
                  AppColors.resolve(AppColors.success, AppDarkColors.success)),
              _KpiCard(Strings.orders, '$_totalOrders',
                  Icons.receipt_long_rounded,
                  AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                  subtitle: '$_confirmedOrders ${Strings.confirmedPlural}'),
              _KpiCard(Strings.pending, '$_pendingOrders',
                  Icons.pending_actions_rounded,
                  AppColors.resolve(AppColors.error, AppDarkColors.error),
                  subtitle: '$_cancelledOrders ${Strings.cancelledPlural}'),
              _KpiCard(Strings.users, '$_totalUsers',
                  Icons.people_rounded,
                  AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  subtitle: _newUsersThisMonth > 0 ? '+$_newUsersThisMonth ${Strings.thisMonth}' : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.assignment_turned_in_rounded,
                  color: AppColors.resolve(AppColors.error, AppDarkColors.error), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(Strings.pendingRestaurantsValidation,
                  style: AppTypography.titleMedium()),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$_pendingRestaurantCount',
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(AppColors.error, AppDarkColors.error))),
            ),
          ]),
          const SizedBox(height: 16),
          ..._pendingRestaurants.take(5).map((entry) {
            final Restaurant resto = entry['restaurant'];
            final String ownerName = entry['ownerName'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.storefront_rounded, size: 22,
                        color: AppColors.resolve(AppColors.accent, AppDarkColors.accent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resto.name,
                            style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                        Text(ownerName,
                            style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted), size: 20),
                    onPressed: () => _rejectRestaurant(resto),
                    tooltip: Strings.reject,
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.check_circle_rounded,
                        color: AppColors.resolve(AppColors.success, AppDarkColors.success), size: 22),
                    onPressed: () => _validateRestaurant(resto),
                    tooltip: Strings.validate,
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
                  ),
                ]),
              ),
            );
          }),
          if (_pendingRestaurants.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RestaurantListPage(country: _userCountry)));
                  },
                  child: Text('Voir les ${_pendingRestaurants.length} restaurants en attente',
                      style: AppTypography.labelMedium(
                          color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))),
                ),
              ),
            ),
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
            Icon(Icons.flash_on_rounded,
                color: AppColors.resolve(AppColors.accent, AppDarkColors.accent), size: 20),
            const SizedBox(width: 8),
            Text(Strings.quickActions,
                style: AppTypography.titleLarge().copyWith(fontSize: 18)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (_userRole == AppRole.superAdmin) ...[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_add_rounded,
                  label: Strings.addAdmin,
                  color: Colors.blue,
                  onTap: () => _showAddUserDialog(roleID: 1),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _QuickActionCard(
                icon: Icons.file_download_rounded,
                label: Strings.export,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                onTap: _exportData,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.refresh_rounded,
                label: Strings.refresh,
                color: AppColors.resolve(AppColors.success, AppDarkColors.success),
                onTap: _loadStats,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildNavigationSections() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.grid_view_rounded,
                color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted), size: 20),
            const SizedBox(width: 8),
            Text(Strings.management, style: AppTypography.titleLarge().copyWith(fontSize: 18)),
          ]),
          const SizedBox(height: 12),
          _buildSection(
            Strings.users, Icons.people_rounded, Colors.blue,
            '$_totalUsers',
            subtitle: _newUsersThisMonth > 0 ? '+$_newUsersThisMonth ${Strings.thisMonth}' : null,
            onTap: () {
              if (_userRole == AppRole.superAdmin) {
                Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => const CountryPage(sectionType: "utilisateurs")));
              } else {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UsersListPage(country: _userCountry)));
              }
            },
            onAdd: _userRole == AppRole.superAdmin
                ? () => _showAddUserDialog(roleID: 2)
                : null,
          ),
          const SizedBox(height: 8),
          _buildSection(
            Strings.restaurants, Icons.storefront_rounded,
            AppColors.resolve(AppColors.accent, AppDarkColors.accent),
            '$_totalRestaurants',
            badge: _pendingRestaurantCount > 0 ? '+$_pendingRestaurantCount' : null,
            onTap: () {
              if (_userRole == AppRole.superAdmin) {
                Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => CountryPage(sectionType: "restaurants")));
              } else {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RestaurantListPage(country: _userCountry)));
              }
            },
          ),
          const SizedBox(height: 8),
          _buildSection(
            Strings.livreurs, Icons.delivery_dining_rounded,
            AppColors.resolve(AppColors.success, AppDarkColors.success),
            '$_totalLivreurs',
            onTap: () {
              if (_userRole == AppRole.superAdmin) {
                Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => const CountryPage(sectionType: "livreurs")));
              } else {
                Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => const LivreurListPage()));
              }
            },
          ),
          if (_userRole == AppRole.superAdmin) ...[
            const SizedBox(height: 8),
            _buildSection(
              Strings.administrators, Icons.admin_panel_settings_rounded,
              AppColors.resolve(AppColors.error, AppDarkColors.error),
              '—',
              onTap: () {
                Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => CountryPage(sectionType: "administrateurs")));
              },
              onAdd: () => _showAddUserDialog(roleID: 1),
            ),
            const SizedBox(height: 8),
            _buildSection(
              Strings.supportChat, Icons.support_agent_rounded,
              AppColors.resolve(AppColors.brand, AppDarkColors.brand), '',
              subtitle: Strings.chatWithUsers,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AdminSupportMessagerie(country: _userCountry))),
            ),
            const SizedBox(height: 8),
            _buildSection(
              Strings.auditLog, Icons.history_rounded,
              AppColors.resolve(AppColors.accent, AppDarkColors.accent), '',
              subtitle: Strings.auditTrail,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AuditLogPage(country: _userCountry))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color iconColor, String count,
      {String? subtitle, String? badge, VoidCallback? onTap, VoidCallback? onAdd}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium().copyWith(fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle, style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(badge,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(AppColors.error, AppDarkColors.error)).copyWith(fontSize: 11)),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(count,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)).copyWith(fontSize: 14)),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.successLight, AppDarkColors.successLight),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: IconButton(
                icon: Icon(Icons.add_rounded,
                    color: AppColors.resolve(AppColors.success, AppDarkColors.success), size: 18),
                onPressed: onAdd,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
        ]),
      ),
    );
  }

  Future<void> _showAddUserDialog({int roleID = 1}) async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final firstnameCtrl = TextEditingController();
    final lastnameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool showPassword = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.person_add_rounded,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 20),
            ),
            const SizedBox(width: 12),
            Text(roleID == 1 ? Strings.addAdmin : Strings.addUserLabel,
                style: AppTypography.titleMedium()),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              TextField(
                controller: firstnameCtrl,
                decoration: InputDecoration(
                  labelText: Strings.firstName,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastnameCtrl,
                decoration: InputDecoration(
                  labelText: Strings.lastName,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: Strings.username,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: Strings.email,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: Strings.password,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded, size: 20),
                    onPressed: () =>
                        setDialogState(() => showPassword = !showPassword),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Strings.cancel,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (usernameCtrl.text.isEmpty || emailCtrl.text.isEmpty ||
                    passwordCtrl.text.isEmpty) return;
                if (roleID == 1 && (firstnameCtrl.text.isEmpty || lastnameCtrl.text.isEmpty)) return;
                final result = await Users.manageUser(
                  roleID: roleID,
                  telephone: '',
                  password: passwordCtrl.text,
                  password_crypte: passwordCtrl.text,
                  firstname: firstnameCtrl.text,
                  lastname: lastnameCtrl.text,
                  email: emailCtrl.text,
                  username: usernameCtrl.text,
                  status: 'Verified',
                  identity: 'Verified',
                  addressID: 0,
                  country: _userCountry,
                );
                if (mounted) {
                  final isSuccess = result is int && result > 0;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isSuccess
                        ? Strings.userCreatedSuccess
                        : result.toString()),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ));
                  if (isSuccess) {
                    Navigator.pop(ctx);
                    _loadStats();
                  }
                }
              },
              child: Text(Strings.create),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon, this.color, {this.subtitle});
  final String title, value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: AppTypography.headlineMedium().copyWith(fontSize: 22, height: 1.1)),
          const SizedBox(height: 2),
          Text(title,
              style: AppTypography.labelMedium(
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)).copyWith(fontSize: 11)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!,
                  style: AppTypography.bodyMedium().copyWith(fontSize: 10)),
            ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
          boxShadow: AppShadows.cardList,
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.labelMedium().copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ExportTile(this.icon, this.title, this.subtitle, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
              Text(subtitle, style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
        ]),
      ),
    );
  }
}
