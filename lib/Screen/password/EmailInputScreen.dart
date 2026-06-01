import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../utils/strings.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of('no_account_for_email'))));
      return;
    }
    final code = await sendPasswordResetEmail(context, email);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of('reset_code_send_failed'))));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Strings.of('reset_code_sent'))));
    Navigator.push(context, MaterialPageRoute(builder: (_) => PasswordResetScreen(email: email, listusers: widget.listusers)));
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
            Text(Strings.of('forgotten_password_title'),
                style: AppTypography.headlineLarge()),
            const SizedBox(height: 8),
            Text(Strings.of('forgotten_password_subtitle'),
                style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
            const SizedBox(height: 32),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyLarge(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: Strings.of('email'),
              ),
              validator: (v) => EmailValidator.validate(v?.trim() ?? '') ? null : Strings.of('enter_valid_email'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : checkEmail,
                child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(Strings.of('verify_email')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
