import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../theme/app_theme.dart';
import '../../controllers/ui_controller.dart';
import '../../mails/mails.dart';
import '../../models/users.dart';
import '../../db/database_helper.dart';
import '../../services/node_auth_service.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/swirling_loader.dart';
import 'password_change_success_screen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;
  final String? expectedCode;
  final DateTime? generatedAt;

  const PasswordResetScreen({
    super.key,
    required this.email,
    required this.listusers,
    this.expectedCode,
    this.generatedAt,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final codeCtrl = TextEditingController();
  final newPwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final simpleUIController = SimpleUIController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isCodeVerified = false;
  bool _verifying = false; // évite le double envoi (saisie complète + bouton)
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
      try {
        codeCtrl.dispose();
      } catch (_) {}
      try {
        newPwdCtrl.dispose();
      } catch (_) {}
      try {
        confirmCtrl.dispose();
      } catch (_) {}
    });
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Voile bloquant Swirling (OverlayEntry : indépendant de la navigation) ──
  VoidCallback _showLoader() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    var removed = false;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Stack(
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.55),
            ),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(child: Swirling(size: 64, color: brand)),
              ),
            ),
          ],
        ),
      ),
    );
    overlay.insert(entry);
    return () {
      if (removed) return;
      removed = true;
      entry.remove();
    };
  }

  void _snack(String message, {required bool success}) {
    if (!mounted) return;
    final color = success
        ? AppColors.resolve(AppColors.success, AppDarkColors.success)
        : AppColors.resolve(AppColors.error, AppDarkColors.error);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  // ── Logique d'origine ─────────────────────────────────────
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
    final closeLoader = _showLoader();
    try {
      await NodeAuthService.requestPasswordReset(widget.email);
      closeLoader();
      if (!mounted) return;
      setState(() {
        isCodeVerified = false;
        isLoading = false;
        expectedCode = null;
        generatedAt = null;
        codeCtrl.clear();
      });
      _startResendCooldown();
      _snack(AppLocalizations.of(context)!.reset_code_sent, success: true);
    } on NodeAuthException catch (e) {
      closeLoader();
      if (mounted) setState(() => isLoading = false);
      _snack(e.message, success: false);
    } catch (e) {
      closeLoader();
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        _snack(AppLocalizations.of(context)!.reset_code_send_failed,
            success: false);
      }
    }
  }

  // store mutable refs so resend can update them
  late String? expectedCode = widget.expectedCode;
  late DateTime? generatedAt = widget.generatedAt;

  Future<void> verifyCode() async {
    if (_verifying) return;
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      _snack(AppLocalizations.of(context)!.password_reset_code_hint,
          success: false);
      return;
    }
    _verifying = true;
    final closeLoader = _showLoader();
    try {
      bool valid = false;
      if (expectedCode != null && generatedAt != null) {
        valid = isCodeValid(code, expectedCode!, generatedAt!);
      }
      if (!valid) {
        try {
          await NodeAuthService.verifyPasswordResetCode(
              email: widget.email, code: code);
          valid = true;
        } on NodeAuthException catch (e) {
          closeLoader();
          if (!mounted) return;
          _snack(e.message, success: false);
          return;
        } catch (e) {
          closeLoader();
          if (!mounted) return;
          final msg = e.toString().startsWith('Exception: ')
              ? e.toString().substring('Exception: '.length)
              : e.toString();
          _snack(
              msg.isEmpty
                  ? AppLocalizations.of(context)!.invalid_or_expired_code
                  : msg,
              success: false);
          return;
        }
      }
      closeLoader();
      if (!mounted) return;
      if (!valid) {
        _snack(AppLocalizations.of(context)!.invalid_or_expired_code,
            success: false);
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => isCodeVerified = true);
    } finally {
      closeLoader();
      _verifying = false;
    }
  }

  bool _isPasswordValid(String pwd) {
    if (pwd.length < 8) return false;
    final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    final hasDigit = pwd.contains(RegExp(r'[0-9]'));
    final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUpper && hasDigit && hasSpecial;
  }

  Future<void> resetPassword() async {
    if (!isCodeVerified) {
      verifyCode();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => isLoading = true);
    final closeLoader = _showLoader();
    try {
      await NodeAuthService.resetPassword(
        email: widget.email,
        code: codeCtrl.text.trim(),
        password: newPwdCtrl.text,
      );
      final user = Users.getUsersByEmail(widget.listusers, widget.email);
      if (user != null) {
        final encrypted = await Users.encryptPassword(newPwdCtrl.text);
        await DatabaseHelper.updateUserPassword(
          user.userID,
          encrypted,
          mustChangePassword: false,
        );
      }
      closeLoader();
      if (!mounted) return;
      setState(() => isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PasswordChangeSuccessScreen(),
        ),
      );
    } on NodeAuthException catch (e) {
      closeLoader();
      if (!mounted) return;
      setState(() => isLoading = false);
      Toast(context, e.message, false);
    } catch (e) {
      closeLoader();
      if (!mounted) return;
      setState(() => isLoading = false);
      Toast(context, "Erreur : $e", false);
    }
  }

  // ── Interface ─────────────────────────────────────────────
  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    required Widget suffixIcon,
  }) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);

    OutlineInputBorder outline(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLarge(color: inkMuted),
      prefixIcon:
          Icon(Icons.lock_outline_rounded, size: 20, color: inkMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: outline(border, 1),
      enabledBorder: outline(border, 1),
      focusedBorder: outline(brand, 1.6),
      errorBorder: outline(error, 1.2),
      focusedErrorBorder: outline(error, 1.6),
      errorMaxLines: 3,
    );
  }

  Widget _eye() {
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return IconButton(
      icon: Icon(
        simpleUIController.isObscure
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: inkMuted,
        size: 20,
      ),
      onPressed: () => simpleUIController.isObscureActive(),
    );
  }

  /// Icône d'en-tête qui change selon l'étape.
  Widget _heroIcon() {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brand.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  brand.withValues(alpha: 0.20),
                  brand.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: brand.withValues(alpha: 0.25), width: 1.5),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                isCodeVerified
                    ? Icons.lock_reset_rounded
                    : Icons.mark_email_read_outlined,
                key: ValueKey(isCodeVerified),
                color: brand,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Deux barres : étape 1 (code) → étape 2 (nouveau mot de passe).
  Widget _stepBars() {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    Widget bar(bool active) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 5,
            decoration: BoxDecoration(
              color: active ? brand : border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
    return Row(
      children: [
        bar(true),
        const SizedBox(width: 6),
        bar(isCodeVerified),
      ],
    );
  }

  Widget _codeStep(AppLocalizations loc) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final cooling = _resendCooldown > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modifier l'email
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.edit_outlined, size: 16, color: brand),
            label: Text(
              loc.email,
              style: AppTypography.labelMedium(color: brand),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Saisie du code : la largeur s'adapte aux petits écrans
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final w = ((c.maxWidth - gap * 5) / 6).clamp(34.0, 50.0);
            return PinCodeTextField(
              appContext: context,
              length: 6,
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              animationType: AnimationType.scale,
              animationDuration: const Duration(milliseconds: 180),
              enableActiveFill: true,
              cursorColor: brand,
              backgroundColor: Colors.transparent,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textStyle: AppTypography.titleLarge(color: ink)
                  .copyWith(fontWeight: FontWeight.w800),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(16),
                borderWidth: 1.2,
                activeBorderWidth: 1.8,
                selectedBorderWidth: 1.8,
                fieldHeight: 58,
                fieldWidth: w,
                activeFillColor: card,
                inactiveFillColor: card,
                selectedFillColor: brand.withValues(alpha: 0.06),
                activeColor: brand,
                inactiveColor: border,
                selectedColor: brand,
              ),
              onCompleted: (_) => verifyCode(),
              onChanged: (_) {},
            );
          },
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: loc.verify_code,
          icon: Icons.arrow_forward_rounded,
          isLoading: isLoading,
          onPressed: verifyCode,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: cooling || isLoading ? null : _resendCode,
            icon: Icon(
              cooling ? Icons.timer_outlined : Icons.refresh_rounded,
              size: 18,
              color: cooling ? inkMuted : brand,
            ),
            label: Text(
              cooling
                  ? '${loc.resendCode} ($_resendCooldown s)'
                  : loc.resendCode,
              style: TextStyle(
                color: cooling ? inkMuted : brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(AppLocalizations loc) {
    final fieldStyle = AppTypography.bodyLarge(
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: simpleUIController,
          builder: (_, __) => TextFormField(
            controller: newPwdCtrl,
            obscureText: simpleUIController.isObscure,
            style: fieldStyle,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              context,
              hint: loc.new_password,
              suffixIcon: _eye(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return loc.enter_password;
              if (!_isPasswordValid(v)) return loc.password_requirement_hint;
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: newPwdCtrl.text.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _PasswordStrengthIndicator(controller: newPwdCtrl),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: simpleUIController,
          builder: (_, __) => TextFormField(
            controller: confirmCtrl,
            obscureText: simpleUIController.isObscure,
            style: fieldStyle,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!isLoading) resetPassword();
            },
            decoration: _decoration(
              context,
              hint: loc.confirm_password,
              suffixIcon: _eye(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return loc.confirm_password_required;
              if (v != newPwdCtrl.text) return loc.passwords_do_not_match;
              return null;
            },
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: loc.reset_password,
          icon: Icons.check_rounded,
          isLoading: isLoading,
          onPressed: resetPassword,
        ),
      ],
    );
  }

  Widget _backButton(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: card,
          shape: CircleBorder(side: BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.arrow_back_rounded, color: ink, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Stack(
        children: [
          AuthShell(
            title: loc.verification_code_title,
            subtitle: isCodeVerified
                ? loc.verification_enter_new_password
                : loc.code_sent_to_email(widget.email),
            form: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepBars(),
                  const SizedBox(height: 22),
                  _heroIcon(),
                  const SizedBox(height: 22),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(isCodeVerified),
                        child: isCodeVerified
                            ? _passwordStep(loc)
                            : _codeStep(loc),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _backButton(context),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _PrimaryButton — pilule en dégradé (coins nets, appui visible)
// ═══════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final radius = BorderRadius.circular(999);

    return Opacity(
      opacity: isLoading ? 0.8 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [brand, brand.withValues(alpha: 0.85)],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: brand.withValues(alpha: isLoading ? 0.10 : 0.32),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? Swirling(
                        key: const ValueKey('loading'),
                        size: 34,
                        color: Colors.white,
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(icon, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _PasswordStrengthIndicator — jauge + critères
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
  bool _hasMin = false,
      _hasUpper = false,
      _hasNumber = false,
      _hasSpecial = false;

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
      _hasSpecial = t.contains(RegExp(r'[^a-zA-Z0-9\s]'));
    });
  }

  int get _score =>
      (_hasMin ? 1 : 0) +
      (_hasUpper ? 1 : 0) +
      (_hasNumber ? 1 : 0) +
      (_hasSpecial ? 1 : 0);

  Color get _c {
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
    final loc = AppLocalizations.of(context)!;
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 6,
                  margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: i < _score ? _c : border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _criterion(_hasMin, loc.min_8_chars),
              _criterion(_hasUpper, loc.require_uppercase),
              _criterion(_hasNumber, loc.require_3_digits),
              _criterion(_hasSpecial, loc.require_special),
            ],
          ),
        ],
      ),
    );
  }

  Widget _criterion(bool ok, String label) {
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final inkSubtle =
        AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            ok ? Icons.check_circle_rounded : Icons.circle_outlined,
            key: ValueKey(ok),
            size: 15,
            color: ok ? success : inkSubtle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
            color: ok ? success : inkMuted,
          ),
        ),
      ],
    );
  }
}