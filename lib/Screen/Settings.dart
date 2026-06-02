import 'package:dios_delices/Screen/legal/LegalPage.dart';
import 'package:dios_delices/Screen/legal/PrivacyPolicyPage.dart';
import 'package:dios_delices/Screen/legal/CGVPage.dart';
import 'package:dios_delices/Screen/ProfilePage.dart';
import 'package:dios_delices/components/Logout.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  int _currentRoleId = 0;
  String _currentLang = 'Français';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language') ?? 'fr';
    if (!mounted) return;
    setState(() {
      _currentRoleId = session.role.id;
      _currentLang = langCode == 'en' ? 'English' : 'Français';
    });
  }

  bool get _isAdmin => _currentRoleId == 1 || _currentRoleId == 4;

  Future<void> _setLanguage(String code, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    localeNotifier.value = Locale(code);
    setState(() => _currentLang = label);
  }

  Future<void> _toggleDark(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    darkModeNotifier.value = value;
  }

  Future<void> _confirmLogout() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LogoutFormDialog(),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final session = await SessionService.readSession();
    final users = await Users.fetchUsersFromDB();
    final currentUser = Users.getUsersByUserId(users, session.userId);
    if (currentUser == null) return;
    if (!mounted) return;

    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool showCurrent = false, showNew = false, showConfirm = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
              child: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Modifier le mot de passe',
                style: AppTypography.titleMedium().copyWith(fontSize: 16)),
          ]),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: currentPwdCtrl,
                obscureText: !showCurrent,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(showCurrent
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setDialogState(() => showCurrent = !showCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwdCtrl,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(showNew
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setDialogState(() => showNew = !showNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwdCtrl,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(showConfirm
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded, size: 20),
                    onPressed: () => setDialogState(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: AppTypography.labelMedium(color: AppColors.inkMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPwd = currentPwdCtrl.text.trim();
                final newPwd = newPwdCtrl.text.trim();
                final confirmPwd = confirmPwdCtrl.text.trim();

                if (currentPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Tous les champs sont requis')));
                  return;
                }
                if (newPwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Le mot de passe doit faire au moins 6 caractères')));
                  return;
                }
                if (newPwd != confirmPwd) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas')));
                  return;
                }

                final currentEncrypted = await Users.encryptPassword(currentPwd);
                if (currentEncrypted != currentUser.password &&
                    currentPwd != currentUser.password) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Mot de passe actuel incorrect')));
                  return;
                }

                final encrypted = await Users.encryptPassword(newPwd);
                final result = await Users.updatePassword(
                    currentUser.userID, encrypted);
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result == 'success'
                      ? 'Mot de passe modifié avec succès'
                      : result.toString()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ));
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
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
            child: const Icon(Icons.warning_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Supprimer mon compte',
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Text(
          'Cette action est irréversible. Toutes vos données personnelles et '
          'vos commandes seront définitivement supprimées.\n\n'
          'Voulez-vous vraiment continuer ?',
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final session = await SessionService.readSession();
    final result = await Users.suppr1User(session.userId);
    if (!mounted) return;

    if (result == 'success') {
      await SessionService.clearAll();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LogoutFormDialog(),
        ),
        (route) => false,
      );
      if (mounted) _confirmLogout();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.toString()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mon profil ──────────────────────────────
          _sectionTitle(l10n.myProfile),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _settingRow(
                Icons.person_rounded,
                l10n.myProfile,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfilePage())),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Sécurité ─────────────────────────────────
          _sectionTitle(l10n.security),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _settingRow(
                Icons.lock_outline_rounded,
                l10n.changePassword,
                _showChangePasswordDialog,
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Apparence ───────────────────────────────
          _sectionTitle(l10n.appearance),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: darkModeNotifier,
              builder: (_, isDark, __) => SwitchListTile(
                title: Text(l10n.darkMode, style: AppTypography.labelMedium()),
                subtitle: Text(isDark ? l10n.enabled : l10n.disabled,
                    style: AppTypography.bodyMedium()),
                value: isDark,
                activeColor: AppColors.brand,
                onChanged: _toggleDark,
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? AppColors.brand : AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Langue ───────────────────────────────────
          _sectionTitle(l10n.language),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _langTile('Français', 'fr', '🇫🇷'),
              const Divider(height: 1, indent: 56),
              _langTile('English', 'en', '🇬🇧'),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Informations légales ─────────────────────
          _sectionTitle(l10n.legalInfo),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _settingRow(
                Icons.privacy_tip_outlined,
                l10n.privacyPolicy,
                () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyPage())),
              ),
              const Divider(height: 1, indent: 56),
              _settingRow(
                Icons.description_outlined,
                l10n.termsOfService,
                () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const CGVPage())),
              ),
              const Divider(height: 1, indent: 56),
              _settingRow(
                Icons.info_outline_rounded,
                l10n.legalNotice,
                () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const LegalPage())),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── À propos ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.admin_panel_settings_rounded,
                      color: AppColors.brand, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dios Délices', style: AppTypography.labelMedium().copyWith(fontSize: 15)),
                    Text('v1.0.0 · Administration',
                        style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              Text('La cuisine de quartier, plus chaleureuse et plus simple.',
                  style: AppTypography.bodyMedium(color: AppColors.inkSubtle).copyWith(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Supprimer mon compte ─────────────────────
          if (!_isAdmin)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showDeleteAccountDialog,
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Supprimer mon compte'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          if (!_isAdmin) const SizedBox(height: 12),

          // ── Déconnexion ──────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: AppTypography.titleMedium().copyWith(fontSize: 17));
  }

  Widget _langTile(String label, String code, String flag) {
    final isSelected = _currentLang == label;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label, style: AppTypography.labelMedium()),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 22)
          : null,
      onTap: isSelected ? null : () => _setLanguage(code, label),
    );
  }

  Widget _settingRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brand),
      title: Text(label, style: AppTypography.labelMedium()),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.inkSubtle, size: 20),
      onTap: onTap,
    );
  }
}
