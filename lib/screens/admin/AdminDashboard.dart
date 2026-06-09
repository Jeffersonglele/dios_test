import 'dart:io';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/delivery/LivreurListPage.dart';
import 'package:dios_delices/screens/restaurants/RestaurantListPage.dart';
import 'package:dios_delices/screens/users/UsersListPage.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/commande.dart';
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
import '../../utils/currency_util.dart';
import '../../utils/toast.dart';
import 'CategoryManagementPage.dart';
import 'PromotionsPage.dart';
import 'ParrainagePage.dart';
import 'ScheduledDeletionsPage.dart';
import 'AuditLogPage.dart';
import '../CountryPage.dart';

// ═══════════════════════════════════════════════════════════
// AdminDashboard — Refonte complète
// ═══════════════════════════════════════════════════════════

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ── Données utilisateur ──────────────────────────────────
  AppRole _userRole = AppRole.unknown;
  String _userCountry = 'France';
  String _userName = '';

  // ── Statistiques ─────────────────────────────────────────
  int _totalUsers = 0;
  int _totalRestaurants = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  int _pendingOrders = 0;
  int _confirmedOrders = 0;
  int _cancelledOrders = 0;
  int _newUsersMonth = 0;
  int _totalLivreurs = 0;
  bool _statsLoading = true;

  // ── Restaurants en attente ───────────────────────────────
  List<Map<String, dynamic>> _pendingRestaurants = [];
  int _pendingRestaurantCount = 0;

  List<Users> _allUsers = [];
  List<Restaurant> _allRestaurants = [];

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

  // ── Chargement stats ─────────────────────────────────────
  Future<void> _loadStats({String? country}) async {
    final target = country ?? _userCountry;
    setState(() => _statsLoading = true);

    try {
      final fn = ParseCloudFunction('getDashboardStats');
      final response = await fn
          .execute(parameters: {if (target.isNotEmpty) 'country': target});
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;
          final users = await Users.fetchUsersFromDB();
          final restaurants = await Restaurant.fetchRestaurantsFromDB();
          final commandes = await Commande.fetchCommandesFromDB();
          if (!mounted) return;
          setState(
              () => _applyData(users, restaurants, commandes, target, stats));
          return;
        }
      }
    } catch (_) {}

    final users = await Users.fetchUsersFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final commandes = await Commande.fetchCommandesFromDB();
    if (!mounted) return;
    setState(() => _applyData(users, restaurants, commandes, target, null));
  }

  void _applyData(
    List<Users> users,
    List<Restaurant> restaurants,
    List<Commande> commandes,
    String targetCountry,
    Map<String, dynamic>? stats,
  ) {
    _allUsers = users;
    _allRestaurants = restaurants;

    final cu = users.where((u) => u.country == targetCountry).toList();
    final cr = restaurants.where((r) {
      final owner = Users.getUsersByUserId(users, r.userID);
      return owner?.country == targetCountry;
    }).toList();

    int _s(String key, int fallback) =>
        stats != null ? (stats[key] as num?)?.toInt() ?? fallback : fallback;
    double _sd(String key, double fallback) =>
        stats != null ? (stats[key] as num?)?.toDouble() ?? fallback : fallback;

    _totalUsers = _s('totalUsers', cu.length);
    _totalLivreurs = cu.where((u) => u.roleID == 5).length;
    _totalRestaurants = _s('totalRestaurants', cr.length);
    _totalOrders = _s('totalOrders', commandes.length);
    _totalRevenue = _sd('totalRevenue', 0);
    _pendingOrders = _s('pendingCount',
        commandes.where((c) => CommandeStatus.isPending(c.status)).length);
    _confirmedOrders = _s('confirmedCount',
        commandes.where((c) => CommandeStatus.isConfirmed(c.status)).length);
    _cancelledOrders = _s('cancelledCount',
        commandes.where((c) => CommandeStatus.isCancelled(c.status)).length);
    _newUsersMonth = (stats != null
            ? (stats['newUsersThisMonth'] as num?)?.toInt()
            : null) ??
        0;

    _pendingRestaurants = restaurants.where((r) => r.valid == 0).where((r) {
      final owner = Users.getUsersByUserId(users, r.userID);
      return owner?.country == targetCountry;
    }).map((r) {
      final owner = Users.getUsersByUserId(users, r.userID);
      return {
        'restaurant': r,
        'ownerName': owner != null
            ? '${owner.firstname} ${owner.lastname}'
            : 'Utilisateur #${r.userID}',
      };
    }).toList();
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

  // ── Validation / rejet restaurant ────────────────────────
  Future<void> _validateRestaurant(Restaurant r) async {
    final result = await Restaurant.updateRestaurantStatus(r.restaurantID, 1);
    if (!mounted) return;
    if (result == 'success') {
      Toast(
          context,
          AppLocalizations.of(context)!.admin_restaurant_validated(r.name),
          true);
      _loadStats();
    } else {
      Toast(context, 'Erreur : $result', false);
    }
  }

  Future<void> _rejectRestaurant(Restaurant r) async {
    final ctrl = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(AppLocalizations.of(context)!.rejectReason,
            style: AppTypography.titleMedium()),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
              hintText:
                  AppLocalizations.of(context)!.admin_rejection_reason_hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.admin_reject),
          ),
        ],
      ),
    );
    if (remark == null || !mounted) return;
    final result = await Restaurant.updateRestaurantStatus(r.restaurantID, 2);
    if (!mounted) return;
    if (result == 'success') {
      Toast(
          context,
          AppLocalizations.of(context)!.admin_restaurant_rejected(r.name),
          false);
      _loadStats();
    } else {
      Toast(context, 'Erreur : $result', false);
    }
  }

  // ── Recherche ─────────────────────────────────────────────
  void _showSearch() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          List<Users> ur = [];
          List<Restaurant> rr = [];
          if (ctrl.text.length >= 2) {
            final q = ctrl.text.toLowerCase();
            ur = _allUsers
                .where((u) =>
                    u.firstname.toLowerCase().contains(q) ||
                    u.lastname.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q))
                .toList();
            rr = _allRestaurants
                .where((r) => r.name.toLowerCase().contains(q))
                .toList();
          }
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            title: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.admin_search_hint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
              onChanged: (_) => set(() {}),
            ),
            content: ctrl.text.length >= 2
                ? SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ur.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(AppLocalizations.of(context)!.users,
                                style: AppTypography.labelMedium(
                                    color: AppColors.inkMuted)),
                          ),
                          ...ur.take(4).map((u) => ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.resolve(
                                      AppColors.brandSurface,
                                      AppDarkColors.brandSurface),
                                  child: Text(
                                    u.firstname.isNotEmpty
                                        ? u.firstname[0].toUpperCase()
                                        : '?',
                                    style: AppTypography.labelMedium(
                                        color: AppColors.brand),
                                  ),
                                ),
                                title: Text('${u.firstname} ${u.lastname}',
                                    style: AppTypography.bodyLarge()
                                        .copyWith(fontSize: 14)),
                                subtitle: Text(u.email,
                                    style: AppTypography.bodyMedium()
                                        .copyWith(fontSize: 11)),
                              )),
                        ],
                        if (rr.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(
                                AppLocalizations.of(context)!.restaurants,
                                style: AppTypography.labelMedium(
                                    color: AppColors.inkMuted)),
                          ),
                          ...rr.take(4).map((r) => ListTile(
                                dense: true,
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: const Icon(Icons.storefront_rounded,
                                      size: 18, color: AppColors.accent),
                                ),
                                title: Text(r.name,
                                    style: AppTypography.bodyLarge()
                                        .copyWith(fontSize: 14)),
                                subtitle: Text(r.categories,
                                    style: AppTypography.bodyMedium()
                                        .copyWith(fontSize: 11)),
                              )),
                        ],
                        if (ur.isEmpty && rr.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(AppLocalizations.of(context)!.noResults,
                                style: AppTypography.bodyMedium(
                                    color: AppColors.inkMuted)),
                          ),
                      ],
                    ),
                  )
                : null,
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context)!.close)),
            ],
          );
        },
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────
  void _showExport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.file_download_rounded,
                color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(AppLocalizations.of(context)!.admin_export_title,
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ExportTile(Icons.people_rounded, AppLocalizations.of(context)!.users,
              Colors.blue, () {
            Navigator.pop(ctx);
            _doExport('users');
          }),
          const SizedBox(height: AppSpacing.sm),
          _ExportTile(Icons.storefront_rounded,
              AppLocalizations.of(context)!.restaurants, AppColors.accent, () {
            Navigator.pop(ctx);
            _doExport('restaurants');
          }),
          const SizedBox(height: AppSpacing.sm),
          _ExportTile(Icons.receipt_long_rounded,
              AppLocalizations.of(context)!.orders, AppColors.success, () {
            Navigator.pop(ctx);
            _doExport('orders');
          }),
          const SizedBox(height: AppSpacing.sm),
          _ExportTile(
              Icons.description_rounded,
              AppLocalizations.of(context)!.admin_export_full_report,
              AppColors.brand, () {
            Navigator.pop(ctx);
            _doExport('report');
          }),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel)),
        ],
      ),
    );
  }

  Future<void> _doExport(String type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      String filename, csv;

      if (type == 'users') {
        filename = 'utilisateurs_$ts.csv';
        csv = _csv(
            ['ID', 'Nom', 'Prénom', 'Email', 'Rôle', 'Pays', 'Téléphone'],
            _allUsers
                .map((u) => [
                      u.userID.toString(),
                      _e(u.lastname),
                      _e(u.firstname),
                      _e(u.email),
                      _role(u.roleID),
                      _e(u.country),
                      _e(u.telephone),
                    ])
                .toList());
      } else if (type == 'restaurants') {
        filename = 'restaurants_$ts.csv';
        csv = _csv(
            ['ID', 'Nom', 'Propriétaire', 'Catégories', 'Validé'],
            _allRestaurants.map((r) {
              final o = Users.getUsersByUserId(_allUsers, r.userID);
              return [
                r.restaurantID.toString(),
                _e(r.name),
                _e(o != null ? '${o.firstname} ${o.lastname}' : '#${r.userID}'),
                _e(r.categories),
                r.valid == 1
                    ? 'Oui'
                    : r.valid == 2
                        ? 'Rejeté'
                        : 'Attente',
              ];
            }).toList());
      } else if (type == 'orders') {
        final cmds = await Commande.fetchCommandesFromDB();
        filename = 'commandes_$ts.csv';
        csv = _csv(
            ['ID', 'Client', 'Status', 'Livraison', 'Réduction', 'Date'],
            cmds.map((c) {
              final u = Users.getUsersByUserId(_allUsers, c.userID);
              return [
                c.commandeID.toString(),
                _e(u != null ? '${u.firstname} ${u.lastname}' : '#${c.userID}'),
                _e(c.status),
                c.fraisLivraison.toStringAsFixed(2),
                c.reduction.toStringAsFixed(2),
                c.dateCommande.toIso8601String().split('T')[0],
              ];
            }).toList());
      } else {
        final cmds = await Commande.fetchCommandesFromDB();
        filename = 'rapport_$ts.csv';
        csv = 'Rapport — $_userCountry — $ts\n\n...\n';
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      if (mounted) Toast(context, 'Export : $filename', true);
    } catch (e) {
      if (mounted) Toast(context, 'Erreur : $e', false);
    }
  }

  String _e(String s) => '"${s.replaceAll('"', '""')}"';
  String _role(int id) => [
        '',
        'Admin',
        'Client',
        'Restaurateur',
        'Super Admin',
        'Livreur'
      ][id >= 0 && id <= 5 ? id : 0];
  String _csv(List<String> h, List<List<String>> rows) {
    final b = StringBuffer()
      ..writeln('\uFEFF')
      ..writeln(h.join(';'));
    for (final r in rows) b.writeln(r.join(';'));
    return b.toString();
  }

  // ── Ajouter utilisateur ───────────────────────────────────
  Future<void> _showAddUser({int roleID = 1}) async {
    final fn = TextEditingController();
    final ln = TextEditingController();
    final un = TextEditingController();
    final em = TextEditingController();
    int selectedRole = roleID == 4 ? 4 : 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: AppColors.brand, size: 17),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.of(context)!.admin_add_admin_title,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: AppSpacing.sm),
              _DlgField(
                  ctrl: fn,
                  label: AppLocalizations.of(context)!.firstName,
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: AppSpacing.sm),
              _DlgField(
                  ctrl: ln,
                  label: AppLocalizations.of(context)!.lastName,
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: AppSpacing.sm),
              _DlgField(
                  ctrl: un,
                  label: AppLocalizations.of(context)!.username,
                  icon: Icons.badge_outlined),
              const SizedBox(height: AppSpacing.sm),
              _DlgField(
                  ctrl: em,
                  label: AppLocalizations.of(context)!.email,
                  icon: Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                value: selectedRole,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.role,
                  prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                ),
                items: [
                  DropdownMenuItem(
                      value: 1,
                      child:
                          Text(AppLocalizations.of(context)!.administrators)),
                  DropdownMenuItem(value: 4, child: Text('Super Admin')),
                ],
                onChanged: (v) {
                  if (v != null) set(() => selectedRole = v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.brandSurface, AppDarkColors.brandSurface),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.brand, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.admin_add_admin_info,
                      style:
                          AppTypography.bodySmall(color: AppColors.brandDark),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (un.text.isEmpty || em.text.isEmpty) return;
                final result = await Users.manageUser(
                  roleID: selectedRole,
                  telephone: '',
                  password: '',
                  password_crypte: '',
                  firstname: fn.text,
                  lastname: ln.text,
                  email: em.text,
                  username: un.text,
                  status: 'Verified',
                  identity: 'Verified',
                  addressID: 0,
                  country: _userCountry,
                );
                if (!mounted) return;
                final ok = result is int && result > 0;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? AppLocalizations.of(context)!.admin_admin_created
                      : result.toString()),
                  backgroundColor: ok ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ));
                if (ok) {
                  Navigator.pop(ctx);
                  _loadStats();
                }
              },
              child: Text(AppLocalizations.of(context)!.create),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 400;
    final isMediumScreen = width >= 400 && width < 800;
    final isLargeScreen = width >= 800;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.brand,
            backgroundColor:
                AppColors.resolve(AppColors.card, AppDarkColors.card),
            onRefresh: _loadStats,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero SliverAppBar ──────────────────────
                _HeroAppBar(
                  userName: _userName,
                  userRole: _userRole,
                  userCountry: _userCountry,
                  onSearch: _showSearch,
                  onCountryChanged: (c) {
                    setState(() => _userCountry = c);
                    _loadStats(country: c);
                  },
                ),

                if (_statsLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  )
                else ...[
                  // ── KPI ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: _KpiSection(
                      totalRevenue: _totalRevenue,
                      totalOrders: _totalOrders,
                      confirmedOrders: _confirmedOrders,
                      pendingOrders: _pendingOrders,
                      cancelledOrders: _cancelledOrders,
                      totalUsers: _totalUsers,
                      newUsersMonth: _newUsersMonth,
                      totalLivreurs: _totalLivreurs,
                      totalRestaurants: _totalRestaurants,
                      country: _userCountry,
                    ),
                  ),

                  // ── Alerte restaurants en attente ────────
                  if (_pendingRestaurantCount > 0)
                    SliverToBoxAdapter(
                      child: _ValidationAlert(
                        count: _pendingRestaurantCount,
                      ),
                    ),

                  // ── Section validation ───────────────────
                  if (_pendingRestaurants.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _ValidationSection(
                        pendingRestaurants: _pendingRestaurants,
                        userCountry: _userCountry,
                        onValidate: _validateRestaurant,
                        onReject: _rejectRestaurant,
                      ),
                    ),

                  // ── Actions rapides ──────────────────────
                  SliverToBoxAdapter(
                    child: _QuickActionsSection(
                      userRole: _userRole,
                      onExport: _showExport,
                      onRefresh: _loadStats,
                      onAddAdmin: () => _showAddUser(roleID: 1),
                    ),
                  ),

                  // ── Navigation gestion ───────────────────
                  SliverToBoxAdapter(
                    child: _ManagementNav(
                      userRole: _userRole,
                      userCountry: _userCountry,
                      totalUsers: _totalUsers,
                      totalRestaurants: _totalRestaurants,
                      totalLivreurs: _totalLivreurs,
                      newUsersMonth: _newUsersMonth,
                      pendingCount: _pendingRestaurantCount,
                      onAddUser: () => _showAddUser(roleID: 2),
                      onAddAdmin: () => _showAddUser(roleID: 1),
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      isLargeScreen: isLargeScreen,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _HeroAppBar — SliverAppBar avec dégradé brand
// ═══════════════════════════════════════════════════════════
class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({
    required this.userName,
    required this.userRole,
    required this.userCountry,
    required this.onSearch,
    required this.onCountryChanged,
  });

  final String userName;
  final AppRole userRole;
  final String userCountry;
  final VoidCallback onSearch;
  final ValueChanged<String> onCountryChanged;

  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];
  static const _months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre'
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 400;

    final now = DateTime.now();
    final dateStr =
        '${_days[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';

    return SliverAppBar(
      pinned: true,
      expandedHeight: isSmallScreen ? 180 : 220,
      automaticallyImplyLeading: false,
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.xl)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brandDark,
                  AppColors.brand,
                  AppColors.brandLight
                ],
              ),
            ),
            child: Stack(
              children: [
                // ── Lignes décoratives obliques ──────────
                Positioned(
                  right: -20,
                  top: -10,
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Container(
                      width: 200,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  top: 28,
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Container(
                      width: 130,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: 20,
                  child: Transform.rotate(
                    angle: 0.25,
                    child: Container(
                      width: 160,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),

                // ── Contenu ──────────────────────────────
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top +
                        (isSmallScreen ? 40 : 56),
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Salutation + date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.admin_greeting(userName)} 👋',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSmallScreen ? 18 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Colors.white60, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: isSmallScreen ? 11 : 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          // Bouton recherche dans le hero
                          GestureDetector(
                            onTap: onSearch,
                            child: Container(
                              width: isSmallScreen ? 36 : 40,
                              height: isSmallScreen ? 36 : 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.20)),
                              ),
                              child: Icon(Icons.search_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 18 : 20),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Sélecteur de pays (super admin) ou badge pays
                      if (userRole == AppRole.superAdmin)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children:
                              ['France', 'Bénin', "Côte d'Ivoire"].map((c) {
                            final active = userCountry == c;
                            final flag = c == 'France'
                                ? '🇫🇷'
                                : c == 'Bénin'
                                    ? '🇧🇯'
                                    : '🇨🇮';
                            return GestureDetector(
                              onTap: () => onCountryChanged(c),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(flag,
                                          style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        c,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: isSmallScreen ? 11 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: active
                                              ? AppColors.ink
                                              : Colors.white,
                                        ),
                                      ),
                                    ]),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.resolve(
                                AppColors.brandSurface.withValues(alpha: 0.14),
                                AppDarkColors.brandSurface),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white70, size: 13),
                            const SizedBox(width: 5),
                            Text(userCountry,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSmallScreen ? 11 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Raccord arrondi avec le fond
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(20),
        child: Container(
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _KpiSection — 3 lignes de métriques
// ═══════════════════════════════════════════════════════════
class _KpiSection extends StatelessWidget {
  const _KpiSection({
    required this.totalRevenue,
    required this.totalOrders,
    required this.confirmedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalUsers,
    required this.newUsersMonth,
    required this.totalLivreurs,
    required this.totalRestaurants,
    required this.country,
  });

  final double totalRevenue;
  final int totalOrders,
      confirmedOrders,
      pendingOrders,
      cancelledOrders,
      totalUsers,
      newUsersMonth,
      totalLivreurs,
      totalRestaurants;
  final String country;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 400;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label section
          Row(children: [
            Text(l10n.overview,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const Spacer(),
            // Badge total commandes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$totalOrders ${l10n.orders}',
                style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand))
                    .copyWith(fontSize: isSmallScreen ? 9 : 11),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),

          // ── Revenus — carte large ─────────────────────
          _RevenueCard(
            revenue: totalRevenue,
            orders: totalOrders,
            confirmed: confirmedOrders,
            country: country,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Utilisateurs + livreurs + restaurants ──────
          Row(children: [
            Expanded(
              child: _KpiTile(
                value: '$totalUsers',
                label: l10n.users,
                sublabel:
                    newUsersMonth > 0 ? '+$newUsersMonth ce mois' : l10n.total,
                icon: Icons.people_rounded,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                isSmallScreen: isSmallScreen,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                value: '$totalLivreurs',
                label: l10n.livreurs,
                sublabel: 'Actifs',
                icon: Icons.delivery_dining_rounded,
                color:
                    AppColors.resolve(AppColors.success, AppDarkColors.success),
                isSmallScreen: isSmallScreen,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                value: '$totalRestaurants',
                label: 'Restos',
                sublabel: l10n.validated,
                icon: Icons.storefront_rounded,
                color: const Color(0xFF9B59B6),
                isSmallScreen: isSmallScreen,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Carte revenus (large, mise en valeur) ─────────────────
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.orders,
    required this.confirmed,
    required this.country,
  });

  final double revenue;
  final int orders, confirmed;
  final String country;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 400;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandLight, AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.revenue,
                  style: AppTypography.labelMedium(color: Colors.white70)
                      .copyWith(fontSize: isSmallScreen ? 10 : 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${revenue.toStringAsFixed(0)} ${CurrencyUtil.symbol(country)}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isSmallScreen ? 24 : 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$confirmed ${l10n.orders}',
                      style: AppTypography.labelMedium(color: Colors.white)
                          .copyWith(fontSize: isSmallScreen ? 9 : 11),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            width: isSmallScreen ? 44 : 56,
            height: isSmallScreen ? 44 : 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up_rounded,
                color: Colors.white, size: isSmallScreen ? 22 : 28),
          ),
        ],
      ),
    );
  }
}

// ── KPI tile compact ──────────────────────────────────────
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.isSmallScreen = false,
  });

  final String value, label, sublabel;
  final IconData icon;
  final Color color;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: 0.5,
        ),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône
          Container(
            width: isSmallScreen ? 28 : 32,
            height: isSmallScreen ? 28 : 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 14 : 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Valeur
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.headlineLarge(
                      color: AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle))
                  .copyWith(
                fontSize: isSmallScreen ? 20 : 26,
                color: AppColors.resolve(
                    AppColors.inkSubtle, AppDarkColors.inkSubtle),
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.labelMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                  .copyWith(
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w700)),
          Text(sublabel,
              style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle))
                  .copyWith(fontSize: isSmallScreen ? 9 : 10)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _ManagementNav — Sections de navigation gestion (responsif)
