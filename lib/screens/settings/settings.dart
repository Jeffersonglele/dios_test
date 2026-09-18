import 'package:dios_delices/screens/legal/legal_page.dart';
import 'package:dios_delices/screens/legal/privacy_policy_page.dart';
import 'package:dios_delices/screens/legal/cgv_page.dart';
import 'package:dios_delices/screens/profile/profile_page.dart';
import 'package:dios_delices/screens/profile/location_page.dart';
import 'package:dios_delices/screens/splash/animated_splash_screen.dart';
import 'package:dios_delices/screens/restaurants/restaurant_form_page.dart';
import 'package:dios_delices/widgets/logout.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/theme/theme_provider.dart'
    show localeProvider, themeModeProvider;
import 'package:dios_delices/core/app_role.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  ConsumerState<Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  int _currentRoleId = 0;
  String _currentLang = 'Français';
  String _appVersion = '1.0.0';
  bool _darkMode = false;
  Address? _currentAddress;

  // Notifications settings
  bool _orderNotifications = true;
  bool _promoNotifications = true;
  bool _messageNotifications = true;
  bool _isLoading = false;
  double _maxDeliveryDistance = 10.0;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotificationSettings();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_language') ?? 'fr';
    final addresses = await Address.fetchAddressesFromDB();
    final userAddress =
        Address.getAddressByObject(addresses, "User", session.userId);
    if (!mounted) return;
    setState(() {
      _userId = session.userId;
      _currentRoleId = session.role.id;
      _currentLang = langCode == 'en' ? 'English' : 'Français';
      _currentAddress = userAddress;
    });
    final darkMode = prefs.getBool('dark_mode') ?? false;
    if (mounted) setState(() => _darkMode = darkMode);

    if (session.role.id == 5) {
      final cachedDist =
          prefs.getDouble('driver_max_distance_${session.userId}');
      if (cachedDist != null) {
        setState(() => _maxDeliveryDistance = cachedDist.clamp(1.0, 10.0));
      }
      try {
        final query = QueryBuilder<ParseObject>(ParseObject('Users'))
          ..whereEqualTo('userID', session.userId);
        final response = await query.query();
        if (response.success &&
            response.results != null &&
            response.results!.isNotEmpty) {
          final parseUser = response.results!.first as ParseObject;
          final dist =
              parseUser.get<num>('maxDeliveryDistance')?.toDouble() ?? 10.0;
          // Clamp to valid range (1-10)
          final clampedDist = dist.clamp(1.0, 10.0);
          await prefs.setDouble(
              'driver_max_distance_${session.userId}', clampedDist);
          if (mounted) {
            setState(() => _maxDeliveryDistance = clampedDist);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _saveMaxDeliveryDistance(double distance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('driver_max_distance_${_userId}', distance);

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Users'))
        ..whereEqualTo('userID', _userId);
      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final parseUser = response.results!.first as ParseObject;
        parseUser.set('maxDeliveryDistance', distance);
        await parseUser.save();
      }
    } catch (_) {}
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

  Future<void> _updateNotificationSetting(
      String key, bool value, String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _testNotification() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await NotificationService.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.test_notification_sent)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.error_with_message(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isAdmin => _currentRoleId == 1 || _currentRoleId == 4;

  Future<void> _setLanguage(String code, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    ref.read(localeProvider.notifier).state = Locale(code);
    localeNotifier.value = Locale(code);
    setState(() => _currentLang = label);
  }

  Future<void> _toggleDark(bool value) async {
    ref.read(themeModeProvider.notifier).setDarkMode(value);
    darkModeNotifier.value = value;
  }

  Future<void> _confirmLogout() {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LogoutFormDialog(),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final l10n = AppLocalizations.of(context)!;
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.lock_outline_rounded,
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 18),
            ),
            const SizedBox(width: 10),
            Text(l10n.change_password_title_dialog,
                style: AppTypography.titleMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                    .copyWith(fontSize: 16)),
          ]),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: currentPwdCtrl,
                obscureText: !showCurrent,
                decoration: InputDecoration(
                  labelText: l10n.current_password_label,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        showCurrent
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20),
                    onPressed: () =>
                        setDialogState(() => showCurrent = !showCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwdCtrl,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: l10n.new_password_label,
                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        showNew
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20),
                    onPressed: () => setDialogState(() => showNew = !showNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwdCtrl,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: l10n.confirm_password_label,
                  prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                        showConfirm
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20),
                    onPressed: () =>
                        setDialogState(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPwd = currentPwdCtrl.text.trim();
                final newPwd = newPwdCtrl.text.trim();
                final confirmPwd = confirmPwdCtrl.text.trim();

                if (currentPwd.isEmpty ||
                    newPwd.isEmpty ||
                    confirmPwd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.allFieldsRequired)));
                  return;
                }
                if (newPwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.passwordMinLength)));
                  return;
                }
                if (newPwd != confirmPwd) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.passwordsNotMatch)));
                  return;
                }

                final currentEncrypted =
                    await Users.encryptPassword(currentPwd);
                if (currentEncrypted != currentUser.password &&
                    currentPwd != currentUser.password) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.incorrectCurrentPassword)));
                  return;
                }

                final encrypted = await Users.encryptPassword(newPwd);
                final result =
                    await Users.updatePassword(currentUser.userID, encrypted);
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result == 'success'
                      ? l10n.passwordChangedSuccess
                      : result.toString()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ));
              },
              child: Text(l10n.validate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBecomeRestaurateurDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.restaurant_menu_outlined,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 18),
          ),
          const SizedBox(width: 10),
          Text(l10n.become_restaurateur_dialog_title,
              style: AppTypography.titleMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                  .copyWith(fontSize: 16)),
        ]),
        content: Text(
          l10n.become_restaurateur_dialog_body,
          style: AppTypography.bodyLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.yes_sell_my_dishes),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final session = await SessionService.readSession();
      final cloudFunction = ParseCloudFunction('update1User');
      final response = await cloudFunction.execute(parameters: {
        'userID': session.userId,
        'roleID': 3,
        'identity': 'Verified',
      });

      if (response.success) {
        await SessionService.saveUserSession(
          userId: session.userId,
          role: AppRole.fromId(3),
          country: session.country,
          email: session.email,
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RestaurantFormPage()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.error_with_message(response.error?.message ?? ""))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error_with_message(e.toString()))),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final session = await SessionService.readSession();
    final userEmail = session.email ?? '';

    String enteredEmail = '';
    bool understood = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.errorLight, AppDarkColors.errorLight),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.warning_rounded,
                  color:
                      AppColors.resolve(AppColors.error, AppDarkColors.error),
                  size: 18),
            ),
            const SizedBox(width: 10),
            Text(l10n.delete_account_dialog_title,
                style: AppTypography.titleMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                    .copyWith(fontSize: 16)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  l10n.delete_account_dialog_warning,
                  style: AppTypography.bodyLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.delete_account_recovery_hint,
                  style: AppTypography.bodyMedium(
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted)),
                ),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.confirm_your_email,
                    hintText: userEmail,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  onChanged: (v) => setDialogState(() => enteredEmail = v),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: understood,
                        onChanged: (v) =>
                            setDialogState(() => understood = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.delete_account_understand_hint,
                        style: AppTypography.bodySmall(
                            color: AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              onPressed: enteredEmail == userEmail && understood
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.resolve(AppColors.error, AppDarkColors.error),
                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
              ),
              child: Text(l10n.delete,
                  style: TextStyle(
                    color: enteredEmail == userEmail && understood
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  )),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await Users.suppr1User(session.userId);
    if (!mounted) return;

    if (result == 'success') {
      await SessionService.clearAll();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()),
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
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.resolve(
                        AppColors.brand, AppDarkColors.brand)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mon profil ──────────────────────────────
          _sectionTitle(l10n.myProfile),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
            ),
            child: Column(children: [
              _settingRow(
                Icons.person_rounded,
                l10n.myProfile,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfilePage())),
              ),
              const Divider(height: 1),
              _settingRow(
                Icons.location_on_rounded,
                _currentAddress?.fullAddress ?? l10n.address,
                () async {
                  final session = await SessionService.readSession();
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => LocationPage(
                        objectID: session.userId,
                        user_roleID: session.role.id,
                      ),
                    ),
                  );
                  _load();
                },
              ),
              if (!_isAdmin) ...[
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: Text(l10n.notif_orders_title,
                        style: AppTypography.labelMedium()),
                    subtitle: Text(
                      l10n.notif_orders_desc,
                      style: AppTypography.bodyMedium(),
                    ),
                    value: _orderNotifications,
                    activeColor:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                    onChanged: (val) {
                      setState(() => _orderNotifications = val);
                      _updateNotificationSetting('notif_orders', val, 'orders');
                    },
                    secondary: Icon(Icons.shopping_bag_rounded,
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand)),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: Text(l10n.notif_promos_title,
                        style: AppTypography.labelMedium()),
                    subtitle: Text(
                      l10n.notif_promos_desc,
                      style: AppTypography.bodyMedium(),
                    ),
                    value: _promoNotifications,
                    activeColor:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                    onChanged: (val) {
                      setState(() => _promoNotifications = val);
                      _updateNotificationSetting('notif_promos', val, 'promos');
                    },
                    secondary: const Icon(Icons.local_offer_rounded,
                        color: AppColors.brand),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: Text(l10n.notif_chat_title,
                        style: AppTypography.labelMedium()),
                    subtitle: Text(
                      l10n.notif_chat_desc,
                      style: AppTypography.bodyMedium(),
                    ),
                    value: _messageNotifications,
                    activeColor:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                    onChanged: (val) {
                      setState(() => _messageNotifications = val);
                      _updateNotificationSetting(
                          'notif_messages', val, 'messages');
                    },
                    secondary:
                        const Icon(Icons.chat_rounded, color: AppColors.brand),
                  ),
                ),
              ],
            ]),
          ),
          if (!_isAdmin) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _testNotification,
                icon: const Icon(Icons.notifications_active_rounded, size: 18),
                label: Text(l10n.testNotifications),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brand,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Sécurité ─────────────────────────────────
          _sectionTitle(l10n.security),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
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

          // ── Préférences de livraison ────────────────
          if (_currentRoleId == 5) ...[
            _sectionTitle(l10n.delivery_preferences),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: AppColors.resolve(
                        AppColors.border, AppDarkColors.border),
                    width: 0.5),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Icon(Icons.map_rounded,
                          color: AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand)),
                      title: Text(l10n.max_delivery_distance,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text(l10n.max_delivery_distance_desc(
                          _maxDeliveryDistance.toStringAsFixed(1))),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Slider(
                      value: _maxDeliveryDistance.clamp(1.0, 10.0),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      label:
                          '${_maxDeliveryDistance.clamp(1.0, 10.0).toStringAsFixed(0)} km',
                      onChanged: (val) {
                        setState(
                            () => _maxDeliveryDistance = val.clamp(1.0, 10.0));
                      },
                      onChangeEnd: (val) {
                        _saveMaxDeliveryDistance(val.clamp(1.0, 10.0));
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Apparence ───────────────────────────────
          _sectionTitle(l10n.appearance),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: darkModeNotifier,
              builder: (_, isDark, __) => Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  title:
                      Text(l10n.darkMode, style: AppTypography.labelMedium()),
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
          ),
          const SizedBox(height: 24),

          // ── Langue ───────────────────────────────────
          _sectionTitle(l10n.language),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
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
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
            ),
            child: Column(children: [
              _settingRow(
                Icons.privacy_tip_outlined,
                l10n.privacyPolicy,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage())),
              ),
              const Divider(height: 1, indent: 56),
              _settingRow(
                Icons.description_outlined,
                l10n.termsOfService,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CGVPage())),
              ),
              const Divider(height: 1, indent: 56),
              _settingRow(
                Icons.info_outline_rounded,
                l10n.legalNotice,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalPage())),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Devenir micro-restaurateur ─────────────
          if (_currentRoleId == 2)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(l10n.sell_your_dishes),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.resolve(
                          AppColors.border, AppDarkColors.border),
                      width: 0.5),
                ),
                child: _settingRow(
                  Icons.restaurant_menu_outlined,
                  l10n.becomeRestaurateur,
                  _showBecomeRestaurateurDialog,
                ),
              ),
              const SizedBox(height: 24),
            ]),

          // ── À propos ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                        AppColors.brandSurface, AppDarkColors.brandSurface),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.admin_panel_settings_rounded,
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle,
                        style:
                            AppTypography.labelMedium().copyWith(fontSize: 15)),
                    Text(l10n.version_admin,
                        style:
                            AppTypography.bodyMedium().copyWith(fontSize: 11)),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              Text(l10n.app_tagline,
                  style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.inkSubtle, AppDarkColors.inkSubtle))
                      .copyWith(fontSize: 12)),
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
                label: Text(l10n.deleteAccount),
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
              label: Text(l10n.logout),
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
        style: AppTypography.titleMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
            .copyWith(fontSize: 17));
  }

  Widget _langTile(String label, String code, String flag) {
    final isSelected = _currentLang == label;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 22)),
        title: Text(label, style: AppTypography.labelMedium()),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 22)
            : null,
        onTap: isSelected ? null : () => _setLanguage(code, label),
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.brand),
        title: Text(label, style: AppTypography.labelMedium()),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.inkSubtle, size: 20),
        onTap: onTap,
      ),
    );
  }
}
