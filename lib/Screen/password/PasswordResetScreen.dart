import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../services/password_reset_validation.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import 'PasswordChangeSuccessScreen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;
  final String verificationCode;
  final DateTime codeGenerationTime;

  const PasswordResetScreen({
    super.key,
    required this.email,
    required this.listusers,
    required this.verificationCode,
    required this.codeGenerationTime,
  });

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController newpasswordConfirmController =
      TextEditingController();
  final SimpleUIController simpleUIController =
      Get.put(SimpleUIController()); // Initialisation du contrôleur
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

  void verifyCode() {
    final isValid = isCodeValid(
      widget.verificationCode,
      codeController.text.trim(),
      widget.codeGenerationTime,
    );

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('invalid_or_expired_code'.tr),
      ));
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
            content: Text('same_password_error'.tr),
          ));
        } else if (validation != PasswordResetValidationResult.valid) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('form_invalid'.tr),
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
          content: Text('user_not_found'.tr),
        ));
      }

      setState(() {
        isLoading = false;
      });
    } else {
      // Affiche un message si la validation échoue
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('form_invalid'.tr),
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
                  'reset_password_title'.tr,
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
                      'reset_password_subtitle'.tr,
                      style: const TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: size.height * 0.02),
                    if (!isCodeVerified) ...[
                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.verified_user),
                          labelText: 'verification_code'.tr,
                          hintText: 'verification_code_hint'.tr,
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
                          child: Text('verify_code'.tr),
                        ),
                      ),
                    ] else ...[
                      Obx(() => _buildPasswordField(
                            controller: newPasswordController,
                            hintText: 'new_password'.tr,
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
                      Obx(() => _buildPasswordField(
                            controller: newpasswordConfirmController,
                            hintText: 'confirm_password'.tr,
                            simpleUIController: simpleUIController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'confirm_password_required'.tr;
                              }
                              if (value != newPasswordController.text) {
                                return 'passwords_do_not_match'.tr;
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
                                child: Text('reset_password'.tr),
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
      obscureText: simpleUIController.isObscure.value,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.lock_open),
        suffixIcon: IconButton(
          icon: Icon(simpleUIController.isObscure.value
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
