import 'package:dios_delices/Screen/utilisateurs/UserIdentityRejected.dart';
import 'package:dios_delices/Screen/verif_confirm/WaitIdentityValidation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../db/database_helper.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast.dart';
import '../../providers/users_provider.dart';
import '../restaurants/RestaurantFormPage.dart';
import '../verif_confirm/StartAddressSaving.dart';
import '../verif_confirm/StatusSelectionPage.dart';
import '../restaurants/RestaurantUpdateFormPage.dart';
import '../restaurants/WaitRestaurantValidation.dart';
import '../password/EmailInputScreen.dart';
import '../password/FirstLoginPasswordChange.dart';
import '../verif_confirm/VerificationPage.dart';
import '../../widgets/animations.dart';
import '../../widgets/auth_shell.dart';

// ═══════════════════════════════════════════════════════════
// WelcomeScreen — Écran post-inscription (inchangé logique)
// Refonte visuelle : fond brand, check animé, texte blanc
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
    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
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
                  // Cercle check animé sur fond brand doux
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const AnimatedSuccessCheck(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            _isAdmin ? 'Bienvenue Admin !' : 'Bienvenue !',
                            style: AppTypography.headlineLarge(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isAdmin
                                ? 'Votre compte administrateur a été créé avec succès.\nVous pouvez maintenant gérer la plateforme.'
                                : 'Votre compte a été créé avec succès.\nDécouvrez les meilleurs plats faits maison près de chez vous.',
                            style: AppTypography.bodyLarge(
                              color: AppColors.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  if (_showButton)
                    FadeTransition(
                      opacity: _btnFade,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _continue,
                          child: const Text('Découvrir'),
                        ),
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
// Login — Refonte complète
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
      final user = await _findUser();
      if (user == null) {
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
        if (mounted) Navigator.push(context, CupertinoPageRoute(builder: (_) => FirstLoginPasswordChange(user: user)));
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
      if (mounted)
        Toast(context, 'Erreur de connexion. Vérifiez votre réseau.', false);
      _onLoginFailed();
    }
  }

  Future<Users?> _findUser() async {
    Users? user =
        await Users.verifUser(_users, _nameCtrl.text, _passwordCtrl.text);
    if (user != null) return user;

    user = await Users.loginUser(_nameCtrl.text, _passwordCtrl.text);
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
    final restau = await Restaurant.getRestaurantByUser(_restaus, user.userID);
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
              RestaurantUpdateFormPage(user: user, restaurant: restau),
        ),
      );
    }
  }

  void _redirectToVerification(Users user) {
    final country = user.country.trim().isEmpty ? "Bénin" : user.country.trim();
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

  void _onLoginFailed() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loginFailed = true;
    });
    Toast(context, AppLocalizations.of(context)!.login_failed, false);
  }

  String _indicatif(String c) {
    switch (c) {
      case 'Bénin':
        return '+229';
      case "Côte d'Ivoire":
        return '+225';
      case 'France':
        return '+33';
      default:
        return '+229';
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
          style: AppTypography.bodyLarge(color: AppColors.inkMuted),
          children: [
            TextSpan(
              text: '  ${AppLocalizations.of(context)!.signup}',
              style: AppTypography.bodyLarge(color: AppColors.brand).copyWith(
                fontWeight: FontWeight.w700,
              ),
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
          // ── Identifiant ───────────────────────────────────
          Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return TextFormField(
                controller: _nameCtrl,
                style: AppTypography.bodyLarge(color: colorScheme.onSurface),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  hintText: AppLocalizations.of(context)!.username_or_email,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return AppLocalizations.of(context)!.enter_username;
                  if (v.length < 4) return AppLocalizations.of(context)!.min_4_chars;
                  if (v.length > 80) return 'Trop long (max 80 caractères)';
                  return null;
                },
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Mot de passe ──────────────────────────────────
          Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return TextFormField(
                controller: _passwordCtrl,
                style: AppTypography.bodyLarge(color: colorScheme.onSurface),
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return AppLocalizations.of(context)!.enter_password;
                  if (v.length < 6) return AppLocalizations.of(context)!.min_6_chars;
                  return null;
                },
              );
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.forgotten_password,
                style: AppTypography.labelMedium(color: AppColors.brand),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Bannière erreur ───────────────────────────────
          if (_loginFailed)
            _LoginErrorBanner(
              onDismiss: () => setState(() => _loginFailed = false),
            ),

          if (_loginFailed) const SizedBox(height: AppSpacing.md),

          // ── Bouton connexion ──────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _performLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.login),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _LoginErrorBanner — Bandeau d'erreur dismissible
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
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
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
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
