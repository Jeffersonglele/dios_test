import 'package:dios_delices/screens/delivery/livreur_list_page.dart';
import 'package:dios_delices/screens/users/users_list_page.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../restaurants/restaurant_list_page.dart';
import '../../utils/country_util.dart';

class CountryPage extends StatelessWidget {
  final String sectionType;

  const CountryPage({super.key, required this.sectionType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countries = [
      _CountryData(CountryUtil.rdc, "🇨🇩"),
      if (CountryUtil.allowBeninTestMode)
        _CountryData(CountryUtil.benin, "🇧🇯"),
    ];

    String title;
    IconData icon;
    Color iconColor;
    if (sectionType == "utilisateurs") {
      title = l10n.users;
      icon = Icons.people_rounded;
      iconColor = Colors.blue;
    } else if (sectionType == "administrateurs") {
      title = l10n.administrators;
      icon = Icons.admin_panel_settings_rounded;
      iconColor = AppColors.error;
    } else if (sectionType == "livreurs") {
      title = l10n.livreurs;
      icon = Icons.delivery_dining_rounded;
      iconColor = AppColors.success;
    } else {
      title = l10n.restaurants;
      icon = Icons.storefront_rounded;
      iconColor = AppColors.accent;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(l10n.country_title(title)),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.country_select_hint,
              style: AppTypography.titleMedium().copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            ...countries.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        if (sectionType == "utilisateurs") {
                          return UsersListPage(
                            country: c.name,
                            roleFilter: const [2, 3],
                          );
                        } else if (sectionType == "administrateurs") {
                          return UsersListPage(
                            country: c.name,
                            roleFilter: const [1, 4],
                          );
                        } else if (sectionType == "livreurs") {
                          return LivreurListPage(country: c.name);
                        } else {
                          return RestaurantListPage(country: c.name);
                        }
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border, width: 0.5),
                    boxShadow: AppShadows.cardList,
                  ),
                  child: Row(children: [
                    Text(c.flag, style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: AppTypography.titleMedium().copyWith(fontSize: 17)),
                          const SizedBox(height: 2),
                          Text(
                            l10n.country_view(title, c.name),
                            style: AppTypography.bodyMedium().copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.arrow_forward_rounded, color: iconColor, size: 18),
                    ),
                  ]),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _CountryData {
  final String name;
  final String flag;
  const _CountryData(this.name, this.flag);
}
