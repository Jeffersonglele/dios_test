import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import '../../Constant/Constant.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../utils/strings.dart';
import 'PasswordResetScreen.dart';

class EmailInputScreen extends StatefulWidget {
  final List<Users> listusers;

  const EmailInputScreen({super.key, required this.listusers});

  @override
  _EmailInputScreenState createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> checkEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    bool emailExists = await Users.checkEmailExists(widget.listusers, email);

    if (!emailExists) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Strings.of('no_account_for_email')),
      ));
      return;
    }

    final generationTime = DateTime.now();
    final resetCode = await sendPasswordResetEmail(context, email);

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });

    if (resetCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Strings.of('reset_code_send_failed')),
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Strings.of('reset_code_sent')),
    ));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasswordResetScreen(
          email: email,
          listusers: widget.listusers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: size.width > 600
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.1),
              size.width > 600
                  ? Container()
                  : const Center(child: BrandAvatarLogo()),
              SizedBox(height: size.height * 0.03),
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Text(
                  Strings.of('forgotten_password_title'),
                  style: kLoginTitleStyle(size),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.of('forgotten_password_subtitle'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      style: kTextFormFieldStyle(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_rounded),
                        hintText: Strings.of('email'),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                        ),
                      ),
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (!EmailValidator.validate(value?.trim() ?? '')) {
                          return Strings.of('enter_valid_email');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: checkEmail,
                              child: Text(Strings.of('verify_email')),
                            ),
                          )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
