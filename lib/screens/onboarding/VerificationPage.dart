import 'dart:async';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/Constant.dart';
import '../../core/app_role.dart';
import '../../mails/mails.dart';
import '../../models/users.dart';
import '../../services/session_service.dart';
import '../../widgets/showConfetti.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../AnimatedSplashScreen.dart';
import '../../theme/app_theme.dart';

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

  bool _isSendingCodes = true;
  String? _sendErrorMessage;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _initializeVerification();
  }

  Future<void> _initializeVerification() async {
    if (widget.email.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSendingCodes = false;
        _sendErrorMessage = AppLocalizations.of(context)!.verification_email_missing;
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
      Toast(context, AppLocalizations.of(context)!.verification_code_sent, true);
    } else {
      Toast(context, _sendErrorMessage!, false);
    }
  }

  Future<bool> _sendEmailCode() async {
    if (widget.email.trim().isEmpty) return false;
    try {
      return await sendVerificationEmail(context, widget.email);
    } catch (e) {
      return false;
    }
  }

  String _buildSendErrorMessage() {
    return AppLocalizations.of(context)!.verification_code_send_error;
  }

  String _countryOrDefault(String country) {
    final cleanCountry = country.trim();
    return cleanCountry.isEmpty ? "Bénin" : cleanCountry;
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
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: size.width > 600
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  label: Text(l10n.cancel),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await SessionService.clearAll();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()),
                    );
                  },
                  child: Text(l10n.logout,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(height: 5),
          size.width > 600
              ? Container() // N'affiche pas l'avatar sur les grands écrans
              : const Center(child: BrandAvatarLogo()),
          SizedBox(height: size.height * 0.03),
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Text(
              l10n.verificationCode,
              style: kLoginTitleStyle(
                  size), // Assurez-vous que cette fonction est bien appelée ici
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSendingCodes) ...[
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(l10n.verification_sending),
                      ],
                    ),
                  ),
                ] else if (_sendErrorMessage != null) ...[
                  Text(
                    _sendErrorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.email.trim().isEmpty
                          ? () async {
                              await SessionService.clearAll();
                              if (!mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()),
                              );
                            }
                          : () {
                              setState(() {
                                _isSendingCodes = true;
                                _sendErrorMessage = null;
                              });
                              _initializeVerification();
                            },
                      child: Text(widget.email.trim().isEmpty
                          ? l10n.verification_reconnect
                          : l10n.verification_resend),
                    ),
                  ),
                ] else ...[
                  Text(
                    l10n.verification_code_hint(widget.email),
                  ),
                  SizedBox(height: 6),
                  Text(
                    l10n.verification_spam_hint,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  PinCodeTextField(
                    appContext: context,
                    length: 6,
                    autoDisposeControllers: false,
                    // Le code a 6 chiffres
                    obscureText: false,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(5),
                      fieldHeight: 50,
                      fieldWidth: 40,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.grey[200],
                      selectedFillColor: Colors.white,
                    ),
                    animationDuration: Duration(milliseconds: 300),
                    backgroundColor: Colors.transparent,
                    enableActiveFill: true,
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onCompleted: (v) {},
                    onChanged: (value) {},
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        final code = _codeController.text.trim();
                        if (code.isEmpty) {
                          Toast(context, l10n.verification_enter_code, false);
                          return;
                        }
                        final valid = await verifyEmailCode(email: widget.email, code: code);
                        if (valid) {
                          try {
                            await Users.updateStatus(widget.userID, "Verified");
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setBool('userVerified', true);
                            final country = _countryOrDefault(widget.country);

                            await SessionService.saveUserSession(
                              userId: widget.userID,
                              role: AppRole.fromId(widget.roleID),
                              country: country,
                            );

                            if (!mounted) return;

                            Toast(context, l10n.verification_success, true);

                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WelcomeScreen(),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;

                            Toast(context, l10n.verification_account_error, false);
                          }
                        } else {
                          Toast(context, l10n.verification_code_invalid, false);
                        }
                      },
                      child: Text(l10n.verification_verify),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _resendCooldown > 0
                          ? null
                          : () async {
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
                            },
                      child: Text(
                        _resendCooldown > 0
                            ? l10n.verification_resend_cooldown(_resendCooldown)
                            : l10n.verification_resend,
                        style: TextStyle(
                          color: _resendCooldown > 0 ? Colors.grey : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                ],
              ],
            ),
          ),
        ],
      )),
    );
  }
}
