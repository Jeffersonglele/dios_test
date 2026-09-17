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
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

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
  int _restoState = 0;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final allUsers = await Users.fetchUsersFromDB();
    final currentUser = Users.getUsersByUserId(allUsers, session.userId);
    final userRole = AppRole.fromId(currentUser?.roleID);
    _isVerified = currentUser?.identity == 'Verified';

    // Fetch restaurant if user is professional
    if (userRole.isProfessional && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      _restaurant = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoState = _restaurant?.valid ?? 0;
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
      newSections.add(_StoreSection(
          Icons.storefront_rounded, 'Devenir vendeur', null,
          isSellerRequest: true));
      newSections.add(_StoreSection(Icons.receipt_long_rounded, 'Mes commandes',
          const UserOrdersPage(showRestaurantOrders: false)));
    }

    // Common sections for all users
    newSections.add(_StoreSection(
        Icons.contact_support_rounded, 'Nous contacter', const ContactPage()));
    newSections.add(
        _StoreSection(Icons.settings_rounded, 'Paramètres', const Settings()));
    newSections.add(_StoreSection(Icons.logout_rounded, 'Déconnexion', null,
        isLogout: true));

    if (!mounted) return;
    setState(() => sections = newSections);
  }

  void _buildVendreSection(List<_StoreSection> newSections, session) {
    switch (_restoState) {
      case 0: // pending validation
        newSections.add(_StoreSection(
            Icons.hourglass_bottom_rounded, 'Mon restaurant', null,
            action: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RestaurantFormPage(restaurant: _restaurant)))));
        newSections.add(_StoreSection(
            Icons.arrow_forward_rounded, 'Continuer ma demande', null,
            action: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RestaurantFormPage(restaurant: _restaurant)))));
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
            RestaurantDetails(restaurant_id: session.restaurantId!)));
        newSections.add(_StoreSection(
            Icons.edit_rounded,
            'Modifier mon restaurant',
            RestaurantFormPage(restaurant: _restaurant)));
        newSections.add(_StoreSection(Icons.monetization_on_rounded,
            'Mes revenus', const RestaurantEarningsPage()));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes', const UserOrdersPage(showRestaurantOrders: true)));
        newSections.add(_StoreSection(
            Icons.workspace_premium_rounded, 'Devenir Pro', null,
            action: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProRequestPage()))));
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
          child: Column(children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(l10n.mySpace,
                  style: AppTypography.headlineLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final s = sections[i];
                  return GestureDetector(
                    onTap: () => _openSection(i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: s.isLogout
                            ? AppColors.resolve(
                                AppColors.errorLight, AppDarkColors.errorLight)
                            : AppColors.resolve(
                                AppColors.card, AppDarkColors.card),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.resolve(
                                AppColors.border, AppDarkColors.border),
                            width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: s.isLogout
                                ? AppColors.resolve(
                                    AppColors.error.withValues(alpha: 0.12),
                                    AppDarkColors.error.withValues(alpha: 0.12))
                                : AppColors.resolve(AppColors.brandSurface,
                                    AppDarkColors.brandSurface),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(s.icon,
                              color: s.isLogout
                                  ? AppColors.error
                                  : AppColors.brand,
                              size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(_localizedLabel(s.label, l10n),
                              style: AppTypography.titleMedium().copyWith(
                                  fontSize: 19,
                                  color: s.isLogout
                                      ? AppColors.error
                                      : AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink))),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.resolve(
                                AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
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
        content:
            Text(l10n.store_unverified_body, style: AppTypography.bodyLarge()),
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
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
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
      final session = await SessionService.readSession();
      final cloudFunction = ParseCloudFunction('update1User');
      final response = await cloudFunction.execute(parameters: {
        'userID': session.userId,
        'roleID': 3,
        'identity': 'Verified',
      });

      if (mounted && response.success) {
        final result = response.result as Map<String, dynamic>?;
        if (result?['success'] == true) {
          final updatedSession =
              session.copyWith(role: AppRole.microRestaurant);
          await SessionService.saveUserSession(
            userId: updatedSession.userId,
            role: updatedSession.role,
            country: updatedSession.country,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantFormPage(),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('${l10n.error} : ${result?['error'] ?? 'inconnue'}'),
              backgroundColor: AppColors.error,
            ));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${l10n.error} : ${response.error?.message}'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
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
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(
          l10n.store_cancel_request_body,
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no,
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
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

    if (confirmed == true && mounted) {
      final session = await SessionService.readSession();
      final cloudFunction = ParseCloudFunction('update1User');
      final response = await cloudFunction.execute(parameters: {
        'userID': session.userId,
        'roleID': 1,
        'identity': 'Verified',
      });

      if (mounted && response.success) {
        final result = response.result as Map<String, dynamic>?;
        if (result?['success'] == true) {
          final updatedSession = session.copyWith(role: AppRole.individual);
          await SessionService.saveUserSession(
            userId: updatedSession.userId,
            role: updatedSession.role,
            country: updatedSession.country,
          );
          if (mounted) {
            Toast(context, l10n.store_request_cancelled, true);
            _load();
          }
        } else {
          if (mounted) {
            Toast(context, '${l10n.error} : ${result?['error'] ?? 'inconnue'}',
                false);
          }
        }
      } else {
        if (mounted) {
          Toast(context, '${l10n.error} : ${response.error?.message}', false);
        }
      }
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
                  style: AppTypography.bodyLarge()
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

class _StoreSection {
  final IconData icon;
  final String label;
  final Widget? page;
  final bool isLogout;
  final bool isSellerRequest;
  final VoidCallback? action;
  const _StoreSection(this.icon, this.label, this.page,
      {this.isLogout = false, this.isSellerRequest = false, this.action});
}
