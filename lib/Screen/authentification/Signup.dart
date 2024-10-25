import 'package:dios_delices/Screen/curved_navigation/CurvedNavigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import 'Login.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import 'package:avatar_glow/avatar_glow.dart';

import '../../mails/mails.dart';
import '../../modeles/users.dart';
import '../../utils/thousand_separator_input_formatter.dart';
import '../verif_confirm/VerificationPage.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({Key? key}) : super(key: key);

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  // Définition des contrôleurs de texte pour les champs du formulaire
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _telephone_Controller = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();

  final GlobalKey<FlutterPwValidatorState> validatorKey =
      GlobalKey<FlutterPwValidatorState>();

  var password = ""; // Variable pour stocker le mot de passe
  bool _isSelected = false; // Variable pour gérer le Checkbox
  final _formKey = GlobalKey<FormState>(); // Clé pour le formulaire

  final SimpleUIController simpleUIController = Get.put(SimpleUIController());

  bool hasSpecialCharacter(String value) {
    String specialCharacters =
        r'!@#$%^&*(),.?":{}|<>'; // Définissez vos caractères spéciaux ici
    for (int i = 0; i < value.length; i++) {
      if (specialCharacters.contains(value[i])) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    Get.put(SimpleUIController()); // Initialisation du contrôleur
  }


  @override
  void dispose() {
    // Nettoyage des contrôleurs lorsqu'ils ne sont plus utilisés
    firstnameController.dispose();
    lastnameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      // Fermer le clavier en cliquant en dehors
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return _buildLargeScreen(size, simpleUIController,
                    theme); // Affichage pour les grands écrans
              } else {
                return _buildSmallScreen(size, simpleUIController,
                    theme); // Affichage pour les petits écrans
              }
            },
          ),
        ),
      ),
    );
  }

  // Affichage pour grands écrans
  Widget _buildLargeScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(size, simpleUIController, theme),
        ),
      ],
    );
  }

  // Affichage pour petits écrans
  Widget _buildSmallScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, simpleUIController, theme),
    );
  }

  // Corps principal du formulaire
  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        SizedBox(height: size.height * 0.1),
        size.width > 600
            ? Container() // N'affiche pas l'avatar sur les grands écrans
            : Center(
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
            'Sign Up',
            style: kLoginTitleStyle(
                size), // Assurez-vous que cette fonction est bien appelée ici
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Champ pour le prénom
                _buildTextField(
                  controller: firstnameController,
                  hintText: 'First Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter first name';
                    } else if (value.length < 4) {
                      return 'At least enter 4 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: size.height * 0.02),
                // Champ pour le nom
                _buildTextField(
                  controller: lastnameController,
                  hintText: 'Last Name',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter last name';
                    } else if (value.length < 4) {
                      return 'At least enter 4 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: size.height * 0.02),
                // Champ pour le nom d'utilisateur
                _buildTextField(
                  controller: usernameController,
                  hintText: 'Username',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter username';
                    } else if (value.length < 4) {
                      return 'At least enter 4 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: size.height * 0.02),
                // Champ pour l'email
                _buildTextField(
                  controller: emailController,
                  hintText: 'Email address',
                  icon: Icons.email_rounded,
                  validator: (value) {
                    if (!EmailValidator.validate(value!)) {
                      return 'Please enter a valid email address';
                    }
                  },
                ),
                SizedBox(height: size.height * 0.02),
                _buildTextField(
                  controller: _telephone_Controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandSeparatorInputFormatter(),
                  ],
                  hintText: 'Telephone number',
                  icon: Icons.phone,
                  validator: (value) {
                    if (value != null &&
                        value != "" &&
                        value.length < 6) {
                      return "Veuillez entrer un numéro valide";
                    }
                    return null;
                  },
                ),
                SizedBox(height: size.height * 0.02),
                // Champ pour le mot de passe
                Obx(() => _buildPasswordField(
                      controller: passwordController,
                      hintText: 'Password',
                      simpleUIController: simpleUIController,
                    )),
                SizedBox(height: size.height * 0.02),
                // Validateur de mot de passe
                FlutterPwValidator(
                  key: validatorKey,
                  controller: passwordController,
                  minLength: 8,
                  uppercaseCharCount: 1,
                  numericCharCount: 3,
                  specialCharCount: 1,
                  width: 400,
                  height: 150,
                  onSuccess: () {
                    print("MATCHED");
                  },
                  onFail: () {
                    print("NOT MATCHED");
                  },
                ),
                SizedBox(height: size.height * 0.03),
                // Champ pour confirmer le mot de passe
                Obx(() => _buildPasswordField(
                      controller: passwordConfirmController,
                      hintText: 'Confirm password',
                      simpleUIController: simpleUIController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != passwordController.text) {
                          // Comparaison des deux champs
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    )),
                SizedBox(height: size.height * 0.01),
                CheckboxListTile(
                  title: Text(
                    "Creating an account means you're okay with our Terms of Services and our Privacy Policy",
                    style: TextStyle(
                      color: _isSelected
                          ? Colors.black
                          : Colors.red, // Rouge si non coché
                    ),
                  ),
                  value: _isSelected,
                  onChanged: (newValue) {
                    setState(() {
                      _isSelected = newValue!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity
                      .leading, // Place la checkbox à gauche
                ),
                SizedBox(height: size.height * 0.02),
                // Bouton de sign up
                signUpButton(theme),
                SizedBox(height: size.height * 0.03),
                // Lien pour aller à la page de connexion
                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        CupertinoPageRoute(builder: (ctx) => const Login()));
                    _formKey.currentState?.reset();
                    _clearTextFields();
                    simpleUIController.isObscure.value = true;
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account?',
                      style: kHaveAnAccountStyle(size),
                      children: [
                        TextSpan(
                            text: " Login",
                            style: kLoginOrSignUpTextStyle(size)),
                      ],
                    ),
                  ),
                ),
                invisibleButton(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Méthode pour créer un champ de texte réutilisable
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType, // Ajout du keyboardType optionnel
    List<TextInputFormatter>? inputFormatters, // Ajout des inputFormatters optionnels
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: validator,
      keyboardType: keyboardType, // Utilisation du keyboardType passé en paramètre
      inputFormatters: inputFormatters, // Utilisation des inputFormatters passés en paramètre
    );
  }

  // Méthode pour créer un champ de mot de passe réutilisable
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

  // Bouton d'inscription
  Widget signUpButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, // Couleur de fond du bouton
          foregroundColor: Colors.white, //Couleur du texte
          textStyle: TextStyle(
            fontSize: 18, // Taille du texte
            fontWeight: FontWeight.bold, // (Optionnel) Style de texte en gras
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Bordure du bouton
          ),
        ),
        onPressed: () async {
          if (_formKey.currentState!.validate()) {
            String? verificationCode;
            DateTime codeGenerationTime;

            verificationCode = await sendVerificationEmail(context, emailController.text);
            codeGenerationTime = DateTime.now();

            String encryptedPassword = await Users.encryptPassword(passwordController.text);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerificationPage(
                    verificationCode: verificationCode,
                    codeGenerationTime: codeGenerationTime,
                    email: emailController.text,
                    roleID: 2, //c'est la création de compte pour un utilisateur lambda
                    password: passwordController.text,
                    password_crypte: encryptedPassword,
                    firstname: firstnameController.text,
                    lastname: lastnameController.text,
                    username: usernameController.text,
                    telephone: int.tryParse(_telephone_Controller.text.replaceAll(' ', '')) ?? 0)
              ),
            );
          } else {
            print("Form contains errors");
          }
        },
        child: const Text('Sign up'),
      ),
    );
  }

  // Bouton invisible (navigation)
  Widget invisibleButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.white),
        ),
        onPressed: () {

        },
        child: const Text(''),
      ),
    );
  }

  // Méthode pour vider tous les champs
  void _clearTextFields() {
    firstnameController.clear();
    lastnameController.clear();
    usernameController.clear();
    emailController.clear();
    passwordController.clear();
    passwordConfirmController.clear();
  }
}