// ═══════════════════════════════════════════════════════════
class _ManagementNav extends StatelessWidget {
  const _ManagementNav({
    required this.userRole,
    required this.userCountry,
    required this.totalUsers,
    required this.totalRestaurants,
    required this.totalLivreurs,
    required this.newUsersMonth,
    required this.pendingCount,
    required this.onAddUser,
    required this.onAddAdmin,
    this.isSmallScreen = false,
    this.isMediumScreen = false,
    this.isLargeScreen = false,
  });

  final AppRole userRole;
  final String userCountry;
  final int totalUsers,
      totalRestaurants,
      totalLivreurs,
      newUsersMonth,
      pendingCount;
  final VoidCallback onAddUser, onAddAdmin;
  final bool isSmallScreen, isMediumScreen, isLargeScreen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Pour les petits écrans, on utilise une liste verticale
    if (isSmallScreen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.brandSurface, AppDarkColors.brandSurface),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: AppColors.brand, size: 14),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.admin_management,
                  style: AppTypography.titleMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Utilisateurs
            _NavCardResponsive(
              icon: Icons.people_rounded,
              label: l10n.users,
              count: '$totalUsers',
              sublabel: newUsersMonth > 0 ? '+$newUsersMonth ce mois' : null,
              color: Colors.blue,
              onTap: () {
                if (userRole == AppRole.superAdmin) {
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) =>
                              const CountryPage(sectionType: 'utilisateurs')));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UsersListPage(
                              country: userCountry, roleFilter: const [2, 3])));
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // Restaurants
            _NavCardResponsive(
              icon: Icons.storefront_rounded,
              label: l10n.restaurants,
              count: '$totalRestaurants',
              badge: pendingCount > 0 ? '$pendingCount' : null,
              color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
              onTap: () {
                if (userRole == AppRole.superAdmin) {
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) =>
                              CountryPage(sectionType: 'restaurants')));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              RestaurantListPage(country: userCountry)));
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // Livreurs
            _NavCardResponsive(
              icon: Icons.delivery_dining_rounded,
              label: l10n.livreurs,
              count: '$totalLivreurs',
              color:
                  AppColors.resolve(AppColors.success, AppDarkColors.success),
              onTap: () {
                if (userRole == AppRole.superAdmin) {
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) =>
                              const CountryPage(sectionType: 'livreurs')));
                } else {
                  Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const LivreurListPage()));
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // Catégories
            _NavCardResponsive(
              icon: Icons.label_outline_rounded,
              label: l10n.admin_categories,
              count: '—',
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CategoryManagementPage())),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Promotions
            _NavCardResponsive(
              icon: Icons.discount_rounded,
              label: l10n.admin_promotions,
              count: '—',
              color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PromotionsPage())),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Parrainage
            _NavCardResponsive(
              icon: Icons.people_alt_rounded,
              label: l10n.admin_referral,
              count: '—',
              color: Colors.teal,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ParrainagePage())),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Audit Log
            _NavCardResponsive(
              icon: Icons.history_rounded,
              label: l10n.auditLog,
              count: '—',
              color:
                  AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AuditLogPage(country: userCountry))),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Suppressions programmées
            _NavCardResponsive(
              icon: Icons.delete_sweep_rounded,
              label: l10n.admin_scheduled_deletions,
              count: '—',
              color: AppColors.resolve(AppColors.error, AppDarkColors.error),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ScheduledDeletionsPage(country: userCountry))),
            ),

            if (userRole == AppRole.superAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              _NavCardResponsive(
                icon: Icons.admin_panel_settings_rounded,
                label: l10n.administrators,
                count: '—',
                color: AppColors.resolve(AppColors.error, AppDarkColors.error),
                onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) =>
                            CountryPage(sectionType: 'administrateurs'))),
                onAdd: onAddAdmin,
              ),
            ],
          ],
        ),
      );
    }

    // Pour les écrans moyens et grands, on utilise une grille
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: AppColors.brand, size: 14),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.admin_management,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          ]),
          const SizedBox(height: AppSpacing.md),

          // Grille 2 colonnes
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMediumScreen ? 2 : 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 4,
            children: [
              // Utilisateurs
              _NavCardGrid(
                icon: Icons.people_rounded,
                label: l10n.users,
                count: '$totalUsers',
                sublabel: newUsersMonth > 0 ? '+$newUsersMonth ce mois' : null,
                color: Colors.blue,
                onTap: () {
                  if (userRole == AppRole.superAdmin) {
                    Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const CountryPage(
                                sectionType: 'utilisateurs')));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => UsersListPage(
                                country: userCountry,
                                roleFilter: const [2, 3])));
                  }
                },
              ),

              // Restaurants
              _NavCardGrid(
                icon: Icons.storefront_rounded,
                label: l10n.restaurants,
                count: '$totalRestaurants',
                badge: pendingCount > 0 ? '$pendingCount' : null,
                color:
                    AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                onTap: () {
                  if (userRole == AppRole.superAdmin) {
                    Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) =>
                                CountryPage(sectionType: 'restaurants')));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                RestaurantListPage(country: userCountry)));
                  }
                },
              ),

              // Livreurs
              _NavCardGrid(
                icon: Icons.delivery_dining_rounded,
                label: l10n.livreurs,
                count: '$totalLivreurs',
                color:
                    AppColors.resolve(AppColors.success, AppDarkColors.success),
                onTap: () {
                  if (userRole == AppRole.superAdmin) {
                    Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) =>
                                const CountryPage(sectionType: 'livreurs')));
                  } else {
                    Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (_) => const LivreurListPage()));
                  }
                },
              ),

              // Catégories
              _NavCardGrid(
                icon: Icons.label_outline_rounded,
                label: l10n.admin_categories,
                count: '—',
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryManagementPage())),
              ),

              // Promotions
              _NavCardGrid(
                icon: Icons.discount_rounded,
                label: l10n.admin_promotions,
                count: '—',
                color:
                    AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PromotionsPage())),
              ),

              // Parrainage
              _NavCardGrid(
                icon: Icons.people_alt_rounded,
                label: l10n.admin_referral,
                count: '—',
                color: Colors.teal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ParrainagePage())),
              ),

              // Audit Log
              _NavCardGrid(
                icon: Icons.history_rounded,
                label: l10n.auditLog,
                count: '—',
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AuditLogPage(country: userCountry))),
              ),

              // Suppressions programmées
              _NavCardGrid(
                icon: Icons.delete_sweep_rounded,
                label: l10n.admin_scheduled_deletions,
                count: '—',
                color: AppColors.resolve(AppColors.error, AppDarkColors.error),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ScheduledDeletionsPage(country: userCountry))),
              ),

              if (userRole == AppRole.superAdmin)
                _NavCardGrid(
                  icon: Icons.admin_panel_settings_rounded,
                  label: l10n.administrators,
                  count: '—',
                  color:
                      AppColors.resolve(AppColors.error, AppDarkColors.error),
                  onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) =>
                              CountryPage(sectionType: 'administrateurs'))),
                  onAdd: onAddAdmin,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Version responsive du NavCard pour petits écrans
