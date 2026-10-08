import 'package:dios_delices/screens/users/user_identity_rejected.dart';
import 'package:dios_delices/screens/onboarding/wait_identity_validation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../constants/constant.dart';
import '../../controllers/ui_controller.dart';
import '../../core/app_role.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../db/database_helper.dart';
import '../../services/session_service.dart';
import '../../services/node_auth_service.dart';
import '../../services/node_home_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast.dart';
import '../../utils/country_util.dart';
import '../../utils/phone_number.dart';
import '../../providers/users_provider.dart';
import '../restaurants/restaurant_form_page.dart';
import '../onboarding/start_address_saving.dart';
import '../onboarding/status_selection_page.dart';
import '../restaurants/restaurant_update_form_page.dart';
import '../restaurants/wait_restaurant_validation.dart';
import '../password/email_input_screen.dart';
import '../password/first_login_password_change.dart';
import '../onboarding/verification_page.dart';
import '../../widgets/animations.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/swirling_loader.dart';


VoidCallback _showAuthLoader(BuildContext context) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
  var removed = false;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.55),
          ),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(child: Swirling(size: 64, color: brand)),
            ),
          ),
        ],
      ),
    ),
  );
  overlay.insert(entry);
  return () {
    if (removed) return;
    removed = true;
    entry.remove();
  };
}

