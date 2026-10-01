import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../constants/constant.dart';
import '../../controllers/ui_controller.dart';
import '../../core/app_role.dart';
import '../../l10n/app_localizations.dart';
import '../../models/users.dart';
import '../../db/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_number.dart';
import '../../utils/country_util.dart';
import '../../utils/toast.dart';
import '../legal/cgv_page.dart';
import '../../services/session_service.dart';
import '../../services/node_auth_service.dart';
import '../../widgets/auth_shell.dart';
import '../onboarding/verification_page.dart';
import 'login.dart';

// ═══════════════════════════════════════════════════════════
// SignUpView — Inscription en 3 étapes
// ═══════════════════════════════════════════════════════════

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  // ── Contrôleurs ──────────────────────────────────────────
  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();

  // ── Focus nodes ──────────────────────────────────────────
  final _lastnameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfFocus = FocusNode();

  // ── Stepper ───────────────────────────────────────────────
  int _currentStep = 0;
  static const int _totalSteps = 3;

  // ── État formulaire ───────────────────────────────────────
  bool _termsAccepted = false;
  bool _ageConfirmed = false;
  bool _isLoading = false;
  bool _isDetectingCountry = false;
  int _signupRole = AppRole.individual.id;
  String _permisType = 'moto';
  String _selectedCountry = CountryUtil.rdc;

  // ── Clés de formulaire par étape ──────────────────────────
  final _formKey0 = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  final _simpleUIController = SimpleUIController();

  // ── Données pays ──────────────────────────────────────────
  static const Map<String, String> _countryCodes = {
    CountryUtil.rdc: '+243',
    CountryUtil.benin: '+229',
  };
  static const Map<String, String> _countryFlags = {
    CountryUtil.rdc: '🇨🇩',
    CountryUtil.benin: '🇧🇯',
  };

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _detectCountry();
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfCtrl.dispose();
    _telephoneCtrl.dispose();
    _lastnameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfFocus.dispose();
    super.dispose();
  }

  // ── Détection pays ────────────────────────────────────────
  Future<void> _detectCountry() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      if (mounted) setState(() => _isDetectingCountry = true);

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (placemarks.isNotEmpty) {
        final country = (placemarks.first.country ?? '').toLowerCase();
        final detected = CountryUtil.allowBeninTestMode &&
                (country.contains('benin') || country.contains('bénin'))
            ? CountryUtil.benin
            : (country.contains('démocratique') ||
                    country.contains('democratic') ||
                    country.contains('kinshasa'))
                ? CountryUtil.rdc
                : null;

        if (detected != null && mounted) {
          setState(() => _selectedCountry = detected);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isDetectingCountry = false);
    }
  }

  // ── Sélecteur pays ────────────────────────────────────────
  Future<void> _chooseCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPicker(
        selectedCountry: _selectedCountry,
        countryCodes: _countryCodes,
        countryFlags: _countryFlags,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCountry = selected;
        _telephoneCtrl.clear();
      });
    }
  }

  // ── Navigation entre étapes ───────────────────────────────
  void _nextStep() {
    bool valid;
    switch (_currentStep) {
      case 0:
        valid = _formKey0.currentState?.validate() ?? false;
        break;
      case 1:
        valid = _formKey1.currentState?.validate() ?? false;
        break;
      default:
        valid = false;
    }
    if (!valid) return;
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDriver = _signupRole == AppRole.livreur.id;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: isDriver ? l10n.signup_driver_title : l10n.signup_customer_title,
        subtitle: isDriver
            ? l10n.signup_driver_subtitle
            : l10n.signup_customer_subtitle,
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepProgressBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
        footer: _buildFooter(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      default:
        return _buildStep2();
    }
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 0 — Profil
  // ══════════════════════════════════════════════════════════
  Widget _buildStep0() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoleSelector(
            selectedRole: _signupRole,
            onRoleChanged: (r) => setState(() => _signupRole = r),
          ),

          if (_signupRole == AppRole.livreur.id) ...[
            const SizedBox(height: AppSpacing.lg),
            _VehicleSelector(
              value: _permisType,
              onChanged: (v) => setState(() => _permisType = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // Prénom et Nom côte à côte, sans labels extérieurs
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstnameCtrl,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _lastnameFocus.requestFocus(),
                  style: _fieldTextStyle(context),
                  decoration:
                      _decoration(context, hint: l10n.signup_first_name),
                  validator: _minValidator(2, l10n.signup_min_chars(2)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _lastnameCtrl,
                  focusNode: _lastnameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                  style: _fieldTextStyle(context),
                  decoration: _decoration(context, hint: l10n.signup_last_name),
                  validator: _minValidator(2, l10n.signup_min_chars(2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Nom d'utilisateur
          TextFormField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.done,
            style: _fieldTextStyle(context),
            decoration: _decoration(context, hint: l10n.signup_username),
            validator: _minValidator(4, l10n.signup_username_min_chars),
          ),
          const SizedBox(height: AppSpacing.xl),

          _StepButton(
            label: l10n.signup_continue,
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 1 — Coordonnées
  // ══════════════════════════════════════════════════════════
  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email
          TextFormField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
            keyboardType: TextInputType.emailAddress,
            style: _fieldTextStyle(context),
            decoration: _decoration(context, hint: l10n.signup_email),
            validator: (v) => !EmailValidator.validate(v ?? '')
                ? l10n.signup_email_invalid
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Pays (adapté au look pilule)
          _CountryTile(
            selectedCountry: _selectedCountry,
            isDetecting: _isDetectingCountry,
            countryFlags: _countryFlags,
            countryCodes: _countryCodes,
            onTap: _chooseCountry,
          ),
          const SizedBox(height: AppSpacing.md),

          // Téléphone
          TextFormField(
            controller: _telephoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            style: _fieldTextStyle(context),
            inputFormatters: [
              CountryPhoneInputFormatter(_selectedCountry),
            ],
            decoration: _decoration(
              context,
              hint: l10n.signup_phone_hint(
                phoneExampleForCountry(_selectedCountry),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.signup_phone_required;
              if (!isValidLocalPhoneForCountry(
                phone: v,
                country: _selectedCountry,
              )) {
                return l10n.signup_phone_format(
                  phoneExampleForCountry(_selectedCountry),
                );
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              _BackButton(onPressed: _prevStep),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StepButton(
                  label: l10n.signup_continue,
                  onPressed: _nextStep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 2 — Sécurité + CGU
  // ══════════════════════════════════════════════════════════
  Widget _buildStep2() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mot de passe
          ListenableBuilder(
            listenable: _simpleUIController,
            builder: (context, _) => TextFormField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              obscureText: _simpleUIController.isObscure,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _passwordConfFocus.requestFocus(),
              style: _fieldTextStyle(context),
              decoration: _decoration(
                context,
                hint: l10n.signup_password_hint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _simpleUIController.isObscureActive,
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return l10n.signup_password_required;
                if (v.length < 8) return l10n.signup_password_min_length;
                if (!v.contains(RegExp(r'[A-Z]')))
                  return l10n.signup_password_uppercase_required;
                if (!RegExp(r'\d').hasMatch(v))
                  return l10n.signup_password_digit_required;
                if (!v.contains(RegExp(r'[^a-zA-Z0-9]')))
                  return l10n.signup_password_special_required;
                return null;
              },
            ),
          ),

          if (_passwordCtrl.text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _PasswordStrengthIndicator(controller: _passwordCtrl),
          ],
          const SizedBox(height: AppSpacing.md),

          // Confirmation mot de passe
          ListenableBuilder(
            listenable: _simpleUIController,
            builder: (context, _) => TextFormField(
              controller: _passwordConfCtrl,
              focusNode: _passwordConfFocus,
              obscureText: _simpleUIController.isObscure,
              textInputAction: TextInputAction.done,
              style: _fieldTextStyle(context),
              decoration: _decoration(
                context,
                hint: l10n.signup_password_confirm_hint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _simpleUIController.isObscureActive,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return l10n.signup_password_confirm_required;
                if (v != _passwordCtrl.text)
                  return l10n.signup_password_mismatch;
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // CGU + Âge
          _TermsBlock(
            termsAccepted: _termsAccepted,
            ageConfirmed: _ageConfirmed,
            onTermsChanged: (v) => setState(() => _termsAccepted = v),
            onAgeChanged: (v) => setState(() => _ageConfirmed = v),
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              _BackButton(onPressed: _prevStep),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StepButton(
                  label: l10n.signup_create_account,
                  isLoading: _isLoading,
                  onPressed: _onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Soumission ────────────────────────────────────────────
  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey2.currentState!.validate()) return;
    if (!_termsAccepted) {
      Toast(context, l10n.signup_accept_terms_warning, false);
      return;
    }
    if (!_ageConfirmed) {
      Toast(context, l10n.signup_age_warning, false);
      return;
    }

    setState(() => _isLoading = true);

    NodeAuthSession? auth;
    try {
      final encrypted = await Users.encryptPassword(_passwordCtrl.text);

      final telephoneLocal = phoneStorageFormatForCountry(
        phone: _telephoneCtrl.text,
        country: _selectedCountry,
      );
      final telephoneE164 = phoneE164ForCountry(
        phone: _telephoneCtrl.text,
        country: _selectedCountry,
      );
      try {
        auth = await NodeAuthService.register(
          username: _usernameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          firstname: _firstnameCtrl.text,
          lastname: _lastnameCtrl.text,
          telephone: telephoneLocal,
          telephoneLocal: telephoneLocal,
          telephoneE164: telephoneE164,
          country: _selectedCountry,
          accountType: _signupRole == AppRole.livreur.id ? 'livreur' : 'client',
          ageConfirmed: _ageConfirmed,
        );
      } on NodeAuthException catch (error) {
        // Une première requête peut avoir créé le compte alors que la réponse
        // ou la navigation a été interrompue. Dans ce cas, le nouvel essai
        // reçoit 409. On reprend uniquement le même compte, jamais un compte
        // qui ne correspondrait qu'à l'e-mail ou au pseudo.
        if (error.statusCode != 409) rethrow;

        NodeAuthSession? resumedAuth;
        for (final identifier in <String>[
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
        ]) {
          try {
            final candidate = await NodeAuthService.login(
              identifier: identifier,
              password: _passwordCtrl.text,
            );
            final candidateUsername =
                candidate.user['username']?.toString().trim().toLowerCase();
            final candidateEmail =
                candidate.user['email']?.toString().trim().toLowerCase();
            final requestedUsername =
                _usernameCtrl.text.trim().toLowerCase();
            final requestedEmail = _emailCtrl.text.trim().toLowerCase();

            if (candidateUsername == requestedUsername &&
                candidateEmail == requestedEmail) {
              resumedAuth = candidate;
              break;
            }
          } on NodeAuthException catch (loginError) {
            // Un profil métier manquant correspond au même compte orphelin
            // que le 409 initial. On conserve donc l'erreur d'inscription,
            // au lieu d'afficher le 404 secondaire renvoyé par le login.
            if (loginError.statusCode != 401 &&
                loginError.statusCode != 404) {
              rethrow;
            }
          }
        }

        if (resumedAuth == null) rethrow;
        auth = resumedAuth;
      }

      if (!mounted) return;

      final authSession = auth;
      if (authSession == null) {
        throw const NodeAuthException('Session d’inscription introuvable.');
      }

      final user = Users.fromNodeAuth(authSession.user);
      final createdUserId = user.userID;

      final hasToken = authSession.token.isNotEmpty;
      final userIdValid = createdUserId > 0;

      if (!userIdValid && !hasToken) {
        final fields = <String>[
          if (authSession.user['userId'] != null)
            'userId=${authSession.user['userId']}',
          if (authSession.user['id'] != null) 'id=${authSession.user['id']}',
          if (authSession.user['userID'] != null)
            'userID=${authSession.user['userID']}',
        ];
        final detail = fields.isEmpty ? 'champ ID absent' : fields.join(', ');
        Toast(
          context,
          l10n.signup_create_error('Compte non créé côté serveur ($detail).'),
          false,
        );
        return;
      }

      int effectiveUserId = createdUserId;
      try {
        if (userIdValid) {
          await DatabaseHelper.createUser(user);
        }
        try {
          if (userIdValid) {
            await SessionService.saveNodeSession(
              token: authSession.token,
              userId: effectiveUserId,
              role: AppRole.fromId(user.roleID),
              country: user.country.isEmpty ? _selectedCountry : user.country,
              email: user.email.isEmpty ? _emailCtrl.text.trim() : user.email,
            );
          }
        } catch (_) {}
      } catch (_) {
        if (!userIdValid) effectiveUserId = 0;
      }

      if (!mounted) return;

      final navigatorUserId = effectiveUserId > 0
          ? effectiveUserId
          : (int.tryParse(authSession.user['userId']?.toString() ??
                  authSession.user['id']?.toString() ??
                  '') ??
              0);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationPage(
            email: _emailCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
            userID: navigatorUserId,
            roleID: user.roleID,
            telephone: telephoneLocal,
            password_crypte: encrypted,
            firstname: _firstnameCtrl.text.trim(),
            country: _selectedCountry,
            indicatif: _countryCodes[_selectedCountry] ?? '+243',
            lastname: _lastnameCtrl.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isAuthEx = e is NodeAuthException;
      final baseMessage = isAuthEx ? e.message : e.toString();
      final statusHint =
          isAuthEx && e.statusCode != null ? ' (HTTP ${e.statusCode})' : '';
      final userMessage =
          auth == null ? '$baseMessage$statusHint' : baseMessage;
      Toast(context, userMessage, false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const Login()),
        );
        _clearFields();
        _simpleUIController.isObscure = true;
      },
      child: RichText(
        text: TextSpan(
          text: '${l10n.already_have_account}  ',
          style: AppTypography.bodyLarge(
            color:
                AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
          ),
          children: [
            TextSpan(
              text: l10n.login,
              style: AppTypography.bodyLarge(
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers & Style Inputs (Couleurs préservées) ───────────
  TextStyle _fieldTextStyle(BuildContext context) =>
      AppTypography.bodyLarge(color: Theme.of(context).colorScheme.onSurface);

  // LA MAGIE OPÈRE ICI : Tes couleurs sont préservées, mais le look change (plus d'icône, paddings adaptés)
  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    Widget? suffixIcon,
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
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 18), // Élargi pour l'effet pilule
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

  String? Function(String?) _minValidator(int min, String msg) =>
      (v) => (v == null || v.trim().length < min) ? msg : null;

  void _clearFields() {
    for (final c in [
      _firstnameCtrl,
      _lastnameCtrl,
      _usernameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _passwordConfCtrl,
      _telephoneCtrl,
    ]) {
      c.clear();
    }
  }
}

// ═══════════════════════════════════════════════════════════
// _StepLabel / _StepHeading — Eyebrow + titre court par étape,
// pour remplacer les petits labels épars par un vrai repère visuel
// ═══════════════════════════════════════════════════════════
class _StepLabel {
  const _StepLabel({required this.eyebrow, required this.heading});
  final String eyebrow;
  final String heading;
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.label});
  final _StepLabel label;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Column(
        key: ValueKey(label.eyebrow),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.eyebrow.toUpperCase(),
                style: AppTypography.labelMedium(color: brand).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label.heading,
            style: AppTypography.labelLarge(color: ink)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _SectionLabel — Petit repère "eyebrow" réutilisé pour les
// sous-sections du formulaire (rôle, véhicule…)
// ═══════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: brand, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: AppTypography.labelMedium(color: inkMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StepProgressBar — Identique, couleurs conservées
// ═══════════════════════════════════════════════════════════
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i <= currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: 6,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? brand : border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StepButton — Couleurs et ombres conservées
// ═══════════════════════════════════════════════════════════
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999), // Rendu très arrondi (Pilule)
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: isLoading ? 0.12 : 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: brand.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: isLoading ? null : onPressed,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    key: const ValueKey('label'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _BackButton — Adapté pour rester cohérent
// ═══════════════════════════════════════════════════════════
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);

    return Material(
      color: card,
      shape: CircleBorder(side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.arrow_back_rounded,
            color: ink,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _CountryTile — Modifié pour coller à la forme des TextFields
// ═══════════════════════════════════════════════════════════
class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.selectedCountry,
    required this.isDetecting,
    required this.countryFlags,
    required this.countryCodes,
    required this.onTap,
  });

  final String selectedCountry;
  final bool isDetecting;
  final Map<String, String> countryFlags;
  final Map<String, String> countryCodes;
  final VoidCallback onTap;

  String _countryName(AppLocalizations l10n, String country) =>
      CountryUtil.isBenin(country)
          ? l10n.signup_country_benin
          : l10n.signup_country_drc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              Icons.public_rounded,
              color:
                  AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
              size: 20,
            ),
            const SizedBox(width: 10),
            if (isDetecting) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.signup_country_detecting,
                style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted),
                ),
              ),
            ] else ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${countryFlags[selectedCountry] ?? ''} ${_countryName(l10n, selectedCountry)}',
                      style: AppTypography.bodyLarge(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l10n.signup_country_calling_code(
                        countryCodes[selectedCountry] ?? '',
                      ),
                      style: AppTypography.labelMedium(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _CountryPicker — Bottom sheet moderne avec drapeau + radio
// ═══════════════════════════════════════════════════════════
class _CountryPicker extends StatelessWidget {
  const _CountryPicker({
    required this.selectedCountry,
    required this.countryCodes,
    required this.countryFlags,
  });

  final String selectedCountry;
  final Map<String, String> countryCodes;
  final Map<String, String> countryFlags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    final countries = CountryUtil.selectableCountries;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            // Titre + bouton fermer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.signup_choose_country,
                      style: AppTypography.labelLarge(color: ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: inkMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Zone de recherche (optionnelle – visuel seulement pour l’instant)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.signup_search_country,
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: inkMuted),
                  filled: true,
                  fillColor: AppColors.resolve(
                      AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  // Si tu veux, on pourra implémenter un vrai filtre plus tard.
                },
              ),
            ),

            const SizedBox(height: 4),

            // Liste des pays
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: countries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: border.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final countryName = CountryUtil.isBenin(country)
                      ? l10n.signup_country_benin
                      : l10n.signup_country_drc;
                  final isSelected = country == selectedCountry;
                  final code = countryCodes[country] ?? '';
                  final flag = countryFlags[country] ?? '';

                  return InkWell(
                    onTap: () => Navigator.pop(context, country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          // Avatar drapeau
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.surfaceWarm,
                                  AppDarkColors.surfaceWarm),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Nom + indicatif
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  countryName,
                                  style: AppTypography.bodyLarge(color: ink)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (code.isNotEmpty)
                                  Text(
                                    l10n.signup_country_calling_code(code),
                                    style: AppTypography.bodySmall(
                                        color: inkMuted),
                                  ),
                              ],
                            ),
                          ),
                          // Bouton radio
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? brand : border,
                                width: 1.6,
                              ),
                              color: isSelected
                                  ? brand.withValues(alpha: 0.10)
                                  : Colors.transparent,
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _TermsBlock — CGU + Confirmation d'âge regroupés
// ═══════════════════════════════════════════════════════════
class _TermsBlock extends StatelessWidget {
  const _TermsBlock({
    required this.termsAccepted,
    required this.ageConfirmed,
    required this.onTermsChanged,
    required this.onAgeChanged,
  });

  final bool termsAccepted;
  final bool ageConfirmed;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onAgeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // CGU
          _CheckRow(
            accepted: termsAccepted,
            onToggle: () => onTermsChanged(!termsAccepted),
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted),
                ),
                children: [
                  TextSpan(text: l10n.signup_terms_prefix),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CGVPage()),
                      ),
                      child: Text(
                        l10n.signup_terms_link,
                        style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.brand, AppDarkColors.brand),
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(
            height: AppSpacing.lg,
            color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                .withValues(alpha: 0.5),
          ),

          // Âge
          _CheckRow(
            accepted: ageConfirmed,
            onToggle: () => onAgeChanged(!ageConfirmed),
            child: Text(
              l10n.signup_age_confirmation,
              style: AppTypography.bodyMedium(
                color: AppColors.resolve(
                    AppColors.inkMuted, AppDarkColors.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _CheckRow — Ligne de case à cocher réutilisable
// ═══════════════════════════════════════════════════════════
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.accepted,
    required this.onToggle,
    required this.child,
  });

  final bool accepted;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accepted
                  ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accepted
                    ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                    : AppColors.resolve(AppColors.border, AppDarkColors.border),
                width: 1.5,
              ),
            ),
            child: accepted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RoleSelector — Client / Livreur avec description
// ═══════════════════════════════════════════════════════════
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.onRoleChanged,
  });

  final int selectedRole;
  final ValueChanged<int> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: l10n.signup_role_prompt),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _RoleTab(
              label: l10n.signup_customer_role,
              description: l10n.signup_customer_role_description,
              icon: Icons.person_rounded,
              selected: selectedRole == AppRole.individual.id,
              onTap: () => onRoleChanged(AppRole.individual.id),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoleTab(
              label: l10n.signup_driver_role,
              description: l10n.signup_driver_role_description,
              icon: Icons.delivery_dining_rounded,
              selected: selectedRole == AppRole.livreur.id,
              onTap: () => onRoleChanged(AppRole.livreur.id),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RoleTab — Badge icône circulaire + check overlay quand
// sélectionné (repris du pattern déjà utilisé dans _CountryPicker)
// ═══════════════════════════════════════════════════════════
class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? brand.withValues(alpha: 0.06) : card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? brand : border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: brand.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? brand : brand.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? Colors.white : brand,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: AppTypography.labelLarge(color: ink)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(color: inkMuted),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: brand,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _VehicleSelector — Même langage visuel que _RoleTab
// ═══════════════════════════════════════════════════════════
class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _vehicles = <_Vehicle>[
    _Vehicle(value: 'moto', labelKey: 'moto', icon: Icons.motorcycle_rounded),
    _Vehicle(
      value: 'velo',
      labelKey: 'bicycle',
      icon: Icons.pedal_bike_rounded,
    ),
    _Vehicle(
      value: 'voiture',
      labelKey: 'car',
      icon: Icons.directions_car_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: l10n.signup_vehicle_type),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _vehicles.map((v) {
            final selected = value == v.value;
            final brand =
                AppColors.resolve(AppColors.brand, AppDarkColors.brand);
            final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
            final border =
                AppColors.resolve(AppColors.border, AppDarkColors.border);

            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: v.value != 'voiture' ? AppSpacing.sm : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? brand.withValues(alpha: 0.06) : card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? brand : border,
                      width: selected ? 1.6 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: brand.withValues(alpha: 0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              selected ? brand : brand.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          v.icon,
                          size: 18,
                          color: selected ? Colors.white : brand,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        v.label(l10n),
                        style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                            AppColors.ink,
                            AppDarkColors.ink,
                          ),
                        ).copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Vehicle {
  const _Vehicle({
    required this.value,
    required this.labelKey,
    required this.icon,
  });

  final String value;
  final String labelKey;
  final IconData icon;

  String label(AppLocalizations localizations) {
    if (labelKey == 'moto') return localizations.signup_vehicle_motorcycle;
    if (labelKey == 'bicycle') return localizations.signup_vehicle_bicycle;
    return localizations.signup_vehicle_car;
  }
}

// ═══════════════════════════════════════════════════════════
// _PasswordStrengthIndicator — Version allégée
// ═══════════════════════════════════════════════════════════
class _PasswordStrengthIndicator extends StatefulWidget {
  const _PasswordStrengthIndicator({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordStrengthIndicator> createState() =>
      _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState
    extends State<_PasswordStrengthIndicator> {
  bool _hasMin = false;
  bool _hasUpper = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_evaluate);
    _evaluate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_evaluate);
    super.dispose();
  }

  void _evaluate() {
    final t = widget.controller.text;
    setState(() {
      _hasMin = t.length >= 8;
      _hasUpper = t.contains(RegExp(r'[A-Z]'));
      _hasNumber = RegExp(r'\d').hasMatch(t);
      _hasSpecial = t.contains(RegExp(r'[^a-zA-Z0-9]'));
    });
  }

  int get _score =>
      (_hasMin ? 1 : 0) +
      (_hasUpper ? 1 : 0) +
      (_hasNumber ? 1 : 0) +
      (_hasSpecial ? 1 : 0);

  String _strengthLabel(AppLocalizations l10n) {
    switch (_score) {
      case 4:
        return l10n.signup_password_strength_strong;
      case 3:
        return l10n.signup_password_strength_medium;
      case 2:
        return l10n.signup_password_strength_weak;
      default:
        return l10n.signup_password_strength_very_weak;
    }
  }

  Color get _strengthColor {
    switch (_score) {
      case 4:
        return AppColors.resolve(AppColors.success, AppDarkColors.success);
      case 3:
        return AppColors.resolve(AppColors.accent, AppDarkColors.accent);
      case 2:
        return const Color(0xFFF59E0B);
      default:
        return AppColors.resolve(AppColors.error, AppDarkColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre + label statut
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < _score
                              ? _strengthColor
                              : AppColors.resolve(
                                  AppColors.border, AppDarkColors.border),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _strengthLabel(l10n),
                  key: ValueKey(_score),
                  style: AppTypography.bodySmall(
                    color: _strengthColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Critères
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Criterion(ok: _hasMin, label: l10n.signup_password_min_8),
              _Criterion(ok: _hasUpper, label: l10n.signup_password_uppercase),
              _Criterion(ok: _hasNumber, label: l10n.signup_password_digit),
              _Criterion(ok: _hasSpecial, label: l10n.signup_password_symbol),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _Criterion — Indicateur de critère mot de passe
// ═══════════════════════════════════════════════════════════
class _Criterion extends StatelessWidget {
  const _Criterion({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AppColors.resolve(AppColors.success, AppDarkColors.success)
        : AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            ok
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            key: ValueKey(ok),
            size: 13,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall(color: color),
        ),
      ],
    );
  }
}