class _NavCardResponsive extends StatelessWidget {
  const _NavCardResponsive({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.sublabel,
    this.badge,
    this.onAdd,
  });

  final IconData icon;
  final String label, count;
  final Color color;
  final VoidCallback onTap;
  final String? sublabel, badge;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [AppShadows.subtle],
        ),
        child: Row(children: [
          // Icône
          Container(
            width: isSmallScreen ? 40 : 46,
            height: isSmallScreen ? 40 : 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 18 : 22),
          ),
          const SizedBox(width: AppSpacing.md),
          // Label + sous-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelLarge(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
                if (sublabel != null)
                  Text(sublabel!,
                      style: AppTypography.bodyMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted))
                          .copyWith(fontSize: isSmallScreen ? 9 : 11)),
              ],
            ),
          ),
          // Badge en attente
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.error, AppDarkColors.error))
                      .copyWith(
                          fontSize: isSmallScreen ? 9 : 11,
                          fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // Compteur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(count,
                style: AppTypography.labelMedium(color: color).copyWith(
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.w800)),
          ),
          // Bouton ajouter
          if (onAdd != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: isSmallScreen ? 30 : 34,
                height: isSmallScreen ? 30 : 34,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.successLight, AppDarkColors.successLight),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.add_rounded,
                    color: AppColors.resolve(
                        AppColors.success, AppDarkColors.success),
                    size: isSmallScreen ? 16 : 18),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle),
              size: isSmallScreen ? 16 : 18),
        ]),
      ),
    );
  }
}

