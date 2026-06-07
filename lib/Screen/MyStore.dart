import 'package:dios_delices/Screen/Settings.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantFormPage.dart';
import 'package:dios_delices/Screen/ContactPage.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../components/Logout.dart';
import 'UserOrdersPage.dart';
import '../services/session_service.dart';
import '../../utils/toast.dart';

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
    } else {
      newSections.add(_StoreSection(
          Icons.storefront_rounded, 'Devenir vendeur', null, isSellerRequest: true));
      newSections.add(_StoreSection(Icons.receipt_long_rounded,
          'Mes commandes',
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
            action: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => RestaurantFormPage(restaurant: _restaurant)))));
        newSections.add(_StoreSection(
            Icons.arrow_forward_rounded, 'Continuer ma demande', null,
            action: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => RestaurantFormPage(restaurant: _restaurant)))));
        newSections.add(_StoreSection(
            Icons.cancel_rounded, 'Annuler la demande', null,
            action: _cancelDemande));
        newSections.add(_StoreSection(Icons.receipt_long_rounded,
            'Mes commandes',
            const UserOrdersPage(showRestaurantOrders: false)));
        break;
      case 1: // validated
        newSections.add(_StoreSection(
            Icons.storefront_rounded,
            'Mon restaurant',
            RestaurantDetails(restaurant_id: session.restaurantId!)));
        newSections.add(_StoreSection(
            Icons.edit_rounded, 'Modifier mon restaurant',
            RestaurantFormPage(restaurant: _restaurant)));
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
    if (s.isSellerRequest) {
      _showBecomeRestaurateurDialog();
      return;
    }
    if (s.action != null) {
      s.action!();
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
  Future<void> _showBecomeRestaurateurDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.restaurant_menu_outlined,
                color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Devenir micro-restaurateur',
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(
          'En devenant micro-restaurateur, vous pourrez publier vos plats et les vendre directement aux clients. '
          'Souhaitez-vous continuer ?',
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
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
            child: Text('Oui, je veux vendre mes plats'),
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
          final updatedSession = session.copyWith(role: AppRole.microRestaurant);
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
              content: Text('Erreur : ${result?['error'] ?? 'inconnue'}'),
              backgroundColor: AppColors.error,
            ));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur : ${response.error?.message}'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  Future<void> _cancelDemande() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Annuler la demande',
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(
          'Êtes-vous sûr de vouloir annuler votre demande de création de restaurant ? '
          'Toutes les informations saisies seront perdues.',
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Non',
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
            child: Text('Oui, annuler'),
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
            Toast(context, 'Demande annulée.', true);
            _load();
          }
        } else {
          if (mounted) {
            Toast(context, 'Erreur : ${result?['error'] ?? 'inconnue'}', false);
          }
        }
      } else {
        if (mounted) {
          Toast(context, 'Erreur : ${response.error?.message}', false);
        }
      }
    }
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
