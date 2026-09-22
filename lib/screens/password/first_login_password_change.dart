import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../controllers/ui_controller.dart';
import '../../models/users.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import 'password_change_success_screen.dart';

class FirstLoginPasswordChange extends StatefulWidget {
  final Users user;
  const FirstLoginPasswordChange({super.key, required this.user});
  @override
  State<FirstLoginPasswordChange> createState() => _FirstLoginPasswordChangeState();
}

class _FirstLoginPasswordChangeState extends State<FirstLoginPasswordChange> {
  final newPwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final simpleUIController = SimpleUIController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    newPwdCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String pwd) {
    if (pwd.length < 8) return false;
    final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    final hasDigit = pwd.contains(RegExp(r'[0-9]'));
    final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUpper && hasDigit && hasSpecial;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final encrypted = await Users.encryptPassword(newPwdCtrl.text);
    final result = await Users.updatePassword(
      widget.user.userID,
      encrypted,
      mustChangePassword: false,
      plainPassword: newPwdCtrl.text,
    );
    setState(() => isLoading = false);
    if (result == "success") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PasswordChangeSuccessScreen()),
      );
    } else {
      Toast(context, "Erreur : $result", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AuthShell(
      title: loc.first_login_title,
      subtitle: loc.first_login_subtitle,
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: simpleUIController,
              builder: (_, __) => TextFormField(
                controller: newPwdCtrl,
                obscureText: simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => simpleUIController.isObscureActive(),
                  ),
                  hintText: loc.new_password,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return loc.enter_password;
                  if (!_isPasswordValid(v)) return loc.password_requirement_hint;
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (newPwdCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              _PasswordStrengthIndicator(controller: newPwdCtrl),
            ],
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: simpleUIController,
              builder: (_, __) => TextFormField(
                controller: confirmCtrl,
                obscureText: simpleUIController.isObscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(simpleUIController.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => simpleUIController.isObscureActive(),
                  ),
                  hintText: loc.confirm_password,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return loc.confirm_password_required;
                  if (v != newPwdCtrl.text) return loc.passwords_do_not_match;
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                onPressed: isLoading ? null : _changePassword,
                child: isLoading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(loc.change_password_button,
                        style: AppTypography.labelMedium(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatefulWidget {
  const _PasswordStrengthIndicator({required this.controller});
  final TextEditingController controller;
  @override
  State<_PasswordStrengthIndicator> createState() => _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState extends State<_PasswordStrengthIndicator> {
  bool _hasMin = false, _hasUpper = false, _hasNumber = false, _hasSpecial = false;

  @override
  void initState() { super.initState(); widget.controller.addListener(_check); _check(); }
  @override
  void dispose() { widget.controller.removeListener(_check); super.dispose(); }

  void _check() {
    final t = widget.controller.text;
    setState(() {
      _hasMin = t.length >= 8;
      _hasUpper = t.contains(RegExp(r'[A-Z]'));
      _hasNumber = RegExp(r'\d').allMatches(t).length >= 3;
      _hasSpecial = t.contains(RegExp(r'[^a-zA-Z0-9\s]'));
    });
  }

  int get _score => (_hasMin ? 1 : 0) + (_hasUpper ? 1 : 0) + (_hasNumber ? 1 : 0) + (_hasSpecial ? 1 : 0);

  Color get _c {
    switch (_score) { case 4: return AppColors.success; case 3: return AppColors.accent; case 2: return const Color(0xFFF59E0B); default: return AppColors.error; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: List.generate(4, (i) => Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), height: 4,
          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
          decoration: BoxDecoration(
            color: i < _score ? _c : AppColors.border,
            borderRadius: BorderRadius.circular(999),
          ),
        )))),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _Cr(ok: _hasMin, label: AppLocalizations.of(context)!.min_8_chars),
          _Cr(ok: _hasUpper, label: AppLocalizations.of(context)!.require_uppercase),
          _Cr(ok: _hasNumber, label: AppLocalizations.of(context)!.require_3_digits),
          _Cr(ok: _hasSpecial, label: AppLocalizations.of(context)!.require_special),
        ]),
      ]),
    );
  }

  Widget _Cr({required bool ok, required String label}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 13,
          color: ok ? AppColors.success : AppColors.inkSubtle),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11,
          color: ok ? AppColors.success : AppColors.inkMuted)),
    ]);
  }
}
