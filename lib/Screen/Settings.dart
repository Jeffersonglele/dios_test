import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _darkMode = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _darkMode = prefs.getBool('dark_mode') ?? false);
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    setState(() => _darkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Apparence ───────────────────────────────
          _sectionTitle('Apparence'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: SwitchListTile(
              title: Text('Mode sombre', style: AppTypography.labelMedium()),
              subtitle: Text(_darkMode ? 'Activé' : 'Désactivé',
                  style: AppTypography.bodyMedium()),
              value: _darkMode,
              activeColor: AppColors.brand,
              onChanged: _toggleDarkMode,
              secondary: Icon(
                _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: _darkMode ? AppColors.brand : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Notifications ───────────────────────────
          _sectionTitle('Notifications'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              SwitchListTile(
                title: Text('Commandes', style: AppTypography.labelMedium()),
                value: true, activeColor: AppColors.brand,
                onChanged: (_) {},
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Promotions', style: AppTypography.labelMedium()),
                value: true, activeColor: AppColors.brand,
                onChanged: (_) {},
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Pays ────────────────────────────────────
          _sectionTitle('Pays / Région'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.language_rounded, color: AppColors.brand),
              const SizedBox(width: 12),
              const Text('France, Bénin, Côte d\'Ivoire'),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Compte ──────────────────────────────────
          _sectionTitle('Compte'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _settingRow(Icons.privacy_tip_outlined, 'Politique de confidentialité'),
              const Divider(height: 1),
              _settingRow(Icons.description_outlined, 'Conditions générales'),
              const Divider(height: 1),
              _settingRow(Icons.info_outline_rounded, 'Mentions légales'),
            ]),
          ),
          const SizedBox(height: 24),

          // ── À propos ────────────────────────────────
          Center(child: Text('Dios Délices v$_appVersion',
              style: AppTypography.bodyMedium(color: AppColors.inkSubtle))),
          const SizedBox(height: 8),
          Center(child: Text('Neighborhood cooking, warmer and simpler.',
              style: AppTypography.bodyMedium(color: AppColors.inkSubtle).copyWith(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: AppTypography.titleMedium().copyWith(fontSize: 17));
  }

  Widget _settingRow(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brand),
      title: Text(title, style: AppTypography.labelMedium()),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
      onTap: () {},
    );
  }
}
