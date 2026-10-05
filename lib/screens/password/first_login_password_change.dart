import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../controllers/ui_controller.dart';
import '../../models/users.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/swirling_loader.dart';
import 'password_change_success_screen.dart';

class FirstLoginPasswordChange extends StatefulWidget {
  final Users user;
  const FirstLoginPasswordChange({super.key, required this.user});
  @override
  State<FirstLoginPasswordChange> createState() =>
      _FirstLoginPasswordChangeState();
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

  // ── Logique d'origine (inchangée) ─────────────────────────
  bool _isPasswordValid(String pwd) {
    if (pwd.length < 8) return false;
    final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    final hasDigit = pwd.contains(RegExp(r'[0-9]'));
    final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUpper && hasDigit && hasSpecial;
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

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => isLoading = true);
    final closeLoader = _showLoader();
    String result;
    try {
      final encrypted = await Users.encryptPassword(newPwdCtrl.text);
      result = await Users.updatePassword(
        widget.user.userID,
        encrypted,
        mustChangePassword: false,
        plainPassword: newPwdCtrl.text,
      );
    } catch (e) {
      result = e.toString();
    }
    closeLoader();
    if (!mounted) return;
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

  Widget _heroIcon() {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brand.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 72,
            height: 72,
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
            child:
                Icon(Icons.verified_user_outlined, color: brand, size: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fieldStyle = AppTypography.bodyLarge(
      color: Theme.of(context).colorScheme.onSurface,
    );

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: loc.first_login_title,
        subtitle: loc.first_login_subtitle,
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroIcon(),
              const SizedBox(height: 24),
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
                    if (!_isPasswordValid(v)) {
                      return loc.password_requirement_hint;
                    }
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
                        child: _PasswordStrengthIndicator(
                            controller: newPwdCtrl),
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
                    if (!isLoading) _changePassword();
                  },
                  decoration: _decoration(
                    context,
                    hint: loc.confirm_password,
                    suffixIcon: _eye(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return loc.confirm_password_required;
                    }
                    if (v != newPwdCtrl.text) return loc.passwords_do_not_match;
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 28),
              _PrimaryButton(
                label: loc.change_password_button,
                isLoading: isLoading,
                onPressed: _changePassword,
              ),
            ],
          ),
        ),
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
    this.isLoading = false,
  });

  final String label;
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
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20),
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