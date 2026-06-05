import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../l10n/app_localizations.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.no_account_for_email)));
      return;
    }
    final code = await sendPasswordResetEmail(context, email);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.reset_code_send_failed)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.reset_code_sent)));
    Navigator.push(context, MaterialPageRoute(builder: (_) => PasswordResetScreen(email: email, listusers: widget.listusers)));
  }

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppDarkColors.surface : AppColors.surface;
    final cardColor = isDark ? AppDarkColors.card : AppColors.card;
    final inkColor = isDark ? AppDarkColors.ink : AppColors.ink;
    final inkMuted = isDark ? AppDarkColors.inkMuted : AppColors.inkMuted;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(backgroundColor: surface),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 40),
            Text(AppLocalizations.of(context)!.forgotten_password_title, style: AppTypography.headlineLarge(color: inkColor)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.forgotten_password_subtitle, style: AppTypography.bodyLarge(color: inkMuted)),
            const SizedBox(height: 32),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyLarge(color: inkColor),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: AppLocalizations.of(context)!.email,
                filled: true, fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.brand, width: 1.5)),
              ),
              validator: (v) => EmailValidator.validate(v?.trim() ?? '') ? null : AppLocalizations.of(context)!.enter_valid_email,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                onPressed: isLoading ? null : checkEmail,
                child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppLocalizations.of(context)!.verify_email, style: AppTypography.labelMedium(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
