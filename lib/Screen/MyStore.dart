import 'package:dios_delices/Screen/Settings.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantFormPage.dart';
import 'package:dios_delices/Screen/ContactPage.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../components/Logout.dart';
import 'UserOrdersPage.dart';
import '../services/session_service.dart';

class MyStore extends StatefulWidget {
  const MyStore({super.key});
  @override
  State<MyStore> createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  List<_StoreSection> sections = [];
  Restaurant? _restaurant;
  int _restoState = 0;

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

    // Fetch restaurant if user is professional
    if (userRole.isProfessional && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      _restaurant = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoState = _restaurant?.valid ?? 0;
    }

    // Build sections based on role
    List<_StoreSection> newSections = [];

    // Only show restaurateur sections if user is microRestaurant
    if (userRole.isProfessional) {
      _buildVendreSection(newSections, session);
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
            Icons.hourglass_bottom_rounded, 'Mon restaurant', null));
        newSections.add(_StoreSection(
            Icons.arrow_forward_rounded, 'Continuer ma demande', null));
        newSections.add(_StoreSection(
            Icons.cancel_rounded, 'Annuler la demande', null));
        break;
      case 1: // validated
        newSections.add(_StoreSection(
            Icons.storefront_rounded,
            'Mon restaurant',
            RestaurantDetails(restaurant_id: session.restaurantId!)));
        newSections.add(_StoreSection(
            Icons.edit_rounded, 'Modifier mon restaurant',
            RestaurantFormPage()));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes',
            const UserOrdersPage(showRestaurantOrders: true)));
        newSections.add(_StoreSection(Icons.workspace_premium_rounded,
            'Devenir Pro', null));
        break;
      default:
        newSections.add(
            _StoreSection(Icons.storefront_rounded, 'Mon restaurant', null));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes',
            const UserOrdersPage(showRestaurantOrders: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Mon espace', style: AppTypography.headlineLarge()),
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
                        color:
                            s.isLogout ? AppColors.errorLight : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: s.isLogout
                                ? AppColors.error.withValues(alpha: 0.12)
                                : AppColors.brandSurface,
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
                          child: Text(s.label,
                              style: AppTypography.titleMedium().copyWith(
                                  fontSize: 19,
                                  color: s.isLogout
                                      ? AppColors.error
                                      : AppColors.ink)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.inkSubtle),
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
    if (s.page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée de restaurant.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => s.page!));
  }
}

class _StoreSection {
  final IconData icon;
  final String label;
  final Widget? page;
  final bool isLogout;
  const _StoreSection(this.icon, this.label, this.page,
      {this.isLogout = false});
}
