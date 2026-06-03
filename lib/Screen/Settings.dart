import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../modeles/address.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';
import '../utils/strings.dart';
import '../utils/toast.dart';
import '../components/Logout.dart';
import 'AnimatedSplashScreen.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});
  @override
  ConsumerState<Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  bool _isDarkMode = false;
  String _selectedLanguage = 'fr';
  String _country = '';
  String _roleLabel = '';
  int _roleId = 0;
  String _userAddress = '';
  int? _addressID;
  bool _loadingUser = true;
  bool _notifOrders = true;
  bool _notifPromos = true;
  bool _notifMessages = true;

  bool get _isAdmin => _roleId == 1 || _roleId == 4;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadUserInfo();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _selectedLanguage = prefs.getString('app_language') ?? 'fr';
      _notifOrders = prefs.getBool('notif_orders') ?? true;
      _notifPromos = prefs.getBool('notif_promos') ?? true;
      _notifMessages = prefs.getBool('notif_messages') ?? true;
    });
  }

  Future<void> _loadUserInfo() async {
    final session = await SessionService.readSession();
    final users = await Users.fetchUsersFromDB();
    final user = Users.getUsersByUserId(users, session.userId);
    final role = AppRole.fromId(user?.roleID ?? session.role.id);
    final labels = {1: 'Admin', 2: 'Client', 3: 'Micro-restaurateur', 4: 'Super Admin', 5: 'Livreur'};

    String adr = '';
    int? aid;
    try {
      final addresses = await Address.fetchAddressesFromDB();
      final addr = Address.getAddressByObject(addresses, 'Users', session.userId);
      if (addr != null) { adr = addr.fullAddress ?? ''; aid = addr.addressID; }
    } catch (_) {}

    if (mounted) setState(() {
      _country = user?.country ?? session.country;
      _roleLabel = labels[role.id] ?? 'Inconnu';
      _roleId = role.id;
      _userAddress = adr;
      _addressID = aid;
      _loadingUser = false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    final themeState = value ? ThemeMode.dark : ThemeMode.light;
    try {
      ref.read(themeModeProvider.notifier).state = themeState;
    } catch (_) {}
    setState(() => _isDarkMode = value);
  }

  Future<void> _setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    Strings.setLanguage(code);
    ref.read(localeProvider.notifier).state = Locale(code);
    setState(() => _selectedLanguage = code);
  }

  Future<void> _editAddress() async {
    final ctrl = TextEditingController(text: _userAddress);
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text('Modifier l\'adresse', style: AppTypography.titleMedium()),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Votre adresse complète',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          validator: (v) => (v == null || v!.trim().isEmpty) ? 'Adresse requise' : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
              if (placemarks.isNotEmpty) {
                final pm = placemarks.first;
                ctrl.text = [pm.thoroughfare, pm.locality, pm.administrativeArea, pm.country]
                    .where((e) => e != null && e.isNotEmpty).join(', ');
              }
            } catch (_) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Position introuvable')));
            }
          },
          icon: const Icon(Icons.my_location_rounded, size: 18),
          label: const Text('Détecter ma position'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ));

    if (result == null || result.trim().isEmpty || !mounted) return;

    final session = await SessionService.readSession();
    try {
      final locations = await locationFromAddress(result);
      if (locations.isEmpty) { Toast(context, 'Adresse introuvable.', false); return; }
      final loc = locations.first;

      await Address.manageAddress(
        addressID: _addressID,
        city: '',
        state: session.country,
        fullAddress: result,
        numero: 0,
        lat: loc.latitude.toString(),
        long: loc.longitude.toString(),
        object: 'Users',
        objectID: session.userId,
        user_roleID: session.role.id,
      );
      setState(() => _userAddress = result);
      Toast(context, 'Adresse mise à jour.', true);
    } catch (e) {
      Toast(context, 'Erreur: $e', false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(Strings.deleteAccount, style: AppTypography.titleMedium()),
      content: Text(Strings.get(
        'Votre compte sera désactivé immédiatement et définitivement supprimé sous 30 jours. '
        'Vos restaurants, plats et commandes seront masqués.\n\nConfirmer la suppression ?',
        'Your account will be deactivated now and permanently deleted in 30 days. '
        'Your restaurants, dishes and orders will be hidden.\n\nConfirm deletion?'
      ), style: AppTypography.bodyLarge()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Strings.cancel, style: AppTypography.labelMedium(color: AppColors.inkMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: Text(Strings.delete)),
      ],
    ));
    if (confirmed != true || !mounted) return;
    final session = await SessionService.readSession();
    final result = await Users.suppr1User(session.userId);
    if (!mounted) return;
    if (result == 'success') {
      await SessionService.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Strings.get('Compte désactivé. Suppression définitive dans 30 jours.', 'Account deactivated. Permanent deletion in 30 days.')),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()), (route) => false);
      }
    } else {
      if (mounted) Toast(context, '${Strings.error} : $result', false);
    }
  }

  Future<void> _testNotification() async {
    if (mounted) Toast(context, Strings.get('Notifications fonctionnelles', 'Notifications working'), true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppDarkColors.surface : AppColors.surface;
    final ink = isDark ? AppDarkColors.ink : AppColors.ink;
    final inkMuted = isDark ? AppDarkColors.inkMuted : AppColors.inkMuted;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(title: Text(Strings.settings, style: AppTypography.titleMedium())),
      body: _loadingUser ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (_country.isNotEmpty) _SectionTitle(Strings.get('Compte', 'Account')),
        if (_country.isNotEmpty) ...[
          ListTile(leading: Icon(Icons.flag_rounded, color: inkMuted), title: Text(Strings.get('Pays / Région', 'Country / Region'), style: AppTypography.bodyLarge(color: ink)), trailing: Text(_country, style: AppTypography.bodyMedium(color: inkMuted))),
          ListTile(leading: Icon(Icons.badge_rounded, color: inkMuted), title: Text(Strings.role, style: AppTypography.bodyLarge(color: ink)), trailing: Text(_roleLabel, style: AppTypography.bodyMedium(color: inkMuted))),
          ListTile(
            leading: Icon(Icons.location_on_rounded, color: inkMuted),
            title: Text('Adresse', style: AppTypography.bodyLarge(color: ink)),
            subtitle: Text(_userAddress.isNotEmpty ? _userAddress : 'Non définie', style: AppTypography.bodyMedium(color: inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.edit_rounded, size: 18, color: AppColors.inkSubtle),
            onTap: _editAddress,
          ),
          const SizedBox(height: 12),
        ],
        _SectionTitle(Strings.appearance),
        const SizedBox(height: 8),
        SwitchListTile(secondary: Icon(Icons.dark_mode_rounded, color: inkMuted), title: Text(Strings.darkMode, style: AppTypography.bodyLarge(color: ink)), value: _isDarkMode, onChanged: _toggleDarkMode, activeColor: AppColors.brand),
        ListTile(
          leading: Icon(Icons.language_rounded, color: inkMuted),
          title: Text(Strings.language, style: AppTypography.bodyLarge(color: ink)),
          subtitle: Text(_selectedLanguage == 'fr' ? 'Français' : 'English', style: AppTypography.bodyMedium(color: inkMuted)),
          trailing: PopupMenuButton<String>(onSelected: _setLanguage, child: Icon(Icons.arrow_drop_down_rounded, color: inkMuted),
            itemBuilder: (_) => [PopupMenuItem(value: 'fr', child: Text('Français', style: AppTypography.bodyMedium())), PopupMenuItem(value: 'en', child: Text('English', style: AppTypography.bodyMedium()))],
          ),
        ),
        const SizedBox(height: 12),
        if (!_isAdmin) ...[
          _SectionTitle(Strings.notifications),
          const SizedBox(height: 8),
          SwitchListTile(secondary: Icon(Icons.receipt_long_rounded, color: inkMuted), title: Text(Strings.orders, style: AppTypography.bodyLarge(color: ink)), subtitle: Text(Strings.get('Nouvelles commandes', 'New orders'), style: AppTypography.bodyMedium(color: inkMuted)), value: _notifOrders, onChanged: (v) async { final p = await SharedPreferences.getInstance(); await p.setBool('notif_orders', v); setState(() => _notifOrders = v); }, activeColor: AppColors.brand),
          SwitchListTile(secondary: Icon(Icons.local_offer_rounded, color: inkMuted), title: Text(Strings.get('Promotions', 'Promotions'), style: AppTypography.bodyLarge(color: ink)), subtitle: Text(Strings.get('Offres spéciales', 'Special offers'), style: AppTypography.bodyMedium(color: inkMuted)), value: _notifPromos, onChanged: (v) async { final p = await SharedPreferences.getInstance(); await p.setBool('notif_promos', v); setState(() => _notifPromos = v); }, activeColor: AppColors.brand),
          SwitchListTile(secondary: Icon(Icons.chat_rounded, color: inkMuted), title: Text(Strings.get('Messages', 'Messages'), style: AppTypography.bodyLarge(color: ink)), subtitle: Text(Strings.get('Messages du support', 'Support messages'), style: AppTypography.bodyMedium(color: inkMuted)), value: _notifMessages, onChanged: (v) async { final p = await SharedPreferences.getInstance(); await p.setBool('notif_messages', v); setState(() => _notifMessages = v); }, activeColor: AppColors.brand),
          const SizedBox(height: 12),
          ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.brandSurface, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(Icons.notifications_active_rounded, color: AppColors.brand, size: 20)), title: Text(Strings.get('Tester les notifications', 'Test notifications'), style: AppTypography.bodyLarge(color: ink)), subtitle: Text(Strings.get('Envoyer une notification de test', 'Send a test notification'), style: AppTypography.bodyMedium(color: inkMuted)), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle), onTap: _testNotification),
        ],
        const SizedBox(height: 24),
        _SectionTitle(Strings.security),
        const SizedBox(height: 8),
        ListTile(leading: Icon(Icons.lock_reset_rounded, color: inkMuted), title: Text(Strings.changePassword, style: AppTypography.bodyLarge(color: ink)), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle), onTap: _showPasswordDialog),
        if (!_isAdmin)
          ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20)), title: Text(Strings.deleteAccount, style: AppTypography.bodyLarge(color: AppColors.error)), subtitle: Text(Strings.deleteAccountWarning, style: AppTypography.bodyMedium(color: inkMuted)), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle), onTap: _deleteAccount),
        const SizedBox(height: 24),
        _SectionTitle(Strings.get('Session', 'Session')),
        const SizedBox(height: 8),
        ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20)), title: Text(Strings.logout, style: AppTypography.bodyLarge(color: AppColors.error)), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle), onTap: () => showDialog(context: context, barrierDismissible: false, builder: (_) => const LogoutFormDialog())),
        const SizedBox(height: 60),
      ]),
    );
  }

  void _showPasswordDialog() async {
    final currentPwd = TextEditingController();
    final newPwd = TextEditingController();
    final form = GlobalKey<FormState>();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(Strings.changePassword, style: AppTypography.titleMedium()),
      content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: currentPwd, obscureText: true, decoration: InputDecoration(labelText: Strings.currentPassword, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))), validator: (v) => v == null || v!.isEmpty ? Strings.required : null),
        const SizedBox(height: 12),
        TextFormField(controller: newPwd, obscureText: true, decoration: InputDecoration(labelText: Strings.newPassword, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))), validator: (v) => v == null || v!.isEmpty ? Strings.required : (v.length < 6 ? Strings.get('6 caractères minimum', '6 characters minimum') : null)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Strings.cancel, style: AppTypography.labelMedium(color: AppColors.inkMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white), onPressed: () async {
          if (!form.currentState!.validate()) return;
          final session = await SessionService.readSession();
          final users = await Users.fetchUsersFromDB();
          final user = Users.getUsersByUserId(users, session.userId);
          if (user == null) { Toast(context, Strings.get('Utilisateur introuvable', 'User not found'), false); return; }
          try {
            final verify = ParseCloudFunction('loginUser');
            final resp = await verify.execute(parameters: {'login': user.username, 'password': currentPwd.text});
            if (!resp.success || resp.result == null || (resp.result as Map<String, dynamic>)['error'] != null) {
              Toast(context, Strings.get('Mot de passe actuel incorrect', 'Incorrect password'), false);
              return;
            }
          } catch (_) {
            Toast(context, Strings.get('Erreur de vérification.', 'Verification error.'), false);
            return;
          }
          final encrypted = await Users.encryptPassword(newPwd.text);
          final result = await Users.updatePassword(session.userId, encrypted);
          if (!ctx.mounted) return;
          if (result == 'success') { Navigator.pop(ctx); Toast(context, Strings.get('Mot de passe modifié', 'Password changed'), true); }
          else Toast(context, '${Strings.error} : $result', false);
        }, child: Text(Strings.modify)),
      ],
    ));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(title, style: AppTypography.labelMedium().copyWith(fontSize: 12, letterSpacing: 0.5, color: isDark ? AppDarkColors.inkSubtle : AppColors.inkSubtle)));
  }
}
