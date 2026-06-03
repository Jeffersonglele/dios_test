import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nous contacter'),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.support_agent,
            size: 64,
            color: AppColors.brand,
          ),
          const SizedBox(height: 16),
          Text(
            "Besoin d'aide ?",
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium(color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            "Contactez-nous pour toute question ou modification de vos informations.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 32),
          _ContactTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: 'contact@diosdelices.com',
            color: AppColors.brand,
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
            title: 'Téléphone',
            subtitle: '+229 01 23 45 67 89',
            color: AppColors.brand,
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
            title: 'Chat',
            subtitle: 'Disponible de 9h à 18h',
            color: AppColors.brand,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Chat bientôt disponible !'),
                  backgroundColor: AppColors.brand,
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
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: AppTypography.labelMedium(color: AppColors.ink),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodyMedium(color: AppColors.inkMuted),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.inkSubtle),
        onTap: onTap,
      ),
    );
  }
}
