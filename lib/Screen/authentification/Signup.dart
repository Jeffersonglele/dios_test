import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../modeles/users.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone_number.dart';
import '../../utils/strings.dart';
import '../../utils/toast.dart';
import '../../mails/mails.dart';
import '../../widgets/auth_shell.dart';
import 'Login.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({Key? key}) : super(key: key);
  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final firstnameCtrl = TextEditingController();
  final lastnameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final passwordConfirmCtrl = TextEditingController();
  final telephoneCtrl = TextEditingController();

  bool _consentRGPD = false;
  bool _isSelected = false;
  int _signupRole = 2;
  String _permisType = 'moto';
  String _selectedCountry = "Bénin";

  final Map<String, String> _countryCodes = {
    "France": "+33",
    "Bénin": "+229",
    "Côte d'Ivoire": "+225"
  };
  final Map<String, String> _countryFlags = {
    "France": "🇫🇷",
    "Bénin": "🇧🇯",
    "Côte d'Ivoire": "🇨🇮"
  };
  final Map<String, int> _phoneLengths = {
    "France": 10,
    "Bénin": 10,
    "Côte d'Ivoire": 8
  };

  final _formKey = GlobalKey<FormState>();
  final validatorKey = GlobalKey<FlutterPwValidatorState>();
  final simpleUIController = SimpleUIController();

  @override
  void dispose() {
    firstnameCtrl.dispose();
    lastnameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    passwordConfirmCtrl.dispose();
    telephoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: Strings.of('signup_title'),
        subtitle: Strings.of('signup_subtitle'),
        form: _buildForm(),
        footer: GestureDetector(
          onTap: () {
            Navigator.push(
                context, CupertinoPageRoute(builder: (_) => const Login()));
            _formKey.currentState?.reset();
            _clearFields();
            simpleUIController.isObscure = true;
          },
          child: RichText(
            text: TextSpan(
              text: Strings.of('already_have_account'),
              style: AppTypography.bodyLarge(color: AppColors.ink),
              children: [
                TextSpan(
                  text: " ${Strings.of('login')}",
                  style: AppTypography.bodyLarge(color: AppColors.brand),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Choix rôle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _signupRole = 2),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _signupRole == 2
                            ? AppColors.card
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: _signupRole == 2
                            ? [
                                BoxShadow(
                                    color:
                                        AppColors.ink.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text('Client',
                            style: AppTypography.labelMedium(
                                color: _signupRole == 2
                                    ? AppColors.brand
                                    : AppColors.inkMuted)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _signupRole = 5),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _signupRole == 5
                            ? AppColors.card
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: _signupRole == 5
                            ? [
                                BoxShadow(
                                    color:
                                        AppColors.ink.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text('Livreur',
                            style: AppTypography.labelMedium(
                                color: _signupRole == 5
                                    ? AppColors.brand
                                    : AppColors.inkMuted)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_signupRole == 5) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _permisType,
              decoration: const InputDecoration(
                labelText: 'Type de véhicule',
                prefixIcon: Icon(Icons.motorcycle_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'moto', child: Text('Moto / Scooter')),
                DropdownMenuItem(value: 'velo', child: Text('Vélo')),
                DropdownMenuItem(value: 'voiture', child: Text('Voiture')),
              ],
              onChanged: (v) => setState(() => _permisType = v!),
            ),
          ],
          const SizedBox(height: 16),

          // Champs
          _field(
              firstnameCtrl,
              Strings.of('firstname'),
              Icons.person_outline_rounded,
              (v) => v == null || v.isEmpty
                  ? Strings.of('enter_firstname')
                  : v.length < 4
                      ? Strings.of('min_4_chars')
                      : null),
          const SizedBox(height: 14),
          _field(
              lastnameCtrl,
              Strings.of('lastname'),
              Icons.person_outline_rounded,
              (v) => v == null || v.isEmpty
                  ? Strings.of('enter_lastname')
                  : v.length < 4
                      ? Strings.of('min_4_chars')
                      : null),
          const SizedBox(height: 14),
          _field(
              usernameCtrl,
              Strings.of('username'),
              Icons.alternate_email_rounded,
              (v) => v == null || v.isEmpty
                  ? Strings.of('enter_username')
                  : v.length < 4
                      ? Strings.of('min_4_chars')
                      : null),
          const SizedBox(height: 14),
          _field(
              emailCtrl,
              Strings.of('email'),
              Icons.email_outlined,
              (v) => !EmailValidator.validate(v!)
                  ? Strings.of('enter_valid_email')
                  : null),
          const SizedBox(height: 14),

          // Pays
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            isExpanded: true,
            decoration:
                const InputDecoration(prefixIcon: Icon(Icons.flag_outlined)),
            selectedItemBuilder: (_) => _countryCodes.keys
                .map((c) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_countryFlags[c]} $c ${_countryCodes[c]}')))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedCountry = v!;
              telephoneCtrl.clear();
            }),
            items: _countryCodes.keys
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('${_countryFlags[c]} $c ${_countryCodes[c]}')))
                .toList(),
          ),
          const SizedBox(height: 14),

          // Téléphone
          TextFormField(
            controller: telephoneCtrl,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyLarge(),
            inputFormatters: _selectedCountry == 'Bénin'
                ? [BeninPhoneInputFormatter()]
                : [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined),
              hintText: _selectedCountry == 'Bénin'
                  ? '01 xx xx xx xx'
                  : Strings.of('phone_number'),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return Strings.of('enter_phone');
              if (_selectedCountry == 'Bénin' && !isValidBeninLocalPhone(v))
                return Strings.of('benin_phone_format');
              if (phoneDigits(v).length != _phoneLengths[_selectedCountry]!)
                return Strings.of('phone_length',
                    {'count': '${_phoneLengths[_selectedCountry]}'});
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Mot de passe
          ListenableBuilder(
            listenable: simpleUIController,
            builder: (_, __) => TextFormField(
              controller: passwordCtrl,
              style: AppTypography.bodyLarge(),
              obscureText: simpleUIController.isObscure,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(simpleUIController.isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => simpleUIController.isObscureActive(),
                ),
                hintText: Strings.of('password'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FlutterPwValidator(
            key: validatorKey,
            controller: passwordCtrl,
            minLength: 8,
            uppercaseCharCount: 1,
            numericCharCount: 3,
            specialCharCount: 1,
            width: 400,
            height: 150,
            onSuccess: () {},
            onFail: () {},
          ),
          const SizedBox(height: 14),

          // Confirmation
          ListenableBuilder(
            listenable: simpleUIController,
            builder: (_, __) => TextFormField(
              controller: passwordConfirmCtrl,
              style: AppTypography.bodyLarge(),
              obscureText: simpleUIController.isObscure,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(simpleUIController.isObscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => simpleUIController.isObscureActive(),
                ),
                hintText: Strings.of('confirm_password'),
              ),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return Strings.of('confirm_password_required');
                if (v != passwordCtrl.text)
                  return Strings.of('passwords_do_not_match');
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),

          // Checkbox CGU
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.brand,
            checkColor: Colors.white,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            title: Text(Strings.of('terms_acceptance'),
                style: AppTypography.bodyMedium(
                    color: _isSelected ? AppColors.ink : AppColors.brand)),
            value: _isSelected,
            onChanged: (v) => setState(() => _isSelected = v!),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 20),

          // Bouton
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (!_isSelected) {
                  Toast(context, "Veuillez accepter les conditions.", false);
                  return;
                }
                final encrypted =
                    await Users.encryptPassword(passwordCtrl.text);
                final result = await Users.manageUser(
                  roleID: _signupRole,
                  password: passwordCtrl.text,
                  password_crypte: encrypted,
                  firstname: firstnameCtrl.text,
                  lastname: lastnameCtrl.text,
                  username: usernameCtrl.text,
                  email: emailCtrl.text,
                  telephone: phoneDigits(telephoneCtrl.text),
                  country: _selectedCountry,
                  status: '',
                  identity: '',
                  addressID: 0,
                );
                if (result is int) {
                  sendVerificationEmail(context, emailCtrl.text);
                  Toast(context, "Compte créé ! Vérifiez votre email.", true);
                  if (mounted)
                    Users.chooseCurvedNavigation(
                        _signupRole, _selectedCountry, context);
                } else {
                  debugPrint('Signup error: $result');
                  Toast(context, "Erreur : $result", false);
                }
              },
              child: Text(Strings.of('signup')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      String? Function(String?)? validator) {
    return TextFormField(
      controller: ctrl,
      style: AppTypography.bodyLarge(),
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
      ),
      validator: validator,
    );
  }

  void _clearFields() {
    firstnameCtrl.clear();
    lastnameCtrl.clear();
    usernameCtrl.clear();
    emailCtrl.clear();
    passwordCtrl.clear();
    passwordConfirmCtrl.clear();
    telephoneCtrl.clear();
  }
}
