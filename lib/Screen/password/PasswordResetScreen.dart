import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../modeles/users.dart';
import '../../utils/toast.dart';
import 'PasswordChangeSuccessScreen.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final List<Users> listusers;

  PasswordResetScreen({required this.email, required this.listusers});

  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController newpasswordConfirmController =
      TextEditingController();
  final SimpleUIController simpleUIController =
      Get.put(SimpleUIController()); // Initialisation du contrôleur
  final GlobalKey<FlutterPwValidatorState> validatorKey =
      GlobalKey<FlutterPwValidatorState>();
  final _formKey = GlobalKey<FormState>(); // Clé pour le formulaire

  bool isLoading = false;

  Future<void> resetPassword() async {
    if (_formKey.currentState!.validate()) {
      // Valide le formulaire avant d'exécuter l'action
      setState(() {
        isLoading = true;
      });

      // Récupérer les informations de l'utilisateur via l'email
      Users? user = await Users.getUsersByEmail(widget.listusers, widget.email);

      if (user != null) {
        String newencryptedPassword =
            await Users.encryptPassword(newPasswordController.text);

        if (newencryptedPassword == user.password) {
          // Le mot de passe est le même que l'ancien
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Le nouveau mot de passe doit être différent de l\'ancien'),
          ));
        } else {
          // Mettre à jour le mot de passe
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
          content: Text('Erreur : Utilisateur introuvable.'),
        ));
      }

      setState(() {
        isLoading = false;
      });
    } else {
      // Affiche un message si la validation échoue
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Veuillez remplir correctement les champs'),
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
              Center(
                child: AvatarGlow(
                  duration: Duration(seconds: 2),
                  glowColor: Colors.white24,
                  repeat: true,
                  startDelay: Duration(seconds: 1),
                  child: Material(
                    elevation: 8.0,
                    shape: CircleBorder(),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage:
                          AssetImage('assets/images/logo_sm01.jpg'),
                      radius: 50.0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.03),
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Text(
                  'Reset Password',
                  style: kLoginTitleStyle(size),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => _buildPasswordField(
                          controller: newPasswordController,
                          hintText: 'New Password',
                          simpleUIController: simpleUIController,
                        )),
                    SizedBox(height: size.height * 0.02),
                    // Validateur de mot de passe
                    FlutterPwValidator(
                      key: validatorKey,
                      controller: newPasswordController,
                      minLength: 8,
                      uppercaseCharCount: 1,
                      numericCharCount: 3,
                      specialCharCount: 1,
                      width: 400,
                      height: 150,
                      onSuccess: () {
                        print("Password valid");
                      },
                      onFail: () {
                        print("Password not valid");
                      },
                    ),
                    SizedBox(height: size.height * 0.03),
                    // Champ pour confirmer le mot de passe
                    Obx(() => _buildPasswordField(
                          controller: newpasswordConfirmController,
                          hintText: 'Confirm password',
                          simpleUIController: simpleUIController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        )),
                    SizedBox(height: 20),
                    isLoading
                        ? CircularProgressIndicator()
                        : Center(
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
                              onPressed: resetPassword,
                              child: Text("Reset the password"),
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
