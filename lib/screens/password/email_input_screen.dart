import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../mails/mails.dart';
import '../../models/users.dart';
import '../../services/node_auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/swirling_loader.dart';
import 'password_reset_screen.dart';

class EmailInputScreen extends StatefulWidget {
  final List<Users> listusers;
  const EmailInputScreen({super.key, required this.listusers});
  @override
  State<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
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

  // ── Logique d'origine (inchangée) ─────────────────────────
  Future<void> checkEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final closeLoader = _showLoader();
    final email = emailCtrl.text.trim();
    try {
      await NodeAuthService.requestPasswordReset(email);
    } on NodeAuthException catch (e) {
      closeLoader();
      if (mounted) setState(() => isLoading = false);
      _snack(e.message, success: false);
      return;
    } catch (e) {
      closeLoader();
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        _snack(AppLocalizations.of(context)!.reset_code_send_failed,
            success: false);
      }
      return;
    }
    closeLoader();
    if (!mounted) return;
    setState(() => isLoading = false);
    _snack(AppLocalizations.of(context)!.reset_code_sent, success: true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          email: email,
          listusers: widget.listusers,
        ),
      ),
    );
  }

  // ── Interface ─────────────────────────────────────────────
  InputDecoration _decoration(BuildContext context, {required String hint}) {
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
          Icon(Icons.mail_outline_rounded, size: 20, color: inkMuted),
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: outline(border, 1),
      enabledBorder: outline(border, 1),
      focusedBorder: outline(brand, 1.6),
      errorBorder: outline(error, 1.2),
      focusedErrorBorder: outline(error, 1.6),
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
              border: Border.all(color: brand.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Icon(Icons.lock_reset_rounded, color: brand, size: 34),
          ),
        ],
      ),
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
            title: loc.forgotten_password_title,
            subtitle: loc.forgotten_password_subtitle,
            form: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroIcon(),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    onFieldSubmitted: (_) {
                      if (!isLoading) checkEmail();
                    },
                    style: AppTypography.bodyLarge(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: _decoration(context, hint: loc.email),
                    validator: (v) => EmailValidator.validate(v?.trim() ?? '')
                        ? null
                        : loc.enter_valid_email,
                  ),
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: loc.verify_email,
                    isLoading: isLoading,
                    onPressed: checkEmail,
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
                          const Icon(Icons.arrow_forward_rounded,
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