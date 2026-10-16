import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
import '../../widgets/auth_kit.dart';
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
  bool _movingForward = true;
  static const int _totalSteps = 3;

  // ── État formulaire ───────────────────────────────────────
  bool _termsAccepted = false;
  bool _ageConfirmed = false;
  bool _isLoading = false;
  bool _isDetectingCountry = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConf = true;
  int _signupRole = AppRole.individual.id;
  String _permisType = 'moto';
  String _selectedCountry = CountryUtil.rdc;

  // ── Clés de formulaire par étape ──────────────────────────
  final _formKey0 = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

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

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) return;

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
    final selected =
        await showAuthCountryPicker(context, selected: _selectedCountry);
    if (selected != null && mounted && selected != _selectedCountry) {
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _movingForward = true;
      _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _movingForward = false;
      _currentStep--;
    });
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDriver = _signupRole == AppRole.livreur.id;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      // Le retour système revient d'abord à l'étape précédente.
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prevStep();
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AuthShell(
          title:
              isDriver ? l10n.signup_driver_title : l10n.signup_customer_title,
          subtitle: isDriver
              ? l10n.signup_driver_subtitle
              : l10n.signup_customer_subtitle,
          onBack: _currentStep > 0
              ? _prevStep
              : (canPop ? () => Navigator.of(context).maybePop() : null),
          form: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(
                currentStep: _currentStep,
                labels: [
                  l10n.signup_step_profile,
                  l10n.signup_step_contact,
                  l10n.signup_step_security,
                ],
              ),
              const SizedBox(height: AppSpacing.lg + 4),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: AppMotion.standard,
                  switchOutCurve: AppMotion.accelerate,
                  transitionBuilder: (child, animation) {
                    final incoming =
                        child.key == ValueKey<int>(_currentStep);
                    final dx = (_movingForward == incoming) ? 0.06 : -0.06;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(dx, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: _buildCurrentStep(l10n),
                  ),
                ),
              ),
            ],
          ),
          footer: AuthFooterPrompt(
            prompt: l10n.already_have_account,
            action: l10n.login_submit,
            onTap: _goToLogin,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildProfileStep(l10n);
      case 1:
        return _buildContactStep(l10n);
      default:
        return _buildSecurityStep(l10n);
    }
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 1 — Profil
  // ══════════════════════════════════════════════════════════
  Widget _buildProfileStep(AppLocalizations l10n) {
    final isDriver = _signupRole == AppRole.livreur.id;
    return Form(
      key: _formKey0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFieldLabel(text: l10n.signup_role_prompt),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  label: l10n.signup_customer_role,
                  description: l10n.signup_customer_role_description,
                  icon: Icons.restaurant_menu_rounded,
                  selected: !isDriver,
                  onTap: () =>
                      setState(() => _signupRole = AppRole.individual.id),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: _RoleCard(
                  label: l10n.signup_driver_role,
                  description: l10n.signup_driver_role_description,
                  icon: Icons.delivery_dining_rounded,
                  selected: isDriver,
                  onTap: () => setState(() => _signupRole = AppRole.livreur.id),
                ),
              ),
            ],
          ),

          // ── Véhicule (livreur uniquement) ─────────────────
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: !isDriver
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md + 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthFieldLabel(text: l10n.signup_vehicle_type),
                        AuthSegmentedControl<String>(
                          value: _permisType,
                          onChanged: (v) => setState(() => _permisType = v),
                          segments: [
                            AuthSegment(
                              value: 'moto',
                              label: l10n.signup_vehicle_motorcycle,
                              icon: Icons.two_wheeler_rounded,
                            ),
                            AuthSegment(
                              value: 'velo',
                              label: l10n.signup_vehicle_bicycle,
                              icon: Icons.pedal_bike_rounded,
                            ),
                            AuthSegment(
                              value: 'voiture',
                              label: l10n.signup_vehicle_car,
                              icon: Icons.directions_car_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Identité ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AuthTextField(
                  label: l10n.signup_first_name,
                  controller: _firstnameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  onFieldSubmitted: (_) => _lastnameFocus.requestFocus(),
                  validator: _minValidator(2, l10n.signup_min_chars(2)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: AuthTextField(
                  label: l10n.signup_last_name,
                  controller: _lastnameCtrl,
                  focusNode: _lastnameFocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                  validator: _minValidator(2, l10n.signup_min_chars(2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 4),
          AuthTextField(
            label: l10n.signup_username,
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            icon: Icons.alternate_email_rounded,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.newUsername],
            onFieldSubmitted: (_) => _nextStep(),
            validator: _minValidator(4, l10n.signup_username_min_chars),
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthPrimaryButton(label: l10n.signup_continue, onPressed: _nextStep),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 2 — Coordonnées
  // ══════════════════════════════════════════════════════════
  Widget _buildContactStep(AppLocalizations l10n) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: l10n.signup_email,
            controller: _emailCtrl,
            focusNode: _emailFocus,
            hint: 'nom@exemple.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
            validator: (v) => !EmailValidator.validate(v?.trim() ?? '')
                ? l10n.signup_email_invalid
                : null,
          ),
          const SizedBox(height: AppSpacing.md + 4),
          AuthTextField(
            label: l10n.phone,
            controller: _telephoneCtrl,
            focusNode: _phoneFocus,
            hint: phoneExampleForCountry(_selectedCountry),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [CountryPhoneInputFormatter(_selectedCountry)],
            prefix: AuthPhonePrefix(
              country: _selectedCountry,
              isDetecting: _isDetectingCountry,
              onTap: _chooseCountry,
            ),
            onFieldSubmitted: (_) => _nextStep(),
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
          const SizedBox(height: AppSpacing.sm + 2),
          _CountryHint(
            text: _isDetectingCountry
                ? l10n.signup_country_detecting
                : '${l10n.country} : ${AuthCountries.name(l10n, _selectedCountry)}',
            onTap: _chooseCountry,
          ),
          const SizedBox(height: AppSpacing.xl),
          _StepActions(
            onBack: _prevStep,
            child: AuthPrimaryButton(
              label: l10n.signup_continue,
              onPressed: _nextStep,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ÉTAPE 3 — Sécurité + CGU
  // ══════════════════════════════════════════════════════════
  Widget _buildSecurityStep(AppLocalizations l10n) {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: l10n.password,
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _passwordConfFocus.requestFocus(),
            suffix: AuthObscureToggle(
              obscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.signup_password_required;
              if (v.length < 8) return l10n.signup_password_min_length;
              if (!v.contains(RegExp(r'[A-Z]'))) {
                return l10n.signup_password_uppercase_required;
              }
              if (!RegExp(r'\d').hasMatch(v)) {
                return l10n.signup_password_digit_required;
              }
              if (!v.contains(RegExp(r'[^a-zA-Z0-9]'))) {
                return l10n.signup_password_special_required;
              }
              return null;
            },
          ),
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: _passwordCtrl.text.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
                    child: _PasswordStrength(password: _passwordCtrl.text),
                  ),
          ),
          const SizedBox(height: AppSpacing.md + 4),
          AuthTextField(
            label: l10n.confirm_password,
            controller: _passwordConfCtrl,
            focusNode: _passwordConfFocus,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePasswordConf,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.newPassword],
            suffix: AuthObscureToggle(
              obscured: _obscurePasswordConf,
              onPressed: () =>
                  setState(() => _obscurePasswordConf = !_obscurePasswordConf),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return l10n.signup_password_confirm_required;
              }
              if (v != _passwordCtrl.text) return l10n.signup_password_mismatch;
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _TermsCard(
            termsAccepted: _termsAccepted,
            ageConfirmed: _ageConfirmed,
            onTermsChanged: (v) => setState(() => _termsAccepted = v),
            onAgeChanged: (v) => setState(() => _ageConfirmed = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          _StepActions(
            onBack: _prevStep,
            child: AuthPrimaryButton(
              label: l10n.signup_create_account,
              icon: Icons.check_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _onSubmit,
            ),
          ),
        ],
      ),
    );
  }

  // ── Soumission ────────────────────────────────────────────
  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    FocusManager.instance.primaryFocus?.unfocus();
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
    final closeLoader = showAuthLoader(context);

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
          // Le véhicule choisi n'était jamais transmis au serveur.
          vehicleType:
              _signupRole == AppRole.livreur.id ? _permisType : null,
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

      closeLoader();
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
            indicatif: AuthCountries.dialCode(_selectedCountry),
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
      closeLoader(); // sécurité : sans effet s'il est déjà fermé
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  void _goToLogin() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const Login()),
    );
    _clearFields();
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
    setState(() {
      _currentStep = 0;
      _movingForward = false;
      _obscurePassword = true;
      _obscurePasswordConf = true;
    });
  }
}

// ═══════════════════════════════════════════════════════════
// _StepIndicator — trois segments nommés (Profil · Coordonnées
// · Sécurité). Étapes passées cochées, étape en cours en marque.
// ═══════════════════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.labels});

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final brand = AuthColors.brand;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.standard,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= currentStep ? brand : AuthColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (i < currentStep) ...[
                      Icon(Icons.check_circle_rounded, size: 14, color: brand),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: AppMotion.fast,
                        style: AppTypography.labelMedium(
                          color: i == currentStep
                              ? AuthColors.ink
                              : (i < currentStep
                                  ? AuthColors.inkMuted
                                  : AuthColors.inkSubtle),
                        ).copyWith(
                          fontWeight: i == currentStep
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StepActions — retour d'étape + action principale
// ═══════════════════════════════════════════════════════════
class _StepActions extends StatelessWidget {
  const _StepActions({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AuthSquareButton(
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(child: child),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _RoleCard — Client / Livreur
// ═══════════════════════════════════════════════════════════
class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
    final brand = AuthColors.brand;
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: selected ? AuthColors.brandSurface : AuthColors.card,
          borderRadius: radius,
          border: Border.all(
            color: selected ? brand : AuthColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: brand.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.normal,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? brand
                              : brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 21,
                          color: selected ? Colors.white : brand,
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(selected),
                          size: 20,
                          color: selected ? brand : AuthColors.border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: AppTypography.titleSmall(color: AuthColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(color: AuthColors.inkMuted),
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
// _CountryHint — rappel du pays sous le champ téléphone
// ═══════════════════════════════════════════════════════════
class _CountryHint extends StatelessWidget {
  const _CountryHint({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_rounded, size: 16, color: AuthColors.inkSubtle),
              const SizedBox(width: 8),
              Text(
                text,
                style: AppTypography.bodySmall(color: AuthColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _TermsCard — CGU + confirmation d'âge
// ═══════════════════════════════════════════════════════════
class _TermsCard extends StatelessWidget {
  const _TermsCard({
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
    final textStyle = AppTypography.bodyMedium(color: AuthColors.inkMuted);

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AuthColors.border),
      ),
      child: Column(
        children: [
          _CheckRow(
            checked: termsAccepted,
            onToggle: () => onTermsChanged(!termsAccepted),
            child: Text.rich(
              TextSpan(
                style: textStyle,
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
                        style: textStyle.copyWith(
                          color: AuthColors.brand,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AuthColors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 50, color: AuthColors.border),
          _CheckRow(
            checked: ageConfirmed,
            onToggle: () => onAgeChanged(!ageConfirmed),
            child: Text(l10n.signup_age_confirmation, style: textStyle),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.checked,
    required this.onToggle,
    required this.child,
  });

  final bool checked;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = AuthColors.brand;

    return Semantics(
      checked: checked,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: checked ? brand : AuthColors.inkSubtle,
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _PasswordStrength — jauge + critères
// ═══════════════════════════════════════════════════════════
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasMin = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    final score = [hasMin, hasUpper, hasNumber, hasSpecial].where((ok) => ok).length;

    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final Color color;
    final String label;
    switch (score) {
      case 4:
        color = AuthColors.success;
        label = l10n.signup_password_strength_strong;
        break;
      case 3:
        color = Color.lerp(accent, AuthColors.success, 0.45)!;
        label = l10n.signup_password_strength_medium;
        break;
      case 2:
        color = accent;
        label = l10n.signup_password_strength_weak;
        break;
      default:
        color = AuthColors.error;
        label = l10n.signup_password_strength_very_weak;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < score ? color : AuthColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodySmall(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Criterion(ok: hasMin, label: l10n.signup_password_min_8),
            _Criterion(ok: hasUpper, label: l10n.signup_password_uppercase),
            _Criterion(ok: hasNumber, label: l10n.signup_password_digit),
            _Criterion(ok: hasSpecial, label: l10n.signup_password_symbol),
          ],
        ),
      ],
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final success = AuthColors.success;
    final color = ok ? success : AuthColors.inkMuted;

    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok
            ? success.withValues(alpha: 0.10)
            : AuthColors.border.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.remove_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall(color: color)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
