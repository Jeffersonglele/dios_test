import 'package:dios_delices/screens/users/user_identity_rejected.dart';
import 'package:dios_delices/screens/onboarding/wait_identity_validation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';

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
import '../restaurants/restaurant_form_page.dart';
import '../onboarding/courier_onboarding_page.dart';
import '../../services/courier_application_service.dart';
import '../onboarding/start_address_saving.dart';
import '../restaurants/wait_restaurant_validation.dart';
import '../password/email_input_screen.dart';
import '../password/first_login_password_change.dart';
import '../onboarding/verification_page.dart';
import '../../widgets/animations.dart';
import '../../widgets/auth_kit.dart';
import '../../widgets/auth_shell.dart';
import 'signup.dart';

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
    final brandColor = AuthColors.brand;

    return Scaffold(
      backgroundColor: AuthColors.surfaceWarm,
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
                            style: AppTypography.headlineLarge(
                              color: AuthColors.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isAdmin
                                ? AppLocalizations.of(context)!
                                    .admin_welcome_body
                                : AppLocalizations.of(context)!.welcomeSubtitle,
                            style: AppTypography.bodyLarge(
                              color: AuthColors.inkMuted,
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
                      child: AuthPrimaryButton(
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

enum LoginTab { emailPassword, phone }

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  // ── Données ──────────────────────────────────────────────
  List<Users> _users = [];
  List<Restaurant> _restaus = [];

  // ── Contrôleurs ──────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  // ── État ─────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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
    _passwordFocus.dispose();
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
    if (_isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final closeLoader = showAuthLoader(context);

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

      // Email déjà vérifié côté serveur : on le mémorise, sinon le prochain
      // démarrage redemanderait le code de vérification.
      if (role.isAdmin || authenticatedUser.status == 'Verified') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);
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
      _onLoginFailed(
        mounted ? AppLocalizations.of(context)!.connectError : null,
      );
    } finally {
      closeLoader(); // sans effet s'il est déjà fermé
      if (mounted && _isLoading) setState(() => _isLoading = false);
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
    // Livreur : dossier (photo, pièce, permis) validé avant de pouvoir livrer.
    if (AppRole.fromId(user.roleID).isDelivery) {
      if (CourierApplicationService.isVerified(user.identity)) {
        await _redirectToMainApp(user);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourierApplicationService.isPending(user.identity)
                ? const WaitIdentityValidation()
                : const CourierOnboardingPage(),
          ),
        );
      }
      return;
    }
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
        MaterialPageRoute(builder: (_) => const WaitIdentityValidation()),
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
      // Demande refusée : le vendeur corrige sa fiche (le motif est affiché),
      // puis elle repart en validation.
      final resubmitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantFormPage(restaurant: restau),
        ),
      );
      if (resubmitted == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WaitRestaurantValidation()),
        );
      }
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

  /// Affiche l'erreur dans la bannière au-dessus du bouton.
  void _onLoginFailed([String? reason]) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = reason?.trim().isNotEmpty == true
          ? reason!.trim()
          : AppLocalizations.of(context)!.login_failed;
    });
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
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

  // ── Navigation ────────────────────────────────────────────
  void _resetForm() {
    _nameCtrl.clear();
    _passwordCtrl.clear();
    _formKey.currentState?.reset();
    _clearError();
  }

  void _openForgotPassword() {
    _resetForm();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmailInputScreen(listusers: _users)),
    );
  }

  /// Revient à l'inscription si on vient d'elle, sinon la remplace :
  /// la connexion peut être le premier écran (déconnexion forcée).
  void _goToSignup() {
    _resetForm();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        CupertinoPageRoute(builder: (_) => const SignUpView()),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canPop = Navigator.of(context).canPop();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: l10n.login_title,
        subtitle: l10n.login_subtitle,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
        form: _buildForm(l10n),
        footer: AuthFooterPrompt(
          prompt: l10n.login_no_account_prompt,
          action: l10n.login_create_account_link,
          onTap: _goToSignup,
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthSegmentedControl<LoginTab>(
            value: _loginTab,
            onChanged: (tab) => setState(() {
              _loginTab = tab;
              _errorMessage = null;
            }),
            segments: [
              AuthSegment(
                value: LoginTab.emailPassword,
                label: l10n.login_email_tab,
                icon: Icons.alternate_email_rounded,
              ),
              AuthSegment(
                value: LoginTab.phone,
                label: l10n.login_phone_tab,
                icon: Icons.smartphone_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.normal,
              switchInCurve: AppMotion.standard,
              switchOutCurve: AppMotion.accelerate,
              child: _loginTab == LoginTab.emailPassword
                  ? KeyedSubtree(
                      key: const ValueKey(LoginTab.emailPassword),
                      child: _buildEmailForm(l10n),
                    )
                  : const _PhoneLoginForm(key: ValueKey(LoginTab.phone)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identifiant ───────────────────────────────────
          AuthTextField(
            label: l10n.username_or_email,
            controller: _nameCtrl,
            hint: l10n.login_identifier_hint,
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onChanged: (_) => _clearError(),
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.enter_username;
              if (v.length < 4) return l10n.min_4_chars;
              if (v.length > 80) return l10n.too_long_max_80;
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md + 4),

          // ── Mot de passe + lien « oublié » ────────────────
          AuthTextField(
            label: l10n.password,
            labelTrailing: AuthTextLink(
              label: l10n.forgotten_password,
              onTap: _openForgotPassword,
            ),
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _clearError(),
            onFieldSubmitted: (_) => _performLogin(),
            suffix: AuthObscureToggle(
              obscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.enter_password;
              if (v.length < 8) return l10n.signup_password_min_length;
              return null;
            },
          ),

          // ── Bannière erreur ───────────────────────────────
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            child: _errorMessage == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: AuthErrorBanner(
                      message: _errorMessage!,
                      onDismiss: _clearError,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Bouton connexion ───────────────────────────────
          AuthPrimaryButton(
            label: l10n.login_submit,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _performLogin,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// _PhoneLoginForm — Formulaire téléphone + OTP
// ════════════════════════════════════════════════════════════════

class _PhoneLoginForm extends ConsumerStatefulWidget {
  const _PhoneLoginForm({super.key});

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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _phoneE164 =>
      phoneE164ForCountry(phone: _phoneCtrl.text, country: _country);

  // ── Cooldown renvoi OTP ───────────────────────────────────
  void _startCooldown() {
    _cooldownTimer?.cancel();
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
  /// [resend] : renvoi depuis l'écran du code, le numéro est déjà validé.
  Future<void> _sendOTP({bool resend = false}) async {
    if (_isLoading) return;
    if (!resend && !(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    final closeLoader = showAuthLoader(context);
    try {
      final cloudFunction = ParseCloudFunction('sendOTP');
      final response = await cloudFunction.execute(parameters: {
        'phone': _phoneE164,
        'country': _country,
      });
      if (mounted) {
        if (response.success &&
            response.result is Map &&
            response.result['success'] == true) {
          setState(() {
            _otpSent = true;
            _otpCtrl.clear();
          });
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
    if (_isLoading) return;
    if (_otpCtrl.text.length != 6) {
      Toast(
        context,
        AppLocalizations.of(context)!.login_otp_invalid,
        false,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    final closeLoader = showAuthLoader(context);
    try {
      final cloudFunction = ParseCloudFunction('verifyOTP');
      final response = await cloudFunction.execute(parameters: {
        'phone': _phoneE164,
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

  // ── Sélecteur de pays ─────────────────────────────────────
  Future<void> _chooseCountry() async {
    final selected = await showAuthCountryPicker(context, selected: _country);
    if (selected != null && mounted && selected != _country) {
      setState(() {
        _country = selected;
        _phoneCtrl.clear();
      });
    }
  }

  void _editPhone() {
    _cooldownTimer?.cancel();
    setState(() {
      _otpSent = false;
      _resendCooldown = 0;
      _otpCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      child: _otpSent
          ? KeyedSubtree(key: const ValueKey('otp'), child: _buildOtpStep(l10n))
          : KeyedSubtree(
              key: const ValueKey('phone'),
              child: _buildPhoneStep(l10n),
            ),
    );
  }

  // ── Étape 1 : numéro de téléphone ─────────────────────────
  Widget _buildPhoneStep(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: l10n.phone,
            controller: _phoneCtrl,
            hint: phoneExampleForCountry(_country),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [CountryPhoneInputFormatter(_country)],
            prefix: AuthPhonePrefix(country: _country, onTap: _chooseCountry),
            onFieldSubmitted: (_) => _sendOTP(),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.enter_phone;
              if (!isValidLocalPhoneForCountry(phone: v, country: _country)) {
                return l10n.signup_phone_format(
                  phoneExampleForCountry(_country),
                );
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _HintLine(
            icon: Icons.sms_outlined,
            text: l10n.login_phone_subtitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthPrimaryButton(
            label: l10n.login_send_otp,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendOTP,
          ),
        ],
      ),
    );
  }

  // ── Étape 2 : code reçu par SMS ───────────────────────────
  Widget _buildOtpStep(AppLocalizations l10n) {
    final displayPhone =
        '${AuthCountries.dialCode(_country)} ${_phoneCtrl.text.trim()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Rappel du numéro + modifier ──────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            color: AuthColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AuthColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuthColors.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: AuthColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.login_otp_sent_to(displayPhone),
                      style: AppTypography.labelLarge(color: AuthColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.login_otp_subtitle,
                      style: AppTypography.bodySmall(
                        color: AuthColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AuthTextLink(label: l10n.modify, onTap: _editPhone),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Code à 6 chiffres ─────────────────────────────
        PinCodeTextField(
          appContext: context,
          length: 6,
          autoFocus: true,
          autoDisposeControllers: false,
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          animationType: AnimationType.fade,
          animationDuration: AppMotion.fast,
          cursorColor: AuthColors.brand,
          backgroundColor: Colors.transparent,
          enableActiveFill: true,
          textStyle: AppTypography.titleLarge(color: AuthColors.ink),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
            fieldHeight: 56,
            fieldWidth: 46,
            borderWidth: 1,
            activeBorderWidth: 1.4,
            selectedBorderWidth: 1.6,
            activeColor: AuthColors.brand,
            selectedColor: AuthColors.brand,
            inactiveColor: AuthColors.border,
            activeFillColor: AuthColors.card,
            selectedFillColor: AuthColors.card,
            inactiveFillColor: AuthColors.card,
          ),
          onChanged: (_) {},
          onCompleted: (_) => _verifyOTP(),
        ),
        const SizedBox(height: AppSpacing.xs),

        // ── Timer / renvoi ───────────────────────────────
        Center(
          child: _resendCooldown > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AuthColors.inkSubtle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.login_otp_timer(_resendCooldown.toString()),
                        style: AppTypography.labelMedium(
                          color: AuthColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : AuthTextLink(
                  label: l10n.login_otp_resend,
                  onTap: () => _sendOTP(resend: true),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),

        AuthPrimaryButton(
          label: l10n.login_otp_verify,
          icon: Icons.check_rounded,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOTP,
        ),
      ],
    );
  }
}

/// Ligne d'aide discrète : icône + texte.
class _HintLine extends StatelessWidget {
  const _HintLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 1),
          child: Icon(icon, size: 16, color: AuthColors.inkSubtle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall(color: AuthColors.inkMuted),
          ),
        ),
      ],
    );
  }
}
