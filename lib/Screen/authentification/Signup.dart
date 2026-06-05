import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../modeles/users.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_number.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/toast.dart';
import '../legal/CGVPage.dart';
import '../legal/LegalPage.dart';
import '../legal/PrivacyPolicyPage.dart';
import '../../mails/mails.dart';
import '../../services/session_service.dart';
import '../../widgets/auth_shell.dart';
import '../verif_confirm/VerificationPage.dart';
import 'Login.dart';
import '../../utils/strings.dart';

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

  // ── État formulaire ──────────────────────────────────────
  bool _termsAccepted = false;
  bool _isLoading = false;
  int _signupRole = 2;
  String _permisType = 'moto';
  String _selectedCountry = 'Bénin';

  // ── Données pays ─────────────────────────────────────────
  static const Map<String, String> _countryCodes = {
    'France': '+33',
    'Bénin': '+229',
    "Côte d'Ivoire": '+225',
  };
  static const Map<String, String> _countryFlags = {
    'France': '🇫🇷',
    'Bénin': '🇧🇯',
    "Côte d'Ivoire": '🇨🇮',
  };
  static const Map<String, int> _phoneLengths = {
    'France': 10,
    'Bénin': 10,
    "Côte d'Ivoire": 8,
  };

  final _formKey = GlobalKey<FormState>();
  final _simpleUIController = SimpleUIController();

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfCtrl.dispose();
    _telephoneCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: AppLocalizations.of(context)!.signup_title,
        subtitle: AppLocalizations.of(context)!.signup_subtitle,
        form: _buildForm(),
        footer: _buildFooter(),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const Login()),
        );
        _formKey.currentState?.reset();
        _clearFields();
        _simpleUIController.isObscure = true;
      },
      child: RichText(
        text: TextSpan(
          text: AppLocalizations.of(context)!.already_have_account,
          style: AppTypography.bodyLarge(color: AppColors.inkMuted),
          children: [
            TextSpan(
              text: '  ${AppLocalizations.of(context)!.login}',
              style: AppTypography.bodyLarge(color: AppColors.brand).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulaire ────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Sélecteur de rôle ──────────────────────────
          _RoleSelector(
            selectedRole: _signupRole,
            onRoleChanged: (r) => setState(() => _signupRole = r),
          ),

          // ── Type de véhicule (livreur seulement) ─────────
          if (_signupRole == 5) ...[
            const SizedBox(height: AppSpacing.md),
            _VehicleSelector(
              value: _permisType,
              onChanged: (v) => setState(() => _permisType = v),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── 2. Identité ───────────────────────────────────
          _SectionLabel(
            icon: Icons.person_outline_rounded,
            label: 'Identité',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  controller: _firstnameCtrl,
                  hint: AppLocalizations.of(context)!.firstname,
                  validator:
                      _minLengthValidator(4, AppLocalizations.of(context)!.enter_firstname),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FormField(
                  controller: _lastnameCtrl,
                  hint: AppLocalizations.of(context)!.lastname,
                  validator:
                      _minLengthValidator(4, AppLocalizations.of(context)!.enter_lastname),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _FormField(
            controller: _usernameCtrl,
            hint: AppLocalizations.of(context)!.username,
            prefixIcon: Icons.alternate_email_rounded,
            validator: _minLengthValidator(4, AppLocalizations.of(context)!.enter_username),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── 3. Contact ────────────────────────────────────
          _SectionLabel(
            icon: Icons.contact_mail_outlined,
            label: 'Contact',
          ),
          const SizedBox(height: AppSpacing.sm),
          _FormField(
            controller: _emailCtrl,
            hint: AppLocalizations.of(context)!.email,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => !EmailValidator.validate(v ?? '')
                ? AppLocalizations.of(context)!.enter_valid_email
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Pays
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            isExpanded: true,
            style: AppTypography.bodyLarge(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            selectedItemBuilder: (_) => _countryCodes.keys
                .map((c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_countryFlags[c]} $c  ${_countryCodes[c]}',
                        style: AppTypography.bodyLarge(),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedCountry = v!;
              _telephoneCtrl.clear();
            }),
            items: _countryCodes.keys
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        '${_countryFlags[c]}  $c  ${_countryCodes[c]}',
                        style: AppTypography.bodyLarge(),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Téléphone
          Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return TextFormField(
                controller: _telephoneCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyLarge(color: colorScheme.onSurface),
                inputFormatters: _selectedCountry == 'Bénin'
                    ? [BeninPhoneInputFormatter()]
                    : [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: _selectedCountry == 'Bénin'
                      ? '01 xx xx xx xx'
                      : AppLocalizations.of(context)!.phone_number,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return AppLocalizations.of(context)!.enter_phone;
                  if (_selectedCountry == 'Bénin' && !isValidBeninLocalPhone(v))
                    return AppLocalizations.of(context)!.benin_phone_format;
                  if (phoneDigits(v).length != _phoneLengths[_selectedCountry]!)
                    return Strings.get('${_phoneLengths[_selectedCountry]} chiffres', '${_phoneLengths[_selectedCountry]} digits');
                  return null;
                },
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── 4. Sécurité ───────────────────────────────────
          _SectionLabel(
            icon: Icons.lock_outline_rounded,
            label: 'Sécurité',
          ),
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: _simpleUIController,
            builder: (context, __) {
              final colorScheme = Theme.of(context).colorScheme;
              return TextFormField(
                controller: _passwordCtrl,
                style: AppTypography.bodyLarge(color: colorScheme.onSurface),
                obscureText: _simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  hintText: AppLocalizations.of(context)!.password,
                  suffixIcon: IconButton(
                    icon: Icon(_simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: _simpleUIController.isObscureActive,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Indicateurs de force du mot de passe
          _PasswordStrengthIndicator(controller: _passwordCtrl),

          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: _simpleUIController,
            builder: (context, __) {
              final colorScheme = Theme.of(context).colorScheme;
              return TextFormField(
                controller: _passwordConfCtrl,
                style: AppTypography.bodyLarge(color: colorScheme.onSurface),
                obscureText: _simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  hintText: AppLocalizations.of(context)!.confirm_password,
                  suffixIcon: IconButton(
                    icon: Icon(_simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: _simpleUIController.isObscureActive,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return AppLocalizations.of(context)!.confirm_password_required;
                  if (v != _passwordCtrl.text)
                    return AppLocalizations.of(context)!.passwords_do_not_match;
                  return null;
                },
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── 5. CGU ────────────────────────────────────────
          _TermsCheckbox(
            accepted: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── 6. Bouton inscription ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (!_termsAccepted) {
                  Toast(context, "Veuillez accepter les conditions.", false);
                  return;
                }
                final encrypted =
                    await Users.encryptPassword(_passwordCtrl.text);
                final result = await Users.manageUser(
                  roleID: _signupRole,
                  password: _passwordCtrl.text,
                  password_crypte: encrypted,
                  firstname: _firstnameCtrl.text,
                  lastname: _lastnameCtrl.text,
                  username: _usernameCtrl.text,
                  email: _emailCtrl.text,
                  telephone: phoneDigits(_telephoneCtrl.text),
                  country: _selectedCountry,
                  status: '',
                  identity: '',
                  addressID: 0,
                );
                if (result is int) {
                  await SessionService.saveUserSession(
                    userId: result,
                    role: AppRole.fromId(_signupRole),
                    country: _selectedCountry,
                    email: _emailCtrl.text,
                  );
                  sendVerificationEmail(context, _emailCtrl.text);
                  Toast(context, "Compte créé ! Vérifiez votre email.", true);
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerificationPage(
                          email: _emailCtrl.text,
                          username: _usernameCtrl.text,
                          userID: result,
                          roleID: _signupRole,
                          telephone: phoneDigits(_telephoneCtrl.text),
                          password_crypte: encrypted,
                          password: _passwordCtrl.text,
                          firstname: _firstnameCtrl.text,
                          country: _selectedCountry,
                          indicatif: _countryCodes[_selectedCountry] ?? '+229',
                          lastname: _lastnameCtrl.text,
                        ),
                      ),
                    );
                  }
                } else {
                  debugPrint('Signup error: $result');
                  Toast(context, "Erreur : $result", false);
                }
              },
              child: Text(AppLocalizations.of(context)!.signup),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logique inscription ───────────────────────────────────
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      Toast(context, 'Veuillez accepter les conditions.', false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final encrypted = await Users.encryptPassword(_passwordCtrl.text);
      final result = await Users.manageUser(
        roleID: _signupRole,
        password: _passwordCtrl.text,
        password_crypte: encrypted,
        firstname: _firstnameCtrl.text,
        lastname: _lastnameCtrl.text,
        username: _usernameCtrl.text,
        email: _emailCtrl.text,
        telephone: phoneDigits(_telephoneCtrl.text),
        country: _selectedCountry,
        status: '',
        identity: '',
        addressID: 0,
      );

      if (!mounted) return;

      if (result is int) {
        await SessionService.saveUserSession(
          userId: result,
          role: AppRole.fromId(_signupRole),
          country: _selectedCountry,
        );
        sendVerificationEmail(context, _emailCtrl.text);
        Toast(context, 'Compte créé ! Vérifiez votre email.', true);
        if (mounted) {
          Users.chooseCurvedNavigation(_signupRole, _selectedCountry, context);
        }
      } else {
        debugPrint('Signup error: $result');
        Toast(context, 'Erreur : $result', false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  String? Function(String?) _minLengthValidator(int min, String emptyMsg) {
    return (v) {
      if (v == null || v.isEmpty) return emptyMsg;
      if (v.length < min) return AppLocalizations.of(context)!.min_4_chars;
      return null;
    };
  }

  void _clearFields() {
    _firstnameCtrl.clear();
    _lastnameCtrl.clear();
    _usernameCtrl.clear();
    _emailCtrl.clear();
    _passwordCtrl.clear();
    _passwordConfCtrl.clear();
    _telephoneCtrl.clear();
  }
}

// ═══════════════════════════════════════════════════════════
// _RoleSelector — Segment Client / Livreur
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.resolve(
            AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(
                    AppColors.border, AppDarkColors.border)
                .withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _RoleTab(
            label: 'Client',
            icon: Icons.person_rounded,
            selected: selectedRole == 2,
            onTap: () => onRoleChanged(2),
          ),
          _RoleTab(
            label: 'Livreur',
            icon: Icons.delivery_dining_rounded,
            selected: selectedRole == 5,
            onTap: () => onRoleChanged(5),
          ),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.brand : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium(
                  color: selected ? AppColors.brand : AppColors.inkMuted,
                ).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _VehicleSelector — Chips véhicule pour livreur
// ═══════════════════════════════════════════════════════════
class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const List<_Vehicle> _vehicles = [
    _Vehicle(value: 'moto', label: 'Moto', icon: Icons.motorcycle_rounded),
    _Vehicle(value: 'velo', label: 'Vélo', icon: Icons.pedal_bike_rounded),
    _Vehicle(
        value: 'voiture', label: 'Voiture', icon: Icons.directions_car_rounded),
  ];

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de véhicule',
          style: AppTypography.labelMedium(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _vehicles.map((v) {
            final selected = value == v.value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v.value),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: EdgeInsets.only(
                    right: v.value != 'voiture' ? AppSpacing.sm : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface)
                        : AppColors.resolve(
                            AppColors.card, AppDarkColors.card),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected
                          ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                              .withValues(alpha: 0.4)
                          : AppColors.resolve(
                              AppColors.border, AppDarkColors.border),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        v.icon,
                        size: 22,
                        color: selected ? AppColors.brand : AppColors.inkMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.label,
                        style: AppTypography.labelMedium(
                          color:
                              selected ? AppColors.brand : AppColors.inkMuted,
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
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;
}

// ═══════════════════════════════════════════════════════════
// _SectionLabel — En-tête de section avec icône + ligne
// ═══════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.resolve(
                AppColors.brandSurface, AppDarkColors.brandSurface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 15, color: AppColors.brand),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.labelLarge(
              color:
                  AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.resolve(
                AppColors.border, AppDarkColors.border),
          ),
        ),
      ],
    );
  }
}

// _FormField — Champ texte réutilisable
class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      style: AppTypography.bodyLarge(color: colorScheme.onSurface),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        hintText: hint,
      ),
      validator: validator,
    );
  }
}

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
    widget.controller.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final t = widget.controller.text;
    setState(() {
      _hasMin = t.length >= 8;
      _hasUpper = t.contains(RegExp(r'[A-Z]'));
      _hasNumber = RegExp(r'\d').allMatches(t).length >= 3;
      _hasSpecial = t.contains(RegExp(r'[^a-zA-Z0-9]'));
    });
  }

  int get _score =>
      (_hasMin ? 1 : 0) +
      (_hasUpper ? 1 : 0) +
      (_hasNumber ? 1 : 0) +
      (_hasSpecial ? 1 : 0);

  Color get _strengthColor {
    switch (_score) {
      case 4:
        return AppColors.success;
      case 3:
        return AppColors.accent;
      case 2:
        return const Color(0xFFF59E0B);
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(
            AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.resolve(
                    AppColors.border, AppDarkColors.border)
                .withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barre de force
          Row(
            children: List.generate(4, (i) {
              final filled = i < _score;
              return Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? _strengthColor
                        : AppColors.resolve(
                            AppColors.border, AppDarkColors.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Critères en grille 2×2
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Criterion(ok: _hasMin, label: '8 caractères min.'),
              _Criterion(ok: _hasUpper, label: '1 majuscule'),
              _Criterion(ok: _hasNumber, label: '3 chiffres'),
              _Criterion(ok: _hasSpecial, label: '1 caractère spécial'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.ok, required this.label});
  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Icon(
            ok
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            key: ValueKey(ok),
            size: 14,
            color: ok ? AppColors.success : AppColors.inkSubtle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelMedium(
            color: ok ? AppColors.success : AppColors.inkSubtle,
          ).copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _TermsCheckbox — Case CGU sobre
// ═══════════════════════════════════════════════════════════
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.accepted,
    required this.onChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () => onChanged(!accepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Case à cocher personnalisée
          AnimatedContainer(
            duration: AppMotion.fast,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accepted ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accepted ? AppColors.brand : AppColors.border,
                width: 1.5,
              ),
            ),
            child: accepted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CGVPage())),
              child: RichText(
                text: TextSpan(
                  style: AppTypography.bodyMedium(color: accepted ? AppColors.ink : AppColors.inkMuted),
                  children: [
                    TextSpan(text: Strings.get('J\'accepte les ', 'I accept the ')),
                    TextSpan(text: Strings.get('conditions d\'utilisation', 'terms of use'), style: TextStyle(color: AppColors.brand, decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