// Version grille pour écrans moyens et grands
class _NavCardGrid extends StatelessWidget {
  const _NavCardGrid({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.sublabel,
    this.badge,
    this.onAdd,
  });

  final IconData icon;
  final String label, count;
  final Color color;
  final VoidCallback onTap;
  final String? sublabel, badge;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [AppShadows.subtle],
        ),
        child: Row(children: [
          // Icône
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          // Label + sous-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelLarge(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
                if (sublabel != null)
                  Text(sublabel!,
                      style: AppTypography.bodyMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted))
                          .copyWith(fontSize: 10)),
              ],
            ),
          ),
          // Badge en attente
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.error, AppDarkColors.error))
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // Compteur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(count,
                style: AppTypography.labelMedium(color: color)
                    .copyWith(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.successLight, AppDarkColors.successLight),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.add_rounded,
                    color: AppColors.resolve(
                        AppColors.success, AppDarkColors.success),
                    size: 16),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle),
              size: 16),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _ValidationAlert — Bannière d'alerte en attente
// ═══════════════════════════════════════════════════════════
class _ValidationAlert extends StatelessWidget {
  const _ValidationAlert({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.resolve(AppColors.error, AppDarkColors.error)
                .withValues(alpha: 0.25),
            width: 1),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.error, AppDarkColors.error)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.assignment_late_rounded,
              color: AppColors.resolve(AppColors.error, AppDarkColors.error),
              size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.admin_validation_alert(count),
                style: AppTypography.labelLarge(color: AppColors.error),
              ),
              Text(
                l10n.admin_validation_subtitle,
                style: AppTypography.labelMedium(
                        color: AppColors.error.withValues(alpha: 0.75))
                    .copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _ValidationSection — Cards restaurants à valider
// ═══════════════════════════════════════════════════════════
class _ValidationSection extends StatelessWidget {
  const _ValidationSection({
    required this.pendingRestaurants,
    required this.userCountry,
    required this.onValidate,
    required this.onReject,
  });

  final List<Map<String, dynamic>> pendingRestaurants;
  final String userCountry;
  final Future<void> Function(Restaurant) onValidate;
  final Future<void> Function(Restaurant) onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        children: [
          // En-tête section
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.errorLight, AppDarkColors.errorLight),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.assignment_turned_in_rounded,
                    color:
                        AppColors.resolve(AppColors.error, AppDarkColors.error),
                    size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.admin_validation_section,
                    style: AppTypography.titleMedium(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.errorLight, AppDarkColors.errorLight),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pendingRestaurants.length}',
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.error, AppDarkColors.error))
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ),

          // Liste
          ...pendingRestaurants.take(5).map((entry) {
            final Restaurant r = entry['restaurant'];
            final String owner = entry['ownerName'];
            return _ValidationRow(
              restaurant: r,
              ownerName: owner,
              onValidate: () => onValidate(r),
              onReject: () => onReject(r),
            );
          }),

          if (pendingRestaurants.length > 5) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantListPage(country: userCountry),
                  ),
                ),
                child: Text(
                  '${l10n.restaurants} (${pendingRestaurants.length})',
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand)),
                ),
              ),
            ),
          ] else
            const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({
    required this.restaurant,
    required this.ownerName,
    required this.onValidate,
    required this.onReject,
  });

  final Restaurant restaurant;
  final String ownerName;
  final VoidCallback onValidate;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.resolve(
                AppColors.accentLight, AppDarkColors.accentLight),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.storefront_rounded,
              size: 22,
              color: AppColors.resolve(AppColors.accent, AppDarkColors.accent)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant.name,
                  style: AppTypography.labelLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(ownerName,
                  style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.inkMuted, AppDarkColors.inkMuted))
                      .copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        // Bouton rejeter
        GestureDetector(
          onTap: onReject,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.close_rounded,
                color: AppColors.resolve(AppColors.error, AppDarkColors.error),
                size: 18),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Bouton valider
        GestureDetector(
          onTap: onValidate,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.successLight, AppDarkColors.successLight),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.check_rounded,
                color:
                    AppColors.resolve(AppColors.success, AppDarkColors.success),
                size: 18),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _QuickActionsSection — 3 boutons action
// ═══════════════════════════════════════════════════════════
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.userRole,
    required this.onExport,
    required this.onRefresh,
    required this.onAddAdmin,
  });

  final AppRole userRole;
  final VoidCallback onExport, onRefresh, onAddAdmin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.accentLight, AppDarkColors.accentLight),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.flash_on_rounded,
                  color:
                      AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                  size: 14),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.admin_quick_actions,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          ]),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            if (userRole == AppRole.superAdmin) ...[
              Expanded(
                child: _ActionCard(
                  icon: Icons.person_add_rounded,
                  label: l10n.administrators,
                  color: Colors.blue,
                  onTap: onAddAdmin,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: _ActionCard(
                icon: Icons.file_download_rounded,
                label: l10n.export,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                onTap: onExport,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ActionCard(
                icon: Icons.refresh_rounded,
                label: 'Actualiser',
                color:
                    AppColors.resolve(AppColors.success, AppDarkColors.success),
                onTap: onRefresh,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [AppShadows.subtle],
        ),
        child: Column(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: AppColors.resolve(
                    AppColors.ink.withValues(alpha: 0.8), AppDarkColors.ink),
                size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label,
              style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle))
                  .copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.sublabel,
    this.badge,
    this.onAdd,
  });

  final IconData icon;
  final String label, count;
  final Color color;
  final VoidCallback onTap;
  final String? sublabel, badge;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
          boxShadow: [AppShadows.subtle],
        ),
        child: Row(children: [
          // Icône
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          // Label + sous-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelLarge(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
                if (sublabel != null)
                  Text(sublabel!,
                      style: AppTypography.bodyMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted))
                          .copyWith(fontSize: 11)),
              ],
            ),
          ),
          // Badge en attente
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                  style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.error, AppDarkColors.error))
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // Compteur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(count,
                style: AppTypography.labelMedium(color: color)
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          // Bouton ajouter
          if (onAdd != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.successLight, AppDarkColors.successLight),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.add_rounded,
                    color: AppColors.resolve(
                        AppColors.success, AppDarkColors.success),
                    size: 18),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle),
              size: 18),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets utilitaires
// ═══════════════════════════════════════════════════════════

class _ExportTile extends StatelessWidget {
  const _ExportTile(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.resolve(
              AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(label,
              style: AppTypography.labelMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle),
              size: 16),
        ]),
      ),
    );
  }
}

class _DlgField extends StatelessWidget {
  const _DlgField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type,
  });
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? type;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}
