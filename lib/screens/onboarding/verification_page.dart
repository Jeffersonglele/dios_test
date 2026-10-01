import 'dart:async';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constant.dart';
import '../../core/app_role.dart';
import '../../mails/mails.dart';
import '../../models/users.dart';
import '../../services/session_service.dart';
import '../../widgets/showConfetti.dart';
import '../../utils/toast.dart';
import '../splash/animated_splash_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swirling_loader.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final int roleID;
  final String telephone;
  final int userID;
  final String? password;
  final String? firstname;
  final String? lastname;
  final String? username;
  final String? password_crypte;
  final String? indicatif;
  final String country;

  VerificationPage({
    required this.email,
    required this.userID,
    required this.roleID,
    required this.country,
    this.telephone = '',
    this.password,
    this.firstname,
    this.lastname,
    this.username,
    this.password_crypte,
    this.indicatif,
  });

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSendingCodes = true;
  bool _isVerifying = false;
  String? _sendErrorMessage;
  String? _emailError;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _initializeVerification();
  }

  Future<void> _initializeVerification() async {
    if (_emailController.text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSendingCodes = false;
        _sendErrorMessage =
            AppLocalizations.of(context)!.verification_email_missing;
      });
      return;
    }
    final emailSent = await _sendEmailCode();

    if (!mounted) return;

    setState(() {
      _isSendingCodes = false;
      _sendErrorMessage = emailSent ? null : _buildSendErrorMessage();
    });

    if (emailSent) {
      _startResendCooldown();
      Toast(
          context, AppLocalizations.of(context)!.verification_code_sent, true);
    } else {
      Toast(context, _sendErrorMessage!, false);
    }
  }

  Future<bool> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    try {
      return await sendVerificationEmail(context, email);
    } catch (e) {
      return false;
    }
  }

  String _buildSendErrorMessage() {
    return AppLocalizations.of(context)!.verification_code_send_error;
  }

  String _countryOrDefault(String country) {
    final cleanCountry = country.trim();
    return cleanCountry.isEmpty ? "RDC" : cleanCountry;
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _cooldownTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Soumission code ────────────────────────────────────────
  Future<void> _onVerify(AppLocalizations l10n) async {
    if (_isVerifying) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      Toast(context, l10n.verification_enter_code, false);
      return;
    }
    if (!mounted) return;
    setState(() => _isVerifying = true);
    try {
      final valid = await verifyEmailCode(email: widget.email, code: code);
      if (!mounted) return;
      if (valid) {
        try {
          await Users.updateStatus(widget.userID, "Verified");
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('userVerified', true);
          final country = _countryOrDefault(widget.country);

          await SessionService.saveUserSession(
            userId: widget.userID,
            role: AppRole.fromId(widget.roleID),
            country: country,
            email: widget.email,
          );

          if (!mounted) return;
          Toast(context, l10n.verification_success, true);

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WelcomeScreen()),
          );
        } catch (e) {
          if (!mounted) return;
          Toast(context, l10n.verification_account_error, false);
        }
      } else {
        Toast(context, l10n.verification_code_invalid, false);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _onResend(AppLocalizations l10n) async {
    setState(() {
      _isSendingCodes = true;
      _sendErrorMessage = null;
    });
    final sent = await _sendEmailCode();
    if (!mounted) return;
    setState(() {
      _isSendingCodes = false;
      _sendErrorMessage = sent ? null : _buildSendErrorMessage();
    });
    if (sent) _startResendCooldown();
    Toast(
      context,
      sent ? l10n.verification_new_code_sent : l10n.verification_new_code_error,
      sent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgSurface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final barrier = AppColors.resolve(
      AppColors.ink.withValues(alpha: 0.45),
      AppDarkColors.ink.withValues(alpha: 0.60),
    );

    return Scaffold(
      backgroundColor: bgSurface,
      body: Stack(
        children: [
          SafeArea(
            child: IgnorePointer(
              ignoring: _isVerifying,
              child: Opacity(
                opacity: _isVerifying ? 0.55 : 1.0,
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Barre du haut : déconnexion ─────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await SessionService.clearAll();
                                    if (!mounted) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const AnimatedSplashScreen()),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                      foregroundColor: error),
                                  child: Text(
                                    l10n.logout,
                                    style: AppTypography.bodyMedium(
                                            color: error)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(
                              l10n.verificationCode,
                              textAlign: TextAlign.center,
                              style:
                                  AppTypography.displayMedium(color: inkColor)
                                      .copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.08),
                            ),
                            const SizedBox(height: 28),

                            // ── Contenu (chargement / erreur / formulaire) ──
                            if (_isSendingCodes) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(color: brand),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.verification_sending,
                                      style: AppTypography.bodyMedium(
                                          color: inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_sendErrorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: error.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                      color: error.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _sendErrorMessage!,
                                  style: AppTypography.bodyMedium(color: error)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: AppTypography.bodyLarge(color: inkColor),
                                decoration: InputDecoration(
                                  hintText: l10n.email,
                                  hintStyle:
                                      AppTypography.bodyLarge(color: inkMuted),
                                  prefixIcon: Icon(Icons.email_outlined,
                                      size: 20, color: inkMuted),
                                  filled: true,
                                  fillColor: card,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  errorText: _emailError,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide:
                                        BorderSide(color: border, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide:
                                        BorderSide(color: brand, width: 1.6),
                                  ),
                                ),
                                onChanged: (_) =>
                                    setState(() => _emailError = null),
                              ),
                              const SizedBox(height: 20),
                              _PrimaryButton(
                                label: _emailController.text.trim().isEmpty
                                    ? l10n.verification_reconnect
                                    : l10n.verification_resend,
                                onPressed: _emailController.text.trim().isEmpty
                                    ? () async {
                                        await SessionService.clearAll();
                                        if (!mounted) return;
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const AnimatedSplashScreen()),
                                        );
                                      }
                                    : () async {
                                        final users =
                                            await Users.fetchUsersFromDB();
                                        final exists = users.any((u) =>
                                            u.email.toLowerCase() ==
                                                _emailController.text
                                                    .trim()
                                                    .toLowerCase() &&
                                            u.userID != widget.userID);
                                        if (exists) {
                                          setState(() => _emailError =
                                              l10n.verification_email_exists);
                                          return;
                                        }
                                        setState(() {
                                          _isSendingCodes = true;
                                          _sendErrorMessage = null;
                                          _emailError = null;
                                        });
                                        _initializeVerification();
                                      },
                              ),
                            ] else ...[
                              Center(
                                child: Text(
                                  l10n.verification_code_hint(widget.email),
                                  textAlign: TextAlign.center,
                                  style:
                                      AppTypography.bodyLarge(color: inkColor),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  l10n.verification_spam_hint,
                                  textAlign: TextAlign.center,
                                  style:
                                      AppTypography.bodySmall(color: inkMuted),
                                ),
                              ),
                              const SizedBox(height: 28),
                              PinCodeTextField(
                                appContext: context,
                                length: 6,
                                autoDisposeControllers: false,
                                obscureText: false,
                                animationType: AnimationType.fade,
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  fieldHeight: 52,
                                  fieldWidth: 44,
                                  activeColor: brand,
                                  selectedColor: brand,
                                  inactiveColor: border,
                                  activeFillColor: card,
                                  inactiveFillColor: card,
                                  selectedFillColor: card,
                                ),
                                animationDuration:
                                    const Duration(milliseconds: 300),
                                backgroundColor: Colors.transparent,
                                enableActiveFill: true,
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                textStyle:
                                    AppTypography.labelLarge(color: inkColor)
                                        .copyWith(fontWeight: FontWeight.w700),
                                onCompleted: (v) {},
                                onChanged: (value) {},
                              ),
                              const SizedBox(height: 24),
                              _PrimaryButton(
                                label: l10n.verification_verify,
                                onPressed: () => _onVerify(l10n),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: _resendCooldown > 0
                                      ? null
                                      : () => _onResend(l10n),
                                  child: Text(
                                    _resendCooldown > 0
                                        ? l10n.verification_resend_cooldown(
                                            _resendCooldown)
                                        : l10n.verification_resend,
                                    style: AppTypography.bodyMedium(
                                      color: _resendCooldown > 0
                                          ? inkMuted
                                          : brand,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isVerifying)
            _VerificationOverlay(brand: brand, inkColor: inkColor),
        ],
      ),
    );
  }
}

class _VerificationOverlay extends StatelessWidget {
  const _VerificationOverlay({required this.brand, required this.inkColor});

  final Color brand;
  final Color inkColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: AppColors.resolve(
            AppColors.ink.withValues(alpha: 0.45),
            AppDarkColors.ink.withValues(alpha: 0.60),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 36),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Swirling(
                    size: 56,
                    color: brand,
                    semanticLabel: l10n.verification_verifying,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.verification_verifying,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge(color: inkColor).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.verification_patience,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(color: muted),
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
// _PrimaryButton — Même langage visuel que le CTA de SignUpView
// (pilule, couleur brand, ombre portée)
// ═══════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.30),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
