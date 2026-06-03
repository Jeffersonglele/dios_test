import 'package:dios_delices/Screen/Settings.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/Screen/ContactPage.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../components/Logout.dart';
import '../utils/strings.dart';
import 'UserOrdersPage.dart';
import '../services/session_service.dart';

class MyStore extends StatefulWidget {
  const MyStore({super.key});
  @override
  State<MyStore> createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  late List<_StoreSection> sections;

  @override
  void initState() {
    super.initState();
    sections = [
      _StoreSection(Icons.storefront_rounded, Strings.myRestaurant, null),
      _StoreSection(Icons.receipt_long_rounded, Strings.myOrders, const UserOrdersPage(showRestaurantOrders: true)),
      _StoreSection(Icons.contact_support_rounded, Strings.contactUs, const ContactPage()),
      _StoreSection(Icons.settings_rounded, Strings.settings, const Settings()),
      _StoreSection(Icons.logout_rounded, Strings.logout, null, isLogout: true),
    ];
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    if (session.restaurantId != null) {
      setState(() => sections[0] = _StoreSection(
        Icons.storefront_rounded, Strings.myRestaurant,
        RestaurantDetails(restaurant_id: session.restaurantId!)));
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
              child: Text(Strings.mySpace, style: AppTypography.headlineLarge()),
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
                        color: s.isLogout ? AppColors.errorLight : AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: s.isLogout ? AppColors.error.withValues(alpha: 0.12) : AppColors.brandSurface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(s.icon, color: s.isLogout ? AppColors.error : AppColors.brand, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(s.label,
                              style: AppTypography.titleMedium().copyWith(
                                  fontSize: 19,
                                  color: s.isLogout ? AppColors.error : AppColors.ink)),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
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
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const LogoutFormDialog());
      return;
    }
    if (s.page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.noRestaurantData)),
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
  const _StoreSection(this.icon, this.label, this.page, {this.isLogout = false});
}