// ═══════════════════════════════════════════════════════════
// WelcomeScreen
// ═══════════════════════════════════════════════════════════

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;
  bool _showButton = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.3, 0.8, curve: AppMotion.standard),
      ),
    );
    _textSlide = Tween(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.3, 0.8, curve: AppMotion.standard),
      ),
    );
    _textCtrl.forward();

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: AppMotion.standard);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showButton = true);
        _btnCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final session = await SessionService.readSession();
    if (mounted) {
      setState(() => _isAdmin = session.role.isAdmin);
    }
  }

  Future<void> _continue() async {
    final session = await SessionService.readSession();
    if (mounted) {
      await Users.updateDerniereConnexion(session.userId);
      Users.chooseCurvedNavigation(session.role.id, session.country, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
      body: OrderConfettiCelebration(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Cercle check avec halo brand ──────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandColor.withValues(alpha: 0.08),
                        ),
                      ),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              brandColor.withValues(alpha: 0.18),
                              brandColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.25),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const AnimatedSuccessCheck(),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Texte animé ───────────────────────────
                  FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            _isAdmin
                                ? AppLocalizations.of(context)!
                                    .admin_welcome_title
                                : AppLocalizations.of(context)!.welcome,
                            style: AppTypography.headlineLarge(color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isAdmin
                                ? AppLocalizations.of(context)!
                                    .admin_welcome_body
                                : AppLocalizations.of(context)!.welcomeSubtitle,
                            style: AppTypography.bodyLarge(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Bouton animé ──────────────────────────
                  if (_showButton)
                    FadeTransition(
                      opacity: _btnFade,
                      child: _GradientButton(
                        label: AppLocalizations.of(context)!.discover,
                        onPressed: _continue,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Login
// ═══════════════════════════════════════════════════════════

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login>
    with SingleTickerProviderStateMixin {
  // ── Données ──────────────────────────────────────────────
  List<Users> _users = [];
  List<Restaurant> _restaus = [];

  // ── Contrôleurs ──────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── État ─────────────────────────────────────────────────
  bool _isLoading = false;
  bool _loginFailed = false;
  bool _obscurePassword = true;

  LoginTab _loginTab = LoginTab.emailPassword;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Chargement ───────────────────────────────────────────
  Future<void> _loadData() async {
    final usersList = await Users.fetchUsersFromDB();
    final restausList = await Restaurant.fetchRestaurantsFromDB();
    if (mounted) {
      setState(() {
        _users = usersList;
        _restaus = restausList ?? [];
      });
    }
  }

  // ── Connexion ────────────────────────────────────────────
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _loginFailed = false;
    });
    final closeLoader = _showAuthLoader(context);

    try {
      // Évite qu'une ancienne session Parse soit réutilisée par les écrans
      // encore en migration lorsque l'utilisateur ouvre une session Node.
      await SessionService.clearLocalParseSession();
      final isNodeLogin = _loginTab == LoginTab.emailPassword;
      Users? user;

      if (isNodeLogin) {
        final auth = await NodeAuthService.login(
          identifier: _nameCtrl.text,
          password: _passwordCtrl.text,
        );
        user = Users.fromNodeAuth(auth.user);
        await DatabaseHelper.createUser(user);
        await SessionService.saveNodeSession(
          token: auth.token,
          userId: user.userID,
          role: AppRole.fromId(user.roleID),
          country: user.country,
          email: user.email,
        );
      } else {
        // Le téléphone/OTP reste temporairement sur Parse jusqu'à sa
        // migration vers le backend Node.js.
        user = await _findUser();
      }

      if (user == null) {
        _onLoginFailed(Users.lastLoginError);
        return;
      }
      final authenticatedUser = user;

      if (isNodeLogin && !await SessionService.hasNodeSession()) {
        _onLoginFailed('Session Node.js impossible à ouvrir.');
        return;
      }
      if (!isNodeLogin && !await SessionService.hasParseSession()) {
        _onLoginFailed();
        return;
      }

      final role = AppRole.fromId(authenticatedUser.roleID);
      if (!isNodeLogin) {
        await SessionService.saveUserSession(
          userId: authenticatedUser.userID,
          role: role,
          country: authenticatedUser.country,
          email: authenticatedUser.email,
        );
        // Même en login Parse/OTP, on synchronise le catalogue Node.js en
        // local (Hive). Cela évite d'afficher d'anciens restaurants
        // Back4App/Parse sur l'écran d'accueil.
        try {
          await NodeHomeService.load();
        } catch (_) {}
      }

      if (authenticatedUser.mustChangePassword) {
        if (mounted) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => FirstLoginPasswordChange(user: authenticatedUser),
            ),
          );
        }
        return;
      }

      if (role.isAdmin) {
        await _firstLogin(authenticatedUser);
      } else if (authenticatedUser.status == 'Verified') {
        await _handleApprovedUser(authenticatedUser);
      } else {
        _redirectToVerification(authenticatedUser);
      }
    } catch (e) {
      if (e is NodeAuthException) {
        _onLoginFailed(e.message);
        return;
      }
      if (mounted) {
        Toast(context, AppLocalizations.of(context)!.connectError, false);
      }
      _onLoginFailed();
    } finally {
      closeLoader(); // sans effet s'il est déjà fermé
    }
  }

  Future<Users?> _findUser() async {
    Users? user = await Users.loginUser(_nameCtrl.text, _passwordCtrl.text);
    if (user != null) {
      await DatabaseHelper.createUser(user);
      await Users.getAllUsersDetails(adminUserID: user.userID);
      final fresh = await Users.fetchUsersFromDB();
      if (mounted) setState(() => _users = fresh);
      for (final u in fresh) {
        if (u.userID == user.userID) return u;
      }
      return user;
    }

    await Users.getAllUsersDetails();
    final fresh = await Users.fetchUsersFromDB();
    if (mounted) setState(() => _users = fresh);
    return Users.verifUser(fresh, _nameCtrl.text, _passwordCtrl.text);
  }

  Future<void> _handleApprovedUser(Users user) async {
    if (user.country.trim().isEmpty) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              StartAddressSaving(userID: user.userID, roleID: user.roleID),
        ),
      );
    } else if (user.identity == "Verified") {
      await _redirectToMainApp(user);
    } else if (user.identity == "En attente") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WaitIdentityValidation()),
      );
    } else if (user.identity == "Rejected") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserIdentityRejected(
            objectID: user.userID,
            user_roleID: user.roleID,
          ),
        ),
      );
    } else {
      await _redirectToMainApp(user);
    }
  }

  Future<void> _redirectToMainApp(Users user) async {
    final role = AppRole.fromId(user.roleID);
    if (role.isProfessional) {
      NotificationService.subscribeToRestaurantNotifications();
      await _handleRestaurantValidation(user);
    } else {
      if (role.isIndividual) {
        final r = await Restaurant.getRestaurantByUser(_restaus, user.userID);
        if (r != null) await SessionService.setRestaurantId(r.restaurantID);
      }
      NotificationService.subscribeToRestaurantNotifications();
      await _firstLogin(user);
    }
  }

  Future<void> _handleRestaurantValidation(Users user) async {
    // Always fetch fresh data on login to get the latest validation status
    await Restaurant.getAllRestaurantsDetails();
    final refreshed = await Restaurant.fetchRestaurantsFromDB();
    _restaus = refreshed ?? [];
    var restau = await Restaurant.getRestaurantByUser(_restaus, user.userID);

    // Si non trouvé en cache local, tenter la recherche directe API pour ce vendeur
    restau ??= await Restaurant.fetchRestaurantByUserIdFromAPI(user.userID);

    if (!mounted) return;

    if (restau == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RestaurantFormPage()),
      );
    } else if (restau.valid == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WaitRestaurantValidation()),
      );
    } else if (restau.valid == 1) {
      await SessionService.setRestaurantId(restau.restaurantID);
      NotificationService.subscribeToRestaurantNotifications();
      await _firstLogin(user);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RestaurantUpdateFormPage(user: user, restaurant: restau!),
        ),
      );
    }
  }

  void _redirectToVerification(Users user) {
    final country = user.country.trim().isEmpty ? "RDC" : user.country.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationPage(
          userID: user.userID,
          email: user.email,
          roleID: user.roleID,
          password: _passwordCtrl.text,
          password_crypte: user.password,
          firstname: user.firstname,
          lastname: user.lastname,
          username: user.username,
          telephone: user.telephone.toString(),
          country: country,
          indicatif: _indicatif(country),
        ),
      ),
    );
  }

  void _onLoginFailed([String? reason]) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loginFailed = true;
    });
    Toast(
      context,
      reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : AppLocalizations.of(context)!.login_failed,
      false,
    );
  }

  String _indicatif(String c) {
    switch (c) {
      case 'Bénin':
        return '+229';
      case 'RDC':
      case 'CD':
        return '+243';
      default:
        return '+243';
    }
  }

  Future<void> _firstLogin(Users user) async {
    NotificationService.subscribeToRestaurantNotifications();

    final localUser = await DatabaseHelper.getUser(user.userID);
    final lastLogin = localUser?.last_login ?? user.last_login;
    final isFirst = lastLogin == null;

    if (isFirst) {
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    } else {
      await Users.updateDerniereConnexion(user.userID);
      if (mounted) {
        Users.chooseCurvedNavigation(user.roleID, user.country, context);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: AppLocalizations.of(context)!.login_title,
        subtitle: AppLocalizations.of(context)!.login_subtitle,
        form: _buildForm(),
        footer: _buildFooter(),
      ),
    );
  }

  Widget _buildFooter() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(context);
        _nameCtrl.clear();
        _passwordCtrl.clear();
        _formKey.currentState?.reset();
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: AppLocalizations.of(context)!.dont_have_account,
          style: AppTypography.bodyLarge(
            color:
                AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
          ),
          children: [
            TextSpan(
              text: '  ${AppLocalizations.of(context)!.signup}',
              style: AppTypography.bodyLarge(
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sélecteur d'onglets ───────────────────────────
          _LoginTabSelector(
            currentTab: _loginTab,
            onTabChanged: (tab) => setState(() => _loginTab = tab),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_loginTab == LoginTab.emailPassword) ...[
            // ── Identifiant ───────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              style: AppTypography.bodyLarge(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                context,
                hint: AppLocalizations.of(context)!.username_or_email,
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return AppLocalizations.of(context)!.enter_username;
                }
                if (v.length < 4) {
                  return AppLocalizations.of(context)!.min_4_chars;
                }
                if (v.length > 80) {
                  return AppLocalizations.of(context)!.too_long_max_80;
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Mot de passe ──────────────────────────────────
            TextFormField(
              controller: _passwordCtrl,
              style: AppTypography.bodyLarge(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _performLogin(),
              decoration: _decoration(
                context,
                hint: AppLocalizations.of(context)!.password,
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return AppLocalizations.of(context)!.enter_password;
                }
                if (v.length < 8) {
                  return AppLocalizations.of(context)!
                      .signup_password_min_length;
                }
                return null;
              },
            ),

            // ── Mot de passe oublié ───────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _nameCtrl.clear();
                  _passwordCtrl.clear();
                  _formKey.currentState?.reset();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailInputScreen(listusers: _users),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)!.forgotten_password,
                  style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                      AppColors.brand,
                      AppDarkColors.brand,
                    ),
                  ),
                ),
              ),
            ),

            // ── Bannière erreur ───────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _loginFailed
                  ? Column(
                      children: [
                        _LoginErrorBanner(
                          onDismiss: () => setState(() => _loginFailed = false),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Bouton connexion ───────────────────────────────
            _GradientButton(
              label: AppLocalizations.of(context)!.login,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _performLogin,
            ),
          ] else ...[
            // ── Formulaire téléphone ──────────────────────────
            _PhoneLoginForm(isLoading: _isLoading),
          ],
        ],
      ),
    );
  }

  // ── Décoration de champ — pilules, couleurs AppColors ────
  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    Widget? suffixIcon,
    IconData? icon,
  }) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLarge(color: inkMuted),
      suffixIcon: suffixIcon,
      prefixIcon:
          icon == null ? null : Icon(icon, size: 20, color: inkMuted),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: brand, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: error, width: 1.6),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _LoginTabSelector — Onglets Email vs Téléphone
