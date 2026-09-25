import 'package:dios_delices/screens/users/user_identity_rejected.dart';
import 'package:dios_delices/screens/onboarding/wait_identity_validation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constant.dart';
import '../../controllers/ui_controller.dart';
import '../../core/app_role.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../db/database_helper.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast.dart';
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
                      // Halo extérieur doux
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandColor.withValues(alpha: 0.08),
                        ),
                      ),
                      // Cercle principal
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
                            style: AppTypography.headlineLarge(),
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

class _LoginState extends ConsumerState<Login> {
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

    try {
      await SessionService.clearLocalParseSession();
      final user = await _findUser();
      if (user == null) {
        _onLoginFailed(Users.lastLoginError);
        return;
      }

      if (!await SessionService.hasParseSession()) {
        _onLoginFailed();
        return;
      }

      final role = AppRole.fromId(user.roleID);
      await SessionService.saveUserSession(
        userId: user.userID,
        role: role,
        country: user.country,
      );

      if (user.mustChangePassword) {
        if (mounted) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => FirstLoginPasswordChange(user: user),
            ),
          );
        }
        return;
      }

      if (role.isAdmin) {
        _firstLogin(user);
      } else if (user.status == 'Verified') {
        _handleApprovedUser(user);
      } else {
        _redirectToVerification(user);
      }
    } catch (e) {
      if (mounted) {
        Toast(context, AppLocalizations.of(context)!.connectError, false);
      }
      _onLoginFailed();
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

  void _handleApprovedUser(Users user) async {
    if (user.country.trim().isEmpty) {
      Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
              builder: (_) => StartAddressSaving(
                  userID: user.userID, roleID: user.roleID)));
    } else if (user.identity == "Verified") {
      _redirectToMainApp(user);
    } else if (user.identity == "En attente") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => WaitIdentityValidation()));
    } else if (user.identity == "Rejected") {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserIdentityRejected(
                  objectID: user.userID, user_roleID: user.roleID)));
    } else {
      _redirectToMainApp(user);
    }
  }

  void _redirectToMainApp(Users user) async {
    final role = AppRole.fromId(user.roleID);
    if (role.isProfessional) {
      NotificationService.subscribeToRestaurantNotifications();
      _handleRestaurantValidation(user);
    } else {
      if (role.isIndividual) {
        final r = await Restaurant.getRestaurantByUser(_restaus, user.userID);
        if (r != null) await SessionService.setRestaurantId(r.restaurantID);
      }
      NotificationService.subscribeToRestaurantNotifications();
      _firstLogin(user);
    }
  }

  void _handleRestaurantValidation(Users user) async {
    var restau = await Restaurant.getRestaurantByUser(_restaus, user.userID);

    if (restau == null) {
      await Restaurant.getAllRestaurantsDetails();
      final refreshed = await Restaurant.fetchRestaurantsFromDB();
      _restaus = refreshed;
      restau = await Restaurant.getRestaurantByUser(refreshed, user.userID);
    }

    if (!mounted) return;

    if (restau == null) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => RestaurantFormPage()));
    } else if (restau.valid == 0) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => WaitRestaurantValidation()));
    } else if (restau.valid == 1) {
      await SessionService.setRestaurantId(restau.restaurantID);
      NotificationService.subscribeToRestaurantNotifications();
      _firstLogin(user);
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
                )));
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
      onTap: () {
        Navigator.pop(context);
        _nameCtrl.clear();
        _passwordCtrl.clear();
        _formKey.currentState?.reset();
      },
      child: RichText(
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
          // ── Carte champs de connexion ─────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                    .withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)
                      .withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Identifiant ───────────────────────────
                Builder(
                  builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return TextFormField(
                      controller: _nameCtrl,
                      style:
                          AppTypography.bodyLarge(color: colorScheme.onSurface),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        hintText:
                            AppLocalizations.of(context)!.username_or_email,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return AppLocalizations.of(context)!.enter_username;
                        if (v.length < 4)
                          return AppLocalizations.of(context)!.min_4_chars;
                        if (v.length > 80)
                          return AppLocalizations.of(context)!.too_long_max_80;
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Mot de passe ──────────────────────────
                Builder(
                  builder: (context) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return TextFormField(
                      controller: _passwordCtrl,
                      style:
                          AppTypography.bodyLarge(color: colorScheme.onSurface),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _performLogin(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        hintText: AppLocalizations.of(context)!.password,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return AppLocalizations.of(context)!.enter_password;
                        if (v.length < 6)
                          return AppLocalizations.of(context)!.min_6_chars;
                        return null;
                      },
                    );
                  },
                ),
              ],
            ),
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.forgotten_password,
                style: AppTypography.labelMedium(
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                ),
              ),
            ),
          ),

          // ── Bannière erreur animée ────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
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

          const SizedBox(height: AppSpacing.sm),

          // ── Bouton connexion avec gradient ────────────────
          _GradientButton(
            label: AppLocalizations.of(context)!.login,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _performLogin,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _GradientButton — Bouton réutilisable avec gradient + ombre
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

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading || onPressed == null
              ? null
              : LinearGradient(
                  colors: [
                    brandColor,
                    brandColor.withValues(alpha: 0.80),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isLoading || onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: onPressed,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
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
// _LoginErrorBanner — Bandeau d'erreur dismissible amélioré
// ═══════════════════════════════════════════════════════════
class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.resolve(
          AppColors.errorLight,
          AppColors.errorLight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.login_failed,
              style: AppTypography.labelMedium(color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.error,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
