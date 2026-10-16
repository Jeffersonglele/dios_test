import 'package:dios_delices/screens/settings/settings.dart';
import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/screens/restaurants/restaurant_earnings_page.dart';
import 'package:dios_delices/screens/restaurants/restaurant_form_page.dart';
import 'package:dios_delices/screens/contact/contact_page.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/services/restaurant_revenue_service.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../db/database_helper.dart';
import '../../services/node_auth_service.dart';

import '../../widgets/logout.dart';
import '../orders/user_orders_page.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/livreur_earnings_page.dart';
import '../../services/session_service.dart';
import '../../utils/toast.dart';
import '../restaurants/pro_request_page.dart';

class MyStore extends StatefulWidget {
  const MyStore({super.key});
  @override
  State<MyStore> createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  String _localizedLabel(String label, AppLocalizations l10n) {
    const map = {
      'Mes livraisons': 'myDeliveries',
      'Mes revenus': 'store_my_earnings',
      'Rayon de livraison': 'store_delivery_radius',
      'Devenir vendeur': 'store_become_seller',
      'Mes commandes': 'store_my_orders',
      'Nous contacter': 'store_contact_us',
      'Paramètres': 'settings',
      'Déconnexion': 'logout',
      'Mon restaurant': 'store_my_restaurant',
      'Continuer ma demande': 'store_continue_request',
      'Annuler la demande': 'store_cancel_request',
      'Modifier mon restaurant': 'store_edit_restaurant',
      'Devenir Pro': 'store_become_pro',
    };
    final key = map[label];
    if (key == null) return label;
    // Use a map of getters for dynamic dispatch
    final getters = <String, String Function()>{
      'myDeliveries': () => l10n.myDeliveries,
      'store_my_earnings': () => l10n.store_my_earnings,
      'store_delivery_radius': () => l10n.store_delivery_radius,
      'store_become_seller': () => l10n.store_become_seller,
      'store_my_orders': () => l10n.store_my_orders,
      'store_contact_us': () => l10n.store_contact_us,
      'settings': () => l10n.settings,
      'logout': () => l10n.logout,
      'store_my_restaurant': () => l10n.store_my_restaurant,
      'store_continue_request': () => l10n.store_continue_request,
      'store_cancel_request': () => l10n.store_cancel_request,
      'store_edit_restaurant': () => l10n.store_edit_restaurant,
      'store_become_pro': () => l10n.store_become_pro,
    };
    return getters[key]!();
  }

  List<_StoreSection> sections = [];
  Restaurant? _restaurant;
  Users? _currentUser;
  int _restoState = 0;
  int _sellerRestaurantStatus = -1;
  int _serverRestaurantId = 0;
  bool _restaurantIsPro = false;
  String _sellerRemark = '';
  bool _isVerified = false;

  /// Revenus du mois, affichés pour un restaurateur validé.
  RevenueSummary? _revenue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final serverState = await SessionService.fetchServerAccountState();
    final allUsers = await Users.fetchUsersFromDB();
    final currentUser = Users.getUsersByUserId(allUsers, session.userId);
    _currentUser = currentUser;
    final userRole = AppRole.fromId(currentUser?.roleID);
    _isVerified = currentUser?.identity == 'Verified';

    _sellerRestaurantStatus = serverState?.restaurantValid ?? -1;
    _serverRestaurantId = serverState?.restaurantId ?? 0;
    _restaurantIsPro = serverState?.restaurantIsPro ?? false;
    _sellerRemark = serverState?.restaurantRemark ?? '';

    if (userRole.isDelivery && currentUser != null) {
      final settings = await LivreurApi.getSettings(session.userId);
      if (settings != null) {
        currentUser.isOnline = settings['isOnline'] == true;
      }
    }

    // Le restaurant peut exister avant la promotion du compte : il représente
    // alors la demande vendeur en attente ou refusée.
    if (serverState?.restaurantId != null && serverState!.restaurantId > 0) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      _restaurant = Restaurant.getRestaurantByRestaurantId(
          restaurants, serverState.restaurantId);
      _restoState = _restaurant?.valid ?? serverState.restaurantValid;
    } else if (userRole.isProfessional && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      _restaurant = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoState = _restaurant?.valid ?? 0;
    }

    if (_restaurant == null && session.userId > 0) {
      _restaurant = await Restaurant.fetchRestaurantByUserIdFromAPI(session.userId);
      if (_restaurant != null) {
        _restoState = _restaurant!.valid;
      }
    }

    // Build sections based on role
    List<_StoreSection> newSections = [];

    if (userRole.isProfessional) {
      _buildVendreSection(newSections, session);
    } else if (userRole.isDelivery) {
      newSections.add(_StoreSection(Icons.delivery_dining_rounded,
          'Mes livraisons', const DeliveryDashboard()));
      newSections.add(_StoreSection(Icons.monetization_on_rounded,
          'Mes revenus', const LivreurEarningsPage()));
      newSections.add(_StoreSection(
          Icons.map_rounded, 'Rayon de livraison', null,
          action: () => _showDistanceConfig(currentUser)));
    } else {
      // Demande vendeur en cours (0) ou refusée (2) : on la reprend au lieu
      // d'en créer une nouvelle.
      final hasRequest =
          _sellerRestaurantStatus == 0 || _sellerRestaurantStatus == 2;
      newSections.add(_StoreSection(
          hasRequest ? Icons.edit_note_rounded : Icons.storefront_rounded,
          hasRequest ? 'Continuer ma demande' : 'Devenir vendeur',
          null,
          isSellerRequest: true));
      if (hasRequest) {
        newSections.add(_StoreSection(
            Icons.cancel_rounded, 'Annuler la demande', null,
            action: _cancelDemande));
      }
      newSections.add(_StoreSection(Icons.receipt_long_rounded, 'Mes commandes',
          const UserOrdersPage(showRestaurantOrders: false)));
    }

    // Common sections for all users
    newSections.add(_StoreSection(
        Icons.contact_support_rounded, 'Nous contacter', const ContactPage(),
        group: _StoreGroup.account));
    newSections.add(_StoreSection(
        Icons.settings_rounded, 'Paramètres', const Settings(),
        group: _StoreGroup.account));
    newSections.add(_StoreSection(Icons.logout_rounded, 'Déconnexion', null,
        isLogout: true));

    if (!mounted) return;
    setState(() => sections = newSections);
    if (userRole.isProfessional && _restoState == 1) {
      await _loadRevenue();
    } else if (_revenue != null) {
      setState(() => _revenue = null);
    }
  }

  Future<void> _loadRevenue() async {
    try {
      final summary = await RestaurantRevenueService.currentMonth();
      if (mounted) setState(() => _revenue = summary);
    } catch (_) {}
  }

  void _buildVendreSection(List<_StoreSection> newSections, session) {
    switch (_restoState) {
      case 0: // pending validation
      case 2: // refusée : corriger puis renvoyer
        newSections.add(_StoreSection(
            Icons.edit_note_rounded, 'Continuer ma demande', null,
            action: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RestaurantFormPage(restaurant: _restaurant))).then((_) => _load())));
        newSections.add(_StoreSection(
            Icons.cancel_rounded, 'Annuler la demande', null,
            action: _cancelDemande));
        newSections.add(_StoreSection(
            Icons.receipt_long_rounded,
            'Mes commandes',
            const UserOrdersPage(showRestaurantOrders: false)));
        break;
      case 1: // validated
        newSections.add(_StoreSection(
            Icons.storefront_rounded,
            'Mon restaurant',
            RestaurantDetails(
                restaurant_id:
                    _restaurant?.restaurantID ?? session.restaurantId ?? 0)));
        newSections.add(_StoreSection(
            Icons.edit_rounded, 'Modifier mon restaurant', null,
            action: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RestaurantFormPage(restaurant: _restaurant))).then((_) => _load())));
        newSections.add(_StoreSection(Icons.monetization_on_rounded,
            'Mes revenus', const RestaurantEarningsPage()));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes', const UserOrdersPage(showRestaurantOrders: true)));
        if (!(_restaurantIsPro || (_restaurant?.isPro ?? false))) {
          newSections.add(_StoreSection(
              Icons.workspace_premium_rounded, 'Devenir Pro', null,
              action: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProRequestPage()))
                  .then((_) => _load())));
        }
        break;
      default:
        newSections.add(
            _StoreSection(Icons.storefront_rounded, 'Mon restaurant', null));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes', const UserOrdersPage(showRestaurantOrders: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activity = sections
        .where((s) => s.group == _StoreGroup.activity && !s.isLogout)
        .toList();
    final account =
        sections.where((s) => s.group == _StoreGroup.account).toList();
    final logout = sections.where((s) => s.isLogout).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l10n.mySpace,
                      style: AppTypography.headlineLarge(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink))),
                ),
                const SizedBox(height: 16),
                if (_currentUser != null && _currentUser!.roleID != 5) ...[
                  _buildProfileCard(_currentUser!),
                  const SizedBox(height: 12),
                ],
                if ((_currentUser?.roleID == 2 || _currentUser?.roleID == 3) &&
                    (_sellerRestaurantStatus == 0 ||
                        _sellerRestaurantStatus == 2)) ...[
                  _buildSellerRequestBanner(),
                  const SizedBox(height: 12),
                ],
                if (_currentUser?.roleID == 5) ...[
                  _buildDriverInfoCard(_currentUser!),
                  const SizedBox(height: 12),
                ],
                if (_revenue != null) ...[
                  _buildRevenueCard(_revenue!),
                  const SizedBox(height: 12),
                ],
                if (activity.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _groupTitle(l10n.store_section_activity),
                  _buildGroup(activity, l10n),
                ],
                if (account.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _groupTitle(l10n.store_section_account),
                  _buildGroup(account, l10n),
                ],
                if (logout.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildLogoutButton(logout.first, l10n),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.labelMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      );

  /// Sections regroupées dans une seule carte, séparées par un filet.
  Widget _buildGroup(List<_StoreSection> items, AppLocalizations l10n) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final subtle =
        AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.8)),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 68, color: border.withValues(alpha: 0.6)),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _openSection(sections.indexOf(items[i])),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(items[i].icon, color: brand, size: 21),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _localizedLabel(items[i].label, l10n),
                        style: AppTypography.titleSmall(color: ink),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: subtle),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton(_StoreSection s, AppLocalizations l10n) {
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _openSection(sections.indexOf(s)),
        icon: Icon(s.icon, color: error, size: 20),
        label: Text(_localizedLabel(s.label, l10n),
            style: AppTypography.labelLarge(color: error)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: error.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    );
  }

  String _roleLabel(Users user, AppLocalizations l10n) {
    final role = AppRole.fromId(user.roleID);
    if (role.isAdmin) return l10n.store_role_admin;
    if (role.isProfessional) return l10n.store_role_restaurateur;
    if (role.isDelivery) return l10n.store_role_courier;
    return l10n.store_role_client;
  }

  Widget _buildProfileCard(Users user) {
    final l10n = AppLocalizations.of(context)!;
    final name = '${user.firstname} ${user.lastname}'.trim();
    final displayName = name.isEmpty ? user.username : name;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final initials = [user.firstname, user.lastname]
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                .withValues(alpha: 0.8)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.resolve(
              AppColors.brandSurface, AppDarkColors.brandSurface),
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: AppTypography.titleSmall(color: brand),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(
                          AppColors.ink, AppDarkColors.ink))),
              if (user.email.isNotEmpty)
                Text(user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(_roleLabel(user, l10n),
              style: AppTypography.labelMedium(color: brand)
                  .copyWith(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  /// Revenus du mois (restaurateur validé) — même calcul que la page
  /// « Mes revenus » et le tableau de bord.
  Widget _buildRevenueCard(RevenueSummary r) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final deep = Color.lerp(brand, Colors.black, 0.25)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, deep],
        ),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.28),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantEarningsPage()),
          ).then((_) => _loadRevenue()),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.insights_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.store_revenue_month,
                        style: AppTypography.labelMedium(
                                color: Colors.white.withValues(alpha: 0.9))
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (r.toProcess > 0)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const UserOrdersPage(showRestaurantOrders: true),
                        ),
                      ).then((_) => _loadRevenue()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(l10n.store_revenue_to_process(r.toProcess),
                            style: AppTypography.labelMedium(color: brand)
                                .copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtil.formatPrice(r.revenue, r.country),
                    style: AppTypography.headlineLarge(color: Colors.white)
                        .copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.store_revenue_delivered(r.deliveredOrders),
                  style: AppTypography.bodyMedium(
                      color: Colors.white.withValues(alpha: 0.9)),
                ),
                if (r.inProgress > 0)
                  Text(
                    l10n.store_revenue_in_progress(
                        CurrencyUtil.formatPrice(r.inProgress, r.country)),
                    style: AppTypography.bodySmall(
                        color: Colors.white.withValues(alpha: 0.8)),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  Text(l10n.see_all,
                      style: AppTypography.labelMedium(color: Colors.white)
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(Users user) {
    final name = '${user.firstname} ${user.lastname}'.trim();
    final displayName = name.isEmpty ? user.username : name;
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.resolve(
                AppColors.brandSurface, AppDarkColors.brandSurface),
            child: Icon(Icons.delivery_dining_rounded,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium().copyWith(
                        fontSize: 19,
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
                if (user.email.isNotEmpty)
                  Text(user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(color: muted)),
                if (user.telephone.isNotEmpty)
                  Text(user.telephone,
                      style: AppTypography.bodySmall(color: muted)),
                const SizedBox(height: 4),
                Text('Livreur • ${user.isOnline ? 'En ligne' : 'Hors ligne'}',
                    style: AppTypography.labelMedium(
                        color: user.isOnline
                            ? AppColors.success
                            : AppColors.error)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle)),
        ],
      ),
    );
  }

  void _openSection(int index) {
    final s = sections[index];
    if (s.isLogout) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LogoutFormDialog());
      return;
    }
    if (s.isSellerRequest) {
      if (!_isVerified) {
        _showUnverifiedDialog();
      } else {
        _showBecomeRestaurateurDialog();
      }
      return;
    }
    if (s.action != null) {
      s.action!();
      return;
    }
    if (s.page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.store_no_restaurant_data)),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => s.page!));
  }

  Future<void> _showUnverifiedDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.accentLight, AppDarkColors.accentLight),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.hourglass_bottom_rounded,
                color:
                    AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                size: 18),
          ),
          const SizedBox(width: 10),
          Text(l10n.store_unverified_title,
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(l10n.store_unverified_body,
            style: AppTypography.bodyLarge(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showBecomeRestaurateurDialog() async {
    final l10n = AppLocalizations.of(context)!;
    // Une demande existe déjà : on ouvre directement le formulaire.
    final confirmed = _restaurant != null ? true : await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.restaurant_menu_outlined,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 18),
          ),
          const SizedBox(width: 10),
          Text(l10n.store_become_restaurateur_title,
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(
          l10n.store_become_restaurateur_body,
          style: AppTypography.bodyLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              foregroundColor:
                  AppColors.resolve(AppColors.surface, AppDarkColors.surface),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.store_yes_sell),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantFormPage(
            restaurant: _restaurant,
            sellerApplication: true,
          ),
        ),
      );
      if (submitted == true && mounted) {
        await _load();
      }
    }
  }

  Widget _buildSellerRequestBanner() {
    final rejected = _sellerRestaurantStatus == 2;
    final color = rejected ? AppColors.error : AppColors.accent;
    final background = rejected ? AppColors.errorLight : AppColors.accentLight;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.resolve(background, background),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(rejected ? Icons.error_outline : Icons.hourglass_bottom,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rejected
                  ? 'Votre demande vendeur a été refusée.${_sellerRemark.isNotEmpty ? '\nMotif : $_sellerRemark' : ''}'
                  : 'Votre demande vendeur est en attente de validation par l’administrateur.',
              style: AppTypography.bodyMedium(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDemande() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text(l10n.store_cancel_request_title,
              style: AppTypography.titleMedium().copyWith(
                  fontSize: 16,
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        ]),
        content: Text(
          l10n.store_cancel_request_body,
          style: AppTypography.bodyLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.store_yes_cancel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final restaurantId = _restaurant?.restaurantID ?? _serverRestaurantId;
    final token = await SessionService.readNodeToken();
    if (restaurantId <= 0 || token == null) {
      if (mounted) Toast(context, l10n.store_no_restaurant_data, false);
      return;
    }
    try {
      final session = await SessionService.readSession();
      // Retire la demande vendeur ; le serveur repasse le compte en client
      // et renvoie un jeton portant le nouveau rôle.
      final response = await NodeAuthService.deleteJson(
          '/restaurants/legacy/$restaurantId',
          token: token);
      final meta = response['meta'];
      final newToken = meta is Map ? meta['token']?.toString() : null;
      final roleId = meta is Map ? int.tryParse('${meta['roleId']}') : null;
      final role = roleId != null ? AppRole.fromId(roleId) : session.role;
      if (newToken != null && newToken.isNotEmpty) {
        await SessionService.saveNodeSession(
          token: newToken,
          userId: session.userId,
          role: role,
          country: session.country,
          email: session.email,
        );
      } else {
        await SessionService.saveUserSession(
          userId: session.userId,
          role: role,
          country: session.country,
          email: session.email,
        );
      }
      await DatabaseHelper.updateCountryAndRole(
          session.userId, session.country, role.id);
      try {
        await DatabaseHelper.deleteRestaurant(restaurantId);
      } catch (_) {}
      _restaurant = null;
      _restoState = 0;
      if (!mounted) return;
      Toast(context, l10n.store_request_cancelled, true);
      if (role != session.role) {
        // Le compte change d'espace : retour à l'accueil client.
        Users.chooseCurvedNavigation(role.id, session.country, context);
      } else {
        await _load();
      }
    } on NodeAuthException catch (e) {
      if (mounted) Toast(context, '${l10n.error} : ${e.message}', false);
    } catch (_) {
      if (mounted) Toast(context, l10n.error, false);
    }
  }

  void _showDistanceConfig(Users? currentUser) {
    final l10n = AppLocalizations.of(context)!;
    double distance =
        (currentUser?.maxDeliveryDistance?.toDouble() ?? 10).clamp(1.0, 10.0);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.map_rounded,
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 18),
            ),
            const SizedBox(width: 10),
            Text(l10n.store_delivery_radius,
                style: AppTypography.titleMedium().copyWith(fontSize: 16)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.store_max_distance(distance.toStringAsFixed(0)),
                  style: AppTypography.bodyLarge(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink))
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: distance,
                  min: 1,
                  max: 10,
                  divisions: 18,
                  activeColor:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  label: '${distance.toStringAsFixed(0)} km',
                  onChanged: (v) => setInnerState(() => distance = v),
                ),
                const SizedBox(height: 8),
                Text(l10n.store_max_distance_limit,
                    style: AppTypography.bodyMedium(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final s = await SessionService.readSession();
                final ok = await LivreurApi.updateMaxDeliveryDistance(
                    s.userId, distance);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  if (ok) {
                    Toast(
                        context,
                        l10n.store_radius_updated(distance.toStringAsFixed(0)),
                        true);
                    _load();
                  } else {
                    Toast(context, l10n.store_update_error, false);
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StoreGroup { activity, account }

class _StoreSection {
  final IconData icon;
  final String label;
  final Widget? page;
  final bool isLogout;
  final bool isSellerRequest;
  final VoidCallback? action;
  final _StoreGroup group;
  const _StoreSection(this.icon, this.label, this.page,
      {this.isLogout = false,
      this.isSellerRequest = false,
      this.action,
      this.group = _StoreGroup.activity});
}