// ═══════════════════════════════════════════════════════════════

enum LoginTab { emailPassword, phone }

class _LoginTabSelector extends StatelessWidget {
  const _LoginTabSelector({
    required this.currentTab,
    required this.onTabChanged,
  });

  final LoginTab currentTab;
  final ValueChanged<LoginTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final track =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // Pastille qui glisse d'un onglet à l'autre
          AnimatedAlign(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            alignment: currentTab == LoginTab.emailPassword
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: ink.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LoginTab(
                label: AppLocalizations.of(context)!.login_email_tab,
                icon: Icons.email_outlined,
                selected: currentTab == LoginTab.emailPassword,
                onTap: () => onTabChanged(LoginTab.emailPassword),
              ),
              _LoginTab(
                label: AppLocalizations.of(context)!.login_phone_tab,
                icon: Icons.phone_outlined,
                selected: currentTab == LoginTab.phone,
                onTap: () => onTabChanged(LoginTab.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _LoginTab — bouton Email / Téléphone individuel
// ═══════════════════════════════════════════════════════════

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: AppTypography.labelMedium(
              color: selected ? brand : inkMuted,
            ).copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: selected ? brand : inkMuted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _GradientButton — pilule en dégradé + ombre
// (dégradé/ombre sur le Container, effet d'appui sur un Material rogné
//  → aucun coin carré visible)
// ═══════════════════════════════════════════════════════════

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final brandColor = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final radius = BorderRadius.circular(999);
    final disabled = onPressed == null && !isLoading;

    return Opacity(
      opacity: disabled ? 0.5 : (isLoading ? 0.8 : 1),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [brandColor, brandColor.withValues(alpha: 0.85)],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: brandColor.withValues(
                  alpha: (isLoading || disabled) ? 0.10 : 0.32),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? Swirling(
                        key: const ValueKey('loading'),
                        size: 34,
                        color: Colors.white,
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PhoneLoginForm — Formulaire téléphone + OTP
// ════════════════════════════════════════════════════════════════

class _PhoneLoginForm extends ConsumerStatefulWidget {
  const _PhoneLoginForm({required this.isLoading});

  final bool isLoading;

  @override
  ConsumerState<_PhoneLoginForm> createState() => _PhoneLoginFormState();
}

class _PhoneLoginFormState extends ConsumerState<_PhoneLoginForm> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _otpSent = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String _country = CountryUtil.rdc;
  bool _isLoading = false;

  // ── Maps drapeaux / indicatifs ────────────────────────────
  final Map<String, String> _countryFlags = const {
    'RDC': '🇨🇩',
    'Bénin': '🇧🇯',
  };

  final Map<String, String> _countryCodes = const {
    'RDC': '+243',
    'Bénin': '+229',
  };

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Cooldown renvoi OTP ───────────────────────────────────
  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  // ── Envoi OTP ─────────────────────────────────────────────
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final closeLoader = _showAuthLoader(context);
    try {
      final cloudFunction = ParseCloudFunction('sendOTP');
      final response = await cloudFunction.execute(parameters: {
        'phone': phoneE164ForCountry(
          phone: _phoneCtrl.text,
          country: _country,
        ),
        'country': _country,
      });
      if (mounted) {
        if (response.success &&
            response.result is Map &&
            response.result['success'] == true) {
          setState(() => _otpSent = true);
          _startCooldown();
          Toast(
            context,
            AppLocalizations.of(context)!.login_otp_sent,
            true,
          );
        } else {
          Toast(
            context,
            AppLocalizations.of(context)!.login_otp_invalid,
            false,
          );
        }
      }
    } catch (e) {
      if (mounted) Toast(context, 'Erreur: $e', false);
    } finally {
      closeLoader();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Vérification OTP ──────────────────────────────────────
  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.length != 6) {
      Toast(
        context,
        AppLocalizations.of(context)!.login_otp_invalid,
        false,
      );
      return;
    }
    setState(() => _isLoading = true);
    final closeLoader = _showAuthLoader(context);
    try {
      final cloudFunction = ParseCloudFunction('verifyOTP');
      final response = await cloudFunction.execute(parameters: {
        'phone': phoneE164ForCountry(
          phone: _phoneCtrl.text,
          country: _country,
        ),
        'country': _country,
        'code': _otpCtrl.text,
        'ageConfirmed': true,
      });
      if (mounted) {
        if (response.success &&
            response.result is Map &&
            response.result['success'] == true) {
          final result = response.result as Map<String, dynamic>;
          final userMap = result['user'] as Map<String, dynamic>;
          final user = Users.fromMap(userMap);
          final role = AppRole.fromId(user.roleID);
          await SessionService.saveUserSession(
            userId: user.userID,
            role: role,
            country: user.country,
          );
          if (mounted) {
            Toast(
              context,
              AppLocalizations.of(context)!.loginSuccess,
              true,
            );
            if (user.mustChangePassword || user.isSimplified) {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                  builder: (_) => FirstLoginPasswordChange(user: user),
                ),
              );
            } else {
              Users.chooseCurvedNavigation(user.roleID, user.country, context);
            }
          }
        } else {
          final result = response.result;
          final error = result is Map ? result['error']?.toString() : null;
          Toast(
            context,
            error ?? AppLocalizations.of(context)!.login_otp_invalid,
            false,
          );
        }
      }
    } catch (e) {
      if (mounted) Toast(context, 'Erreur: $e', false);
    } finally {
      closeLoader();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Ouvre le sélecteur de pays ────────────────────────────
  Future<void> _chooseCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PhoneCountryPicker(
        currentCountry: _country,
        countryFlags: _countryFlags,
        countryCodes: _countryCodes,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _country = selected;
        _phoneCtrl.clear();
      });
    }
  }

  // ── Décoration de champ pilule ────────────────────────────
  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    Widget? suffixIcon,
    IconData? icon,
  }) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLarge(color: inkMuted),
      suffixIcon: suffixIcon,
      prefixIcon:
          icon == null ? null : Icon(icon, size: 20, color: inkMuted),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: brand, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _otpSent ? _buildOtpForm(loc) : _buildPhoneForm(loc);
  }

  // ── Formulaire saisie du téléphone ────────────────────────
  Widget _buildPhoneForm(AppLocalizations loc) {
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.login_phone_subtitle,
          style: AppTypography.bodyMedium(color: inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Tuile sélecteur de pays ───────────────────────
        _PhoneCountryTile(
          country: _country,
          flag: _countryFlags[_country] ?? '🌍',
          dialCode: _countryCodes[_country] ?? '+243',
          onTap: _chooseCountry,
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Champ téléphone ───────────────────────────────
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: AppTypography.bodyLarge(),
            decoration: _decoration(
              context,
              hint: phoneExampleForCountry(_country),
              icon: Icons.phone_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return loc.enter_phone;
              if (!isValidLocalPhoneForCountry(
                phone: v,
                country: _country,
              )) {
                return loc.login_otp_invalid;
              }
              return null;
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Bouton envoyer OTP ────────────────────────────
        _GradientButton(
          label: loc.login_send_otp,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _sendOTP,
        ),
      ],
    );
  }

  // ── Formulaire saisie de l'OTP ────────────────────────────
  Widget _buildOtpForm(AppLocalizations loc) {
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.login_otp_subtitle,
          style: AppTypography.bodyMedium(color: inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Champ OTP centré ──────────────────────────────
        TextFormField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium().copyWith(letterSpacing: 16),
          decoration: InputDecoration(
            hintText: loc.login_otp_hint,
            counterText: '',
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: brand, width: 1.6),
            ),
          ),
          validator: (v) {
            if (v == null || v.length != 6) return loc.login_otp_invalid;
            return null;
          },
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Timer / bouton renvoi ─────────────────────────
        if (_resendCooldown > 0)
          Center(
            child: Text(
              loc.login_otp_timer(_resendCooldown.toString()),
              style: AppTypography.labelMedium(color: inkMuted),
            ),
          )
        else
          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _otpSent = false);
                _phoneCtrl.clear();
                _otpCtrl.clear();
              },
              child: Text(loc.login_otp_resend),
            ),
          ),

        const SizedBox(height: AppSpacing.lg),

        // ── Bouton vérifier OTP ───────────────────────────
        _GradientButton(
          label: loc.login_otp_verify,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOTP,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PhoneCountryTile — Tuile pilule pour afficher le pays choisi
// ════════════════════════════════════════════════════════════════

class _PhoneCountryTile extends StatelessWidget {
  const _PhoneCountryTile({
    required this.country,
    required this.flag,
    required this.dialCode,
    required this.onTap,
  });

  final String country;
  final String flag;
  final String dialCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brandSurface =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);

    return Material(
      color: surface,
      shape: StadiumBorder(side: BorderSide(color: border, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: brandSurface),
                alignment: Alignment.center,
                child: Text(flag, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  country,
                  style: AppTypography.bodyLarge(color: ink),
                ),
              ),
              Text(
                dialCode,
                style: AppTypography.bodyMedium(color: inkMuted),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: inkMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PhoneCountryPicker — Bottom sheet sélection de pays
// ════════════════════════════════════════════════════════════════

class _PhoneCountryPicker extends StatelessWidget {
  const _PhoneCountryPicker({
    required this.currentCountry,
    required this.countryFlags,
    required this.countryCodes,
  });

  final String currentCountry;
  final Map<String, String> countryFlags;
  final Map<String, String> countryCodes;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final surfaceWarm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    final countries = CountryUtil.selectableCountries;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(
          top: 8,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: border.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            // ── Header titre + bouton fermer ──────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.country,
                    style: AppTypography.displayMedium(color: ink),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: inkMuted,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Barre de recherche décorative ─────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: surfaceWarm,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: inkMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.search,
                    style: AppTypography.bodyMedium(color: inkMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Liste des pays ────────────────────────────
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: countries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final c = countries[index];
                  final isSelected = c == currentCountry;
                  final flag = countryFlags[c] ?? '🌍';
                  final dial = countryCodes[c] ?? '+243';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surfaceWarm,
                      ),
                      child: Center(
                        child: Text(
                          flag,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    title: Text(
                      c,
                      style: AppTypography.bodyLarge(color: ink),
                    ),
                    subtitle: Text(
                      dial,
                      style: AppTypography.bodyMedium(color: inkMuted),
                    ),
                    trailing: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? brand : border,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: brand,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _LoginErrorBanner — Bannière d'erreur de connexion
// ════════════════════════════════════════════════════════════════

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final errorLight =
        AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: error.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: error.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icône erreur ──────────────────────────────
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ── Message ───────────────────────────────────
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.login_failed,
              style: AppTypography.labelMedium(color: error),
            ),
          ),
          // ── Bouton fermer ─────────────────────────────
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.close_rounded,
                color: error,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}