import 'package:flutter/material.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import '../../theme/app_theme.dart';
import '../../Controller/UiController.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../services/password_reset_validation.dart';
import '../../utils/toast.dart';
import '../../utils/strings.dart';
import 'PasswordChangeSuccessScreen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;
  const PasswordResetScreen({super.key, required this.email, required this.listusers});
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final codeCtrl = TextEditingController();
  final newPwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final simpleUIController = SimpleUIController();
  final validatorKey = GlobalKey<FlutterPwValidatorState>();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isCodeVerified = false;

  @override
  void dispose() { codeCtrl.dispose(); newPwdCtrl.dispose(); confirmCtrl.dispose(); super.dispose(); }

  Future<void> verifyCode() async {
    final valid = await verifyEmailCode(email: widget.email, code: codeCtrl.text.trim());
    if (!valid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of('invalid_or_expired_code'))));
      return;
    }
    setState(() => isCodeVerified = true);
  }

  Future<void> resetPassword() async {
    if (!isCodeVerified) { verifyCode(); return; }
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final user = await Users.getUsersByEmail(widget.listusers, widget.email);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of('user_not_found'))));
      setState(() => isLoading = false);
      return;
    }
    final validation = await PasswordResetValidation.validate(newPassword: newPwdCtrl.text, confirmPassword: confirmCtrl.text, currentPasswordHash: user.password);
    if (validation != PasswordResetValidationResult.valid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          validation == PasswordResetValidationResult.sameAsCurrentPassword ? Strings.of('same_password_error') : Strings.of('form_invalid'))));
      setState(() => isLoading = false);
      return;
    }
    final encrypted = await Users.encryptPassword(newPwdCtrl.text);
    final result = await Users.updatePassword(user.userID, encrypted);
    setState(() => isLoading = false);
    result == "success"
        ? Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeSuccessScreen()))
        : Toast(context, "Erreur : $result", false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            Text(Strings.of('reset_password_title'), style: AppTypography.headlineLarge()),
            const SizedBox(height: 8),
            Text(Strings.of('reset_password_subtitle'), style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
            const SizedBox(height: 28),
            if (!isCodeVerified) ...[
              TextFormField(
                controller: codeCtrl, keyboardType: TextInputType.number,
                style: AppTypography.bodyLarge(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  labelText: Strings.of('verification_code'),
                  hintText: Strings.of('verification_code_hint'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 56,
                child: ElevatedButton(onPressed: verifyCode, child: Text(Strings.of('verify_code')))),
            ] else ...[
              ListenableBuilder(listenable: simpleUIController, builder: (_, __) => TextFormField(
                controller: newPwdCtrl, style: AppTypography.bodyLarge(),
                obscureText: simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(simpleUIController.isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => simpleUIController.isObscureActive(),
                  ),
                  hintText: Strings.of('new_password'),
                ),
              )),
              const SizedBox(height: 14),
              FlutterPwValidator(key: validatorKey, controller: newPwdCtrl,
                  minLength: 8, uppercaseCharCount: 1, numericCharCount: 3, specialCharCount: 1,
                  width: 400, height: 150, onSuccess: () {}, onFail: () {}),
              const SizedBox(height: 14),
              ListenableBuilder(listenable: simpleUIController, builder: (_, __) => TextFormField(
                controller: confirmCtrl, style: AppTypography.bodyLarge(),
                obscureText: simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(simpleUIController.isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => simpleUIController.isObscureActive(),
                  ),
                  hintText: Strings.of('confirm_password'),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return Strings.of('confirm_password_required');
                  if (v != newPwdCtrl.text) return Strings.of('passwords_do_not_match');
                  return null;
                },
              )),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : resetPassword,
                  child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(Strings.of('reset_password')),
                )),
            ],
          ]),
        ),
      ),
    );
  }
}
