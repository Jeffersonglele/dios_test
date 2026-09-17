import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.contact),
        backgroundColor:
            AppColors.resolve(AppColors.brand, AppDarkColors.brand),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.support_agent,
              size: 64,
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
          const SizedBox(height: 16),
          Text(
            l10n.contact_need_help,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.contact_description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          _ContactTile(
            icon: Icons.email,
            title: l10n.email,
            subtitle: 'contact@diosdelices.com',
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'contact@diosdelices.com',
                queryParameters: {
                  'subject': 'Support Dios Délices',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.phone,
            title: l10n.phone,
            subtitle: '+229 01 23 45 67 89',
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: '+2290123456789');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.chat,
            title: l10n.chat,
            subtitle: l10n.contact_chat_hours,
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.contact_chat_soon),
                  backgroundColor:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: AppColors.resolve(AppColors.card, AppDarkColors.card),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.resolve(
              AppColors.brandSurface, AppDarkColors.brandSurface),
          child: Icon(icon,
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        subtitle: Text(subtitle,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7))),
        trailing: Icon(Icons.chevron_right,
            color: colorScheme.onSurface.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }
}
