import 'dart:convert';
import 'dart:typed_data';

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
import 'package:dios_delices/widgets/swirling_loader.dart';

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
    _loadUser();
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

  /// Bouton principal plein, en dégradé. Le dégradé + l'ombre sont sur un
  /// Container, l'effet d'appui sur un Material rogné → pas de coins carrés.
  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_brand, _brand.withValues(alpha: 0.85)],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: _brand.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge(color: Colors.white)
                          .copyWith(fontSize: 16),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: Colors.white, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bouton secondaire « discret » : sans fond ni bordure, texte atténué.
  Widget _ghostButton({required String label, required VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: _inkMuted,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium(color: _inkMuted)
              .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Force du mot de passe : 0 (vide) → 4 (très bon).
  int _pwdStrength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 6) score++;
    if (v.length >= 10) score++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[A-Za-z]').hasMatch(v)) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      score++;
    }
    return score.clamp(1, 4);
  }

  Widget _pwdField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool visible,
    required VoidCallback onToggle,
    ValueChanged<String>? onChanged,
    bool matched = false,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      style: AppTypography.bodyLarge(color: _ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _surface,
        prefixIcon: Icon(icon, size: 20, color: _brand),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matched)
              Icon(Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.resolve(
                      AppColors.success, AppDarkColors.success)),
            IconButton(
              icon: Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 20,
                color: _inkMuted,
              ),
              onPressed: onToggle,
            ),
          ],
        ),
        border: border(_border, 0.8),
        enabledBorder: border(_border, 0.8),
        focusedBorder: border(_brand, 1.6),
      ),
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

    bool showCurrent = false, showNew = false, showConfirm = false;
    bool submitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final strength = _pwdStrength(newPwdCtrl.text);
          final matches = confirmPwdCtrl.text.isNotEmpty &&
              confirmPwdCtrl.text == newPwdCtrl.text;
          final strengthColor = strength <= 1
              ? _error
              : strength == 2
                  ? _accent
                  : AppColors.resolve(AppColors.success, AppDarkColors.success);

          Future<void> submit() async {
            final currentPwd = currentPwdCtrl.text.trim();
            final newPwd = newPwdCtrl.text.trim();
            final confirmPwd = confirmPwdCtrl.text.trim();

            String? err;
            if (currentPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
              err = l10n.allFieldsRequired;
            } else if (newPwd.length < 6) {
              err = l10n.passwordMinLength;
            } else if (newPwd != confirmPwd) {
              err = l10n.passwordsNotMatch;
            }
            if (err != null) {
              setD(() => errorText = err);
              return;
            }

            FocusScope.of(ctx).unfocus();
            setD(() {
              errorText = null;
              submitting = true;
            });

            final currentEncrypted = await Users.encryptPassword(currentPwd);
            if (currentUser.password.isNotEmpty &&
                currentEncrypted != currentUser.password &&
                currentPwd != currentUser.password) {
              if (ctx.mounted) {
                setD(() {
                  submitting = false;
                  errorText = l10n.incorrectCurrentPassword;
                });
              }
              return;
            }

            final encrypted = await Users.encryptPassword(newPwd);
            final result = await Users.updatePassword(
                currentUser.userID, encrypted,
                plainPassword: newPwd, currentPlainPassword: currentPwd);

            if (ctx.mounted) Navigator.pop(ctx);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result == 'success'
                  ? l10n.passwordChangedSuccess
                  : result.toString()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ));
          }

          return PopScope(
            canPop: !submitting,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── En-tête ──
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _brandSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _brand.withValues(alpha: 0.25),
                                  width: 6),
                            ),
                            child: Icon(Icons.lock_rounded,
                                color: _brand, size: 28),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.change_password_title_dialog,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleMedium(color: _ink)
                                .copyWith(
                                    fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 20),

                          // ── Champs ──
                          _pwdField(
                            controller: currentPwdCtrl,
                            label: l10n.current_password_label,
                            icon: Icons.lock_outline_rounded,
                            visible: showCurrent,
                            onToggle: () =>
                                setD(() => showCurrent = !showCurrent),
                            onChanged: (_) => setD(() => errorText = null),
                          ),
                          const SizedBox(height: 12),
                          _pwdField(
                            controller: newPwdCtrl,
                            label: l10n.new_password_label,
                            icon: Icons.lock_rounded,
                            visible: showNew,
                            onToggle: () => setD(() => showNew = !showNew),
                            onChanged: (_) => setD(() => errorText = null),
                          ),
                          // Jauge de force
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: newPwdCtrl.text.isEmpty
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(
                                        top: 10, left: 4, right: 4),
                                    child: Row(
                                      children: List.generate(4, (i) {
                                        final on = i < strength;
                                        return Expanded(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 220),
                                            height: 5,
                                            margin: EdgeInsets.only(
                                                right: i == 3 ? 0 : 6),
                                            decoration: BoxDecoration(
                                              color: on
                                                  ? strengthColor
                                                  : _border,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _pwdField(
                            controller: confirmPwdCtrl,
                            label: l10n.confirm_password_label,
                            icon: Icons.lock_rounded,
                            visible: showConfirm,
                            matched: matches,
                            onToggle: () =>
                                setD(() => showConfirm = !showConfirm),
                            onChanged: (_) => setD(() => errorText = null),
                          ),

                          // ── Erreur (visible DANS le dialogue) ──
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: errorText == null
                                ? const SizedBox(width: double.infinity)
                                : Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 14),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _errorLight,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.error_outline_rounded,
                                          color: _error, size: 19),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(errorText!,
                                            style: AppTypography.labelMedium(
                                                    color: _error)
                                                .copyWith(fontSize: 12.5)),
                                      ),
                                    ]),
                                  ),
                          ),
                          const SizedBox(height: 22),

                          // ── Boutons (empilés : action principale bien distincte) ──
                          _primaryButton(
                            label: l10n.validate,
                            onTap: submitting ? null : submit,
                          ),
                          const SizedBox(height: 6),
                          _ghostButton(
                            label: l10n.cancel,
                            onTap: submitting ? null : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Voile Swirling pendant l'enregistrement ──
                  if (submitting)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _card.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                            child: Swirling(size: 64, color: _brand)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    currentPwdCtrl.dispose();
    newPwdCtrl.dispose();
    confirmPwdCtrl.dispose();
  }

  /// Voile plein écran non fermable avec Swirling. Retourne la fonction
  /// qui le referme (sans danger si appelée plusieurs fois).
  VoidCallback _showBlockingLoader() {
    final nav = Navigator.of(context, rootNavigator: true);
    var open = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (_, __, ___) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(child: Swirling(size: 64, color: _brand)),
          ),
        ),
      ),
    );
    return () {
      if (open && nav.canPop()) nav.pop();
      open = false;
    };
  }

  Future<void> _showBecomeRestaurateurDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── En-tête dégradé ──
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brand, _brand.withValues(alpha: 0.75)],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      right: -26,
                      top: -34,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -34,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.restaurant_menu_rounded,
                          color: _brand, size: 36),
                    ),
                    // Bouton fermer
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Contenu ──
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.become_restaurateur_dialog_title,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium(color: _ink).copyWith(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.become_restaurateur_dialog_body,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge(color: _inkMuted)
                          .copyWith(fontSize: 14.5, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    _primaryButton(
                      label: l10n.yes_sell_my_dishes,
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                    const SizedBox(height: 6),
                    _ghostButton(
                      label: l10n.cancel,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Écran bloqué (Swirling) pendant la mise à jour du compte
    final closeLoader = _showBlockingLoader();
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
        closeLoader();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RestaurantFormPage()),
        );
      } else {
        closeLoader();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.error_with_message(response.error?.message ?? ""))),
        );
      }
    } catch (e) {
      closeLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error_with_message(e.toString()))),
      );
    } finally {
      closeLoader(); // sécurité : sans effet s'il est déjà fermé
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
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.md))),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════
  // UI (redesign) — la logique ci-dessus est inchangée
  // ═══════════════════════════════════════════════════════

  Users? _currentUser;

  Future<void> _loadUser() async {
    try {
      final session = await SessionService.readSession();
      final users = await Users.fetchUsersFromDB();
      final u = Users.getUsersByUserId(users, session.userId);
      if (!mounted) return;
      setState(() => _currentUser = u);
    } catch (_) {}
  }

  // Raccourcis couleurs
  Color get _ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  Color get _inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  Color get _inkSubtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  Color get _brand => AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  Color get _brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  Color get _accent => AppColors.resolve(AppColors.accent, AppDarkColors.accent);
  Color get _error => AppColors.resolve(AppColors.error, AppDarkColors.error);
  Color get _errorLight =>
      AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight);
  Color get _card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  Color get _border => AppColors.resolve(AppColors.border, AppDarkColors.border);
  Color get _surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(themeModeProvider);
    ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(l10n.settings,
            style: AppTypography.titleMedium(color: _ink)
                .copyWith(fontSize: 19)),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Swirling(size: 30, color: _brand)),
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Carte profil ──────────────────────────
          _reveal(0, _profileCard(l10n)),
          const SizedBox(height: 16),

          // ── Bannière « vendre mes plats » ─────────
          if (_currentRoleId == 2) ...[
            _reveal(1, _sellBanner(l10n)),
            const SizedBox(height: 16),
          ],

          // ── Compte ────────────────────────────────
          _reveal(
            2,
            _group([
              _row(
                Icons.location_on_rounded,
                _currentAddress?.fullAddress ?? l10n.address,
                subtitle: _currentAddress == null ? null : l10n.address,
                onTap: () async {
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
              _row(
                Icons.lock_outline_rounded,
                l10n.changePassword,
                onTap: _showChangePasswordDialog,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Notifications ─────────────────────────
          if (!_isAdmin) ...[
            _reveal(
              3,
              _group([
                _switchRow(
                  Icons.shopping_bag_rounded,
                  l10n.notif_orders_title,
                  l10n.notif_orders_desc,
                  _orderNotifications,
                  (v) {
                    setState(() => _orderNotifications = v);
                    _updateNotificationSetting('notif_orders', v, 'orders');
                  },
                ),
                _switchRow(
                  Icons.local_offer_rounded,
                  l10n.notif_promos_title,
                  l10n.notif_promos_desc,
                  _promoNotifications,
                  (v) {
                    setState(() => _promoNotifications = v);
                    _updateNotificationSetting('notif_promos', v, 'promos');
                  },
                ),
                _switchRow(
                  Icons.chat_rounded,
                  l10n.notif_chat_title,
                  l10n.notif_chat_desc,
                  _messageNotifications,
                  (v) {
                    setState(() => _messageNotifications = v);
                    _updateNotificationSetting('notif_messages', v, 'messages');
                  },
                ),
                _row(
                  Icons.notifications_active_rounded,
                  l10n.testNotifications,
                  trailing: _isLoading
                      ? Swirling(size: 26, color: _brand)
                      : null,
                  onTap: _isLoading ? null : _testNotification,
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Préférences de livraison (livreur) ────
          if (_currentRoleId == 5) ...[
            _reveal(4, _deliveryCard(l10n)),
            const SizedBox(height: 16),
          ],

          // ── Apparence + langue ────────────────────
          _reveal(
            4,
            _group([
              ValueListenableBuilder<bool>(
                valueListenable: darkModeNotifier,
                builder: (_, isDark, __) => _switchRow(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  l10n.darkMode,
                  isDark ? l10n.enabled : l10n.disabled,
                  isDark,
                  _toggleDark,
                  iconColor: isDark ? _brand : _accent,
                ),
              ),
              _row(
                Icons.translate_rounded,
                l10n.language,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_currentLang,
                      style: AppTypography.bodyMedium(color: _inkMuted)
                          .copyWith(fontSize: 13.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: _inkSubtle, size: 22),
                ]),
                onTap: _showLanguageSheet,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Légal ─────────────────────────────────
          _reveal(
            5,
            _group([
              _row(
                Icons.privacy_tip_outlined,
                l10n.privacyPolicy,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage())),
              ),
              _row(
                Icons.description_outlined,
                l10n.termsOfService,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CGVPage())),
              ),
              _row(
                Icons.info_outline_rounded,
                l10n.legalNotice,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalPage())),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── À propos ──────────────────────────────
          _reveal(6, _aboutCard(l10n)),
          const SizedBox(height: 24),

          // ── Supprimer mon compte ──────────────────
          if (!_isAdmin) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _showDeleteAccountDialog,
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: Text(l10n.deleteAccount),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _error,
                  side: BorderSide(color: _error.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Déconnexion ───────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: Text(l10n.logout,
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animation d'apparition ──────────────────────────────
  Widget _reveal(int index, Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 360 + index * 70),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c),
        ),
        child: child,
      );

  // ── Carte profil ────────────────────────────────────────
  Widget _profileCard(AppLocalizations l10n) {
    final u = _currentUser;
    Uint8List? bytes;
    if (u != null && u.image.isNotEmpty) {
      try {
        bytes = base64Decode(u.image);
      } catch (_) {}
    }
    final initials = u == null
        ? ''
        : '${u.firstname.isNotEmpty ? u.firstname[0] : ''}${u.lastname.isNotEmpty ? u.lastname[0] : ''}'
            .toUpperCase();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfilePage()));
        _loadUser();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _brand, width: 1.8),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: _brandSurface,
              child: bytes != null
                  ? ClipOval(
                      child: Image.memory(bytes,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          gaplessPlayback: true))
                  : (initials.isNotEmpty
                      ? Text(initials,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _brand))
                      : Icon(Icons.person_rounded, color: _brand)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u == null ? l10n.myProfile : '${u.firstname} ${u.lastname}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium(color: _ink)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (u != null && u.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(color: _inkMuted)
                        .copyWith(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration:
                BoxDecoration(color: _brandSurface, shape: BoxShape.circle),
            child: Icon(Icons.chevron_right_rounded, color: _brand, size: 22),
          ),
        ]),
      ),
    );
  }

  // ── Bannière « vendre mes plats » ───────────────────────
  Widget _sellBanner(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _showBecomeRestaurateurDialog,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brand, _brand.withValues(alpha: 0.78)],
          ),
          boxShadow: [
            BoxShadow(
              color: _brand.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(children: [
            Positioned(
              right: -24,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sell_your_dishes,
                        style: AppTypography.titleMedium(color: Colors.white)
                            .copyWith(fontSize: 16.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.become_restaurateur_dialog_body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                                color: Colors.white.withValues(alpha: 0.85))
                            .copyWith(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Préférences de livraison ────────────────────────────
  Widget _deliveryCard(AppLocalizations l10n) {
    final v = _maxDeliveryDistance.clamp(1.0, 10.0);
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        Row(children: [
          _iconBox(Icons.map_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.max_delivery_distance,
                    style: AppTypography.labelMedium(color: _ink)
                        .copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  l10n.max_delivery_distance_desc(v.toStringAsFixed(1)),
                  style: AppTypography.bodyMedium(color: _inkMuted)
                      .copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _brandSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('${v.toStringAsFixed(0)} km',
                style: AppTypography.labelMedium(color: _brand)),
          ),
        ]),
        Slider(
          value: v,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: _brand,
          label: '${v.toStringAsFixed(0)} km',
          onChanged: (val) =>
              setState(() => _maxDeliveryDistance = val.clamp(1.0, 10.0)),
          onChangeEnd: (val) => _saveMaxDeliveryDistance(val.clamp(1.0, 10.0)),
        ),
      ]),
    );
  }

  // ── À propos ────────────────────────────────────────────
  Widget _aboutCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(children: [
        Row(children: [
          _iconBox(Icons.admin_panel_settings_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle,
                    style: AppTypography.labelMedium(color: _ink)
                        .copyWith(fontSize: 15)),
                Text(l10n.version_admin,
                    style: AppTypography.bodyMedium(color: _inkMuted)
                        .copyWith(fontSize: 11)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.app_tagline,
              style: AppTypography.bodyMedium(color: _inkSubtle)
                  .copyWith(fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Sélecteur de langue ─────────────────────────────────
  Future<void> _showLanguageSheet() {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.language,
                  style: AppTypography.titleMedium(color: _ink)
                      .copyWith(fontSize: 18)),
            ),
            const SizedBox(height: 14),
            _langOption(ctx, 'Français', 'fr', '🇫🇷'),
            const SizedBox(height: 10),
            _langOption(ctx, 'English', 'en', '🇬🇧'),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _langOption(BuildContext ctx, String label, String code, String flag) {
    final selected = _currentLang == label;
    return GestureDetector(
      onTap: () async {
        if (!selected) await _setLanguage(code, label);
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _brandSurface : _card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? _brand : _border,
            width: selected ? 1.5 : 0.6,
          ),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: AppTypography.labelMedium(
                        color: selected ? _brand : _ink)
                    .copyWith(fontSize: 15.5)),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: _brand, size: 22),
        ]),
      ),
    );
  }

  // ── Briques réutilisables ───────────────────────────────
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );

  Widget _iconBox(IconData icon, {Color? color}) {
    final c = color ?? _brand;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c == _brand ? _brandSurface : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: c, size: 20),
    );
  }

  /// Carte regroupant plusieurs lignes séparées par des filets.
  Widget _group(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, indent: 70, endIndent: 16, color: _border));
      }
      items.add(children[i]);
    }
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }

  Widget _row(
    IconData icon,
    String label, {
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            _iconBox(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium(color: _ink)
                          .copyWith(fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTypography.bodyMedium(color: _inkMuted)
                            .copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: _inkSubtle, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _switchRow(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(children: [
            _iconBox(icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.labelMedium(color: _ink)
                          .copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(color: _inkMuted)
                          .copyWith(fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: _brand,
            ),
          ]),
        ),
      ),
    );
  }
}