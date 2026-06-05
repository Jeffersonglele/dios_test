import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/auth_shell.dart';
import 'PasswordResetScreen.dart';

class EmailInputScreen extends StatefulWidget {
  final List<Users> listusers;
  const EmailInputScreen({super.key, required this.listusers});
  @override
  _EmailInputScreenState createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() { emailCtrl.dispose(); super.dispose(); }

  Future<void> checkEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final email = emailCtrl.text.trim();
    final exists = await Users.checkEmailExists(widget.listusers, email);
    if (!exists) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.no_account_for_email)));
      return;
    }
    final code = generateCode();
    final sent = await sendPasswordResetEmail(context, email, code);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.reset_code_send_failed)));
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PasswordResetScreen(
        email: email,
        listusers: widget.listusers,
        expectedCode: code,
        generatedAt: DateTime.now(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AuthShell(
          title: AppLocalizations.of(context)!.forgotten_password_title,
          subtitle: AppLocalizations.of(context)!.forgotten_password_subtitle,
          form: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: AppLocalizations.of(context)!.email,
              ),
              validator: (v) => EmailValidator.validate(v?.trim() ?? '') ? null : AppLocalizations.of(context)!.enter_valid_email,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                onPressed: isLoading ? null : checkEmail,
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(AppLocalizations.of(context)!.verify_email, style: AppTypography.labelMedium(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.inkMuted,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}
