import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  ConsumerState<Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  bool _darkMode = false;
  String _appVersion = '1.0.0';

  // Notifications settings
  bool _orderNotifications = true;
  bool _promoNotifications = true;
  bool _messageNotifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadNotificationSettings();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? false;
    if (mounted) setState(() => _darkMode = darkMode);
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _orderNotifications = prefs.getBool('notif_orders') ?? true;
        _promoNotifications = prefs.getBool('notif_promos') ?? true;
        _messageNotifications = prefs.getBool('notif_messages') ?? true;
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);

    final themeNotifier = ref.read(themeModeProvider.notifier);
    themeNotifier.toggleTheme();

    if (mounted) setState(() => _darkMode = value);
  }

  Future<void> _updateNotificationSetting(
      String key, bool value, String channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    try {
      final session = await SessionService.readSession();
      if (session.isLoggedIn) {
        final query = QueryBuilder<ParseObject>(ParseObject('_User'));
        query.whereEqualTo('objectId', session.userId.toString());

        final response = await query.first();
        if (response != null) {
          response.set('preferences_notifications', {
            'orders': _orderNotifications,
            'promos': _promoNotifications,
            'messages': _messageNotifications,
          });
          await response.save();
        }
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde préférences notifications: $e');
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isLoading = true);
    try {
      await NotificationService.sendTestNotification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification test envoyée !'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLegalPage(String type) async {
    // Implémentez la navigation vers les pages légales
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              subtitle: Text(
                isDark ? 'Activé 🌙' : 'Désactivé ☀️',
                style: AppTypography.bodyMedium(),
              ),
              value: isDark,
              activeColor: AppColors.brand,
              onChanged: _toggleDarkMode,
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: isDark ? AppColors.brand : Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                subtitle: Text(
                  'Notifications des statuts de commande',
                  style: AppTypography.bodyMedium(),
                ),
                value: _orderNotifications,
                activeColor: AppColors.brand,
                onChanged: (val) {
                  setState(() => _orderNotifications = val);
                  _updateNotificationSetting('notif_orders', val, 'orders');
                },
                secondary: const Icon(Icons.shopping_bag_rounded,
                    color: AppColors.brand),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Promotions', style: AppTypography.labelMedium()),
                subtitle: Text(
                  'Offres spéciales et réductions',
                  style: AppTypography.bodyMedium(),
                ),
                value: _promoNotifications,
                activeColor: AppColors.brand,
                onChanged: (val) {
                  setState(() => _promoNotifications = val);
                  _updateNotificationSetting('notif_promos', val, 'promos');
                },
                secondary: const Icon(Icons.local_offer_rounded,
                    color: AppColors.brand),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('Messages', style: AppTypography.labelMedium()),
                subtitle: Text(
                  'Nouveaux messages du chat',
                  style: AppTypography.bodyMedium(),
                ),
                value: _messageNotifications,
                activeColor: AppColors.brand,
                onChanged: (val) {
                  setState(() => _messageNotifications = val);
                  _updateNotificationSetting('notif_messages', val, 'messages');
                },
                secondary:
                    const Icon(Icons.chat_rounded, color: AppColors.brand),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _isLoading ? null : _testNotification,
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: const Text('Tester les notifications'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
          _sectionTitle('Compte'),
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
                  'Politique de confidentialité',
                  () => _openLegalPage('privacy')),
              const Divider(height: 1),
              _settingRow(Icons.description_outlined, 'Conditions générales',
                  () => _openLegalPage('cgu')),
              const Divider(height: 1),
              _settingRow(Icons.info_outline_rounded, 'Mentions légales',
                  () => _openLegalPage('legal')),
              const Divider(height: 1),
              _settingRow(
                Icons.logout_rounded,
                'Déconnexion',
                () => _logout(), // ← Correction ici
                color: AppColors.error,
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'Dios Délices v$_appVersion',
                  style: AppTypography.bodyMedium(color: AppColors.inkSubtle),
                ),
                const SizedBox(height: 4),
                Text(
                  'Neighborhood cooking, warmer and simpler.',
                  style: AppTypography.bodyMedium(color: AppColors.inkSubtle)
                      .copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await SessionService.markLoggedOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la déconnexion: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: AppTypography.titleMedium().copyWith(fontSize: 17));
  }

  Widget _settingRow(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.brand),
      title: Text(
        title,
        style: AppTypography.labelMedium(color: color ?? AppColors.ink),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
      onTap: onTap,
    );
  }
}
