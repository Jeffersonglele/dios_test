import 'package:flutter/material.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../services/password_reset_validation.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../utils/strings.dart';
import 'PasswordChangeSuccessScreen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;

  const PasswordResetScreen({
    super.key,
    required this.email,
    required this.listusers,
  });

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController newpasswordConfirmController =
      TextEditingController();
  final SimpleUIController simpleUIController = SimpleUIController();
  final GlobalKey<FlutterPwValidatorState> validatorKey =
      GlobalKey<FlutterPwValidatorState>();
  final _formKey = GlobalKey<FormState>(); // Clé pour le formulaire

  bool isLoading = false;
  bool isCodeVerified = false;

  @override
  void dispose() {
    codeController.dispose();
    newPasswordController.dispose();
    newpasswordConfirmController.dispose();
    super.dispose();
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();
    final valid = await verifyEmailCode(email: widget.email, code: code);
    if (!valid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Strings.of('invalid_or_expired_code')),
        ));
      }
      return;
    }

    setState(() {
      isCodeVerified = true;
    });
  }

  Future<void> resetPassword() async {
    if (!isCodeVerified) {
      verifyCode();
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Valide le formulaire avant d'exécuter l'action
      setState(() {
        isLoading = true;
      });

      // Récupérer les informations de l'utilisateur via l'email
      Users? user = await Users.getUsersByEmail(widget.listusers, widget.email);

      if (user != null) {
        final validation = await PasswordResetValidation.validate(
          newPassword: newPasswordController.text,
          confirmPassword: newpasswordConfirmController.text,
          currentPasswordHash: user.password,
        );

        if (validation == PasswordResetValidationResult.sameAsCurrentPassword) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Strings.of('same_password_error')),
          ));
        } else if (validation != PasswordResetValidationResult.valid) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Strings.of('form_invalid')),
          ));
        } else {
          String encryptedPassword =
              await Users.encryptPassword(newPasswordController.text);
          String updateResult =
              await Users.updatePassword(user.userID, encryptedPassword);

          updateResult == "success"
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => PasswordChangeSuccessScreen()),
                )
              : Toast(context, "Erreur : $updateResult", false);
          ;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Strings.of('user_not_found')),
        ));
      }

      setState(() {
        isLoading = false;
      });
    } else {
      // Affiche un message si la validation échoue
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Strings.of('form_invalid')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Ajout de la clé du formulaire ici
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: size.width > 600
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.1),
              const Center(child: BrandAvatarLogo()),
              SizedBox(height: size.height * 0.03),
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Text(
                  Strings.of('reset_password_title'),
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
                      Strings.of('reset_password_subtitle'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: size.height * 0.02),
                    if (!isCodeVerified) ...[
                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.verified_user),
                          labelText: Strings.of('verification_code'),
                          hintText: Strings.of('verification_code_hint'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),
                      Center(
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
                          onPressed: verifyCode,
                          child: Text(Strings.of('verify_code')),
                        ),
                      ),
                    ] else ...[
                      ListenableBuilder(listenable: simpleUIController, builder: (_, __) => _buildPasswordField(
                            controller: newPasswordController,
                            hintText: Strings.of('new_password'),
                            simpleUIController: simpleUIController,
                          )),
                      SizedBox(height: size.height * 0.02),
                      FlutterPwValidator(
                        key: validatorKey,
                        controller: newPasswordController,
                        minLength: 8,
                        uppercaseCharCount: 1,
                        numericCharCount: 3,
                        specialCharCount: 1,
                        width: 400,
                        height: 150,
                        onSuccess: () {},
                        onFail: () {},
                      ),
                      SizedBox(height: size.height * 0.03),
                      ListenableBuilder(listenable: simpleUIController, builder: (_, __) => _buildPasswordField(
                            controller: newpasswordConfirmController,
                            hintText: Strings.of('confirm_password'),
                            simpleUIController: simpleUIController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return Strings.of('confirm_password_required');
                              }
                              if (value != newPasswordController.text) {
                                return Strings.of('passwords_do_not_match');
                              }
                              return null;
                            },
                          )),
                    ],
                    SizedBox(height: 20),
                    if (isCodeVerified)
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
                                onPressed: resetPassword,
                                child: Text(Strings.of('reset_password')),
                              ),
                            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fonction pour construire le champ de mot de passe avec gestion de la visibilité
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required SimpleUIController simpleUIController,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: simpleUIController.isObscure,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.lock_open),
        suffixIcon: IconButton(
          icon: Icon(simpleUIController.isObscure
              ? Icons.visibility
              : Icons.visibility_off),
          onPressed: () => simpleUIController.isObscureActive(),
        ),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: validator,
    );
  }
}
