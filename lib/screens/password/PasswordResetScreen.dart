import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../theme/app_theme.dart';
import '../../controllers/UiController.dart';
import '../../mails/mails.dart';
import '../../models/users.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import 'PasswordChangeSuccessScreen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;
  final String expectedCode;
  final DateTime generatedAt;

  const PasswordResetScreen({
    super.key,
    required this.email,
    required this.listusers,
    required this.expectedCode,
    required this.generatedAt,
  });

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final codeCtrl = TextEditingController();
  final newPwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final simpleUIController = SimpleUIController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isCodeVerified = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    Future.microtask(() {
      try { codeCtrl.dispose(); } catch (_) {}
      try { newPwdCtrl.dispose(); } catch (_) {}
      try { confirmCtrl.dispose(); } catch (_) {}
    });
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) _cooldownTimer?.cancel();
      });
    });
  }

  Future<void> _resendCode() async {
    setState(() => isLoading = true);
    final code = generateCode();
    final sent = await sendPasswordResetEmail(context, widget.email, code);
    if (!mounted) return;
    if (sent != null) {
      setState(() {
        isCodeVerified = false;
        isLoading = false;
        expectedCode = code;
        generatedAt = DateTime.now();
        codeCtrl.clear();
      });
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.reset_code_sent)));
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.reset_code_send_failed)));
    }
  }

  // store mutable refs so resend can update them
  late String expectedCode = widget.expectedCode;
  late DateTime generatedAt = widget.generatedAt;

  Future<void> verifyCode() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text('Veuillez entrer un code à 6 chiffres')));
      return;
    }
    // Primary: local verification
    bool valid = isCodeValid(code, expectedCode, generatedAt);
    // Fallback: cloud verification
    if (!valid) {
      valid = await verifyEmailCode(email: widget.email, code: code);
    }
    if (!valid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.invalid_or_expired_code)));
      return;
    }
    setState(() => isCodeVerified = true);
  }

  bool _isPasswordValid(String pwd) {
    if (pwd.length < 8) return false;
    final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    final hasDigit = pwd.contains(RegExp(r'[0-9]'));
    final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUpper && hasDigit && hasSpecial;
  }

  Future<void> resetPassword() async {
    if (!isCodeVerified) { verifyCode(); return; }
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final user = await Users.getUsersByEmail(widget.listusers, widget.email);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.user_not_found)));
      setState(() => isLoading = false); return;
    }
    final encrypted = await Users.encryptPassword(newPwdCtrl.text);
    final result = await Users.updatePassword(user.userID, encrypted);
    setState(() => isLoading = false);
    if (result == "success") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeSuccessScreen()));
    } else {
      Toast(context, "Erreur : $result", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Stack(
      children: [
        AuthShell(
          title: 'Code de vérification',
          subtitle: isCodeVerified
              ? 'Entrez votre nouveau mot de passe'
              : 'Un code a été envoyé à ${widget.email}',
          form: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (!isCodeVerified) ...[
              // Modify email link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(loc.email, style: AppTypography.bodySmall(color: AppColors.brand)),
                ),
              ),
              const SizedBox(height: 8),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  fieldHeight: 48, fieldWidth: 44,
                  activeFillColor: AppColors.card,
                  inactiveFillColor: AppColors.card,
                  selectedFillColor: AppColors.card,
                  activeColor: AppColors.brand,
                  inactiveColor: AppColors.border,
                  selectedColor: AppColors.brand,
                ),
                onCompleted: (_) => verifyCode(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  onPressed: isLoading ? null : verifyCode,
                  child: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(loc.verify_code, style: AppTypography.labelMedium(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _resendCooldown > 0 || isLoading ? null : _resendCode,
                  child: Text(
                    _resendCooldown > 0
                        ? '${loc.resendCode} ($_resendCooldown s)'
                        : loc.resendCode,
                    style: TextStyle(
                      color: _resendCooldown > 0 ? AppColors.inkMuted : AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              ListenableBuilder(
                listenable: simpleUIController,
                builder: (_, __) => TextFormField(
                  controller: newPwdCtrl,
                  obscureText: simpleUIController.isObscure,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(simpleUIController.isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => simpleUIController.isObscureActive(),
                    ),
                    hintText: loc.new_password,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc.enter_password;
                    if (!_isPasswordValid(v)) return 'Min 8 chars, 1 upper, 1 digit, 1 special';
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
                      icon: Icon(simpleUIController.isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  onPressed: isLoading ? null : resetPassword,
                  child: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(loc.reset_password, style: AppTypography.labelMedium(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        child: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          label: const Text('Retour'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
      ],
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
        Row(children: List.generate(4, (i) => Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 200), height: 4, margin: EdgeInsets.only(right: i < 3 ? 4 : 0), decoration: BoxDecoration(color: i < _score ? _c : AppColors.border, borderRadius: BorderRadius.circular(999)))))),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _Cr(ok: _hasMin, label: '8 chars min.'),
          _Cr(ok: _hasUpper, label: '1 uppercase'),
          _Cr(ok: _hasNumber, label: '3 digits'),
          _Cr(ok: _hasSpecial, label: '1 special char'),
        ]),
      ]),
    );
  }

  Widget _Cr({required bool ok, required String label}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.circle_outlined, size: 13, color: ok ? AppColors.success : AppColors.inkSubtle),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: ok ? AppColors.success : AppColors.inkMuted)),
    ]);
  }
}
