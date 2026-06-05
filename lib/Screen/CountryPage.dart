import 'package:dios_delices/Screen/livreur/LivreurListPage.dart';
import 'package:dios_delices/Screen/utilisateurs/UsersListPage.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'restaurants/RestaurantListPage.dart';

class CountryPage extends StatelessWidget {
  final String sectionType;

  const CountryPage({super.key, required this.sectionType});

  @override
  Widget build(BuildContext context) {
    final countries = [
      _CountryData("France", "🇫🇷"),
      _CountryData("Côte d'Ivoire", "🇨🇮"),
      _CountryData("Bénin", "🇧🇯"),
    ];

    String title;
    IconData icon;
    Color iconColor;
    if (sectionType == "utilisateurs") {
      title = "Utilisateurs";
      icon = Icons.people_rounded;
      iconColor = Colors.blue;
    } else if (sectionType == "administrateurs") {
      title = "Administrateurs";
      icon = Icons.admin_panel_settings_rounded;
      iconColor = AppColors.error;
    } else if (sectionType == "livreurs") {
      title = "Livreurs";
      icon = Icons.delivery_dining_rounded;
      iconColor = AppColors.success;
    } else {
      title = "Restaurants";
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
            Text('Gestion $title'),
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
              'Sélectionnez un pays',
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
                        if (sectionType == "utilisateurs" || sectionType == "administrateurs") {
                          return UsersListPage(
                            country: c.name,
                            roleFilter: sectionType == "administrateurs" ? [1, 4] : null,
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
                            'Voir les $title en ${c.name}',
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
