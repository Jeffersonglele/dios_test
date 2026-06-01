import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_pw_validator/flutter_pw_validator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/phone_number.dart';
import '../../utils/toast.dart';
import 'Login.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../modeles/users.dart';
import '../verif_confirm/VerificationPage.dart';
import '../../widgets/auth_shell.dart';

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

  TextEditingController locationController = TextEditingController();

  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();
  Position? position;
  String completeAddress = "";

  String _selectedCountry = "Bénin";
  final Map<String, String> _countryCodes = {
    "France": "+33",
    "Bénin": "+229",
    "Côte d'Ivoire": "+225"
  };

  final Map<String, String> _countryFlags = {
    "France": "🇫🇷",
    "Bénin": "🇧🇯",
    "Côte d'Ivoire": "🇨🇮"
  };

  final Map<String, int> _phoneNumberLengths = {
    "France": 10,
    "Bénin": 10,
    "Côte d'Ivoire": 8
  };

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
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: 'signup_title'.tr,
        subtitle: 'signup_subtitle'.tr,
        form: _buildMainBody(size, simpleUIController, theme),
        footer: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (ctx) => const Login()),
            );
            _formKey.currentState?.reset();
            _clearTextFields();
            simpleUIController.isObscure.value = true;
          },
          child: RichText(
            text: TextSpan(
              text: 'already_have_account'.tr,
              style: kHaveAnAccountStyle(size),
              children: [
                TextSpan(
                  text: " ${'login'.tr}",
                  style: kLoginOrSignUpTextStyle(size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Corps principal du formulaire
  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Champ pour le prénom
          _buildTextField(
            controller: firstnameController,
            hintText: 'firstname'.tr,
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'enter_firstname'.tr;
              } else if (value.length < 4) {
                return 'min_4_chars'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
          // Champ pour le nom
          _buildTextField(
            controller: lastnameController,
            hintText: 'lastname'.tr,
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'enter_lastname'.tr;
              } else if (value.length < 4) {
                return 'min_4_chars'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
          // Champ pour le nom d'utilisateur
          _buildTextField(
            controller: usernameController,
            hintText: 'username'.tr,
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'enter_username'.tr;
              } else if (value.length < 4) {
                return 'min_4_chars'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
          // Champ pour l'email
          _buildTextField(
            controller: emailController,
            hintText: 'email'.tr,
            icon: Icons.email_rounded,
            validator: (value) {
              if (!EmailValidator.validate(value!)) {
                return 'enter_valid_email'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
          DropdownButtonFormField<String>(
            value: _selectedCountry,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.flag_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            selectedItemBuilder: (context) {
              return _countryCodes.keys.map((country) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_phoneCountryLabel(country)),
                );
              }).toList();
            },
            onChanged: (String? newValue) {
              setState(() {
                _selectedCountry = newValue!;
                _telephone_Controller.clear();
              });
            },
            items: _countryCodes.keys.map((String country) {
              return DropdownMenuItem<String>(
                value: country,
                child: Text(_phoneCountryLabel(country)),
              );
            }).toList(),
          ),
          SizedBox(height: size.height * 0.02),
          TextFormField(
            controller: _telephone_Controller,
            keyboardType: TextInputType.number,
            inputFormatters: _selectedCountry == 'Bénin'
                ? [BeninPhoneInputFormatter()]
                : [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_rounded),
              hintText: _selectedCountry == 'Bénin'
                  ? '01 xx xx xx xx'
                  : 'phone_number'.tr,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'enter_phone'.tr;
              }
              if (_selectedCountry == 'Bénin' &&
                  !isValidBeninLocalPhone(value)) {
                return 'benin_phone_format'.tr;
              }
              int requiredLength = _phoneNumberLengths[_selectedCountry]!;
              if (phoneDigits(value).length != requiredLength) {
                return 'phone_length'.trParams({'count': '$requiredLength'});
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
          /*_buildTextField(
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
                SizedBox(height: size.height * 0.02),*/
          // Champ pour le mot de passe
          Obx(() => _buildPasswordField(
                controller: passwordController,
                hintText: 'password'.tr,
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
            onSuccess: () {},
            onFail: () {},
          ),
          SizedBox(height: size.height * 0.03),
          // Champ pour confirmer le mot de passe
          Obx(() => _buildPasswordField(
                controller: passwordConfirmController,
                hintText: 'confirm_password'.tr,
                simpleUIController: simpleUIController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'confirm_password_required'.tr;
                  }
                  if (value != passwordController.text) {
                    // Comparaison des deux champs
                    return 'passwords_do_not_match'.tr;
                  }
                  return null;
                },
              )),
          SizedBox(height: size.height * 0.01),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: theme.colorScheme.primary,
            checkColor: Colors.white,
            side: BorderSide(color: theme.dividerColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              'terms_acceptance'.tr,
              style: TextStyle(
                color: _isSelected ? Colors.black : theme.colorScheme.primary,
              ),
            ),
            value: _isSelected,
            onChanged: (newValue) {
              setState(() {
                _isSelected = newValue!;
              });
            },
            controlAffinity:
                ListTileControlAffinity.leading, // Place la checkbox à gauche
          ),
          SizedBox(height: size.height * 0.02),
          /*ElevatedButton.icon(
                  onPressed: getCurrentLocation,
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  label: const Text('Get My Current Location', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                ),
                SizedBox(height: size.height * 0.02),*/
          // Bouton de sign up
          signUpButton(theme),
        ],
      ),
    );
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    position = newPosition;

    List<Placemark> placeMarks =
        await placemarkFromCoordinates(position!.latitude, position!.longitude);
    Placemark pMarks = placeMarks[0];

    completeAddress = '${pMarks.subThoroughfare} ${pMarks.thoroughfare}, '
        '${pMarks.subLocality} ${pMarks.locality}, '
        '${pMarks.subAdministrativeArea}, ${pMarks.administrativeArea} ${pMarks.postalCode}, ${pMarks.country}';

    locationController.text = completeAddress;
  }

  // Méthode pour créer un champ de texte réutilisable
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType, // Ajout du keyboardType optionnel
    List<TextInputFormatter>?
        inputFormatters, // Ajout des inputFormatters optionnels
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: validator,
      keyboardType: keyboardType,
      // Utilisation du keyboardType passé en paramètre
      inputFormatters:
          inputFormatters, // Utilisation des inputFormatters passés en paramètre
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () async {
          if (_formKey.currentState!.validate()) {
            String encryptedPassword =
                await Users.encryptPassword(passwordController.text);

            dynamic result = await Users.manageUser(
              roleID: 2,
              password: passwordController.text,
              password_crypte: encryptedPassword,
              firstname: firstnameController.text,
              lastname: lastnameController.text,
              username: usernameController.text,
              email: emailController.text,
              telephone: phoneDigits(_telephone_Controller.text),
              country: _selectedCountry,
              status: '',
              identity: '',
              addressID: 0,
            );

            if (result is int) {
              // Vérifie si la réponse est bien un userID
              int userID = result;
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('userVerified', false);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerificationPage(
                    userID: userID, // Envoie l'ID de l'utilisateur
                    email: emailController.text,
                    roleID: 2,
                    password: passwordController.text,
                    password_crypte: encryptedPassword,
                    firstname: firstnameController.text,
                    lastname: lastnameController.text,
                    username: usernameController.text,
                    telephone: phoneDigits(_telephone_Controller.text),
                    country: _selectedCountry,
                    indicatif: _countryCodes[_selectedCountry] ?? '',
                  ),
                ),
              );
            } else {
              Toast(context, "Erreur : $result", false);
            }
          } else {
            print("Form contains errors");
          }
        },
        child: Text('signup'.tr),
      ),
    );
  }

  String _phoneCountryLabel(String country) {
    return '${_countryFlags[country] ?? ''} $country ${_countryCodes[country]}';
  }

  // Méthode pour vider tous les champs
  void _clearTextFields() {
    firstnameController.clear();
    lastnameController.clear();
    usernameController.clear();
    emailController.clear();
    passwordController.clear();
    passwordConfirmController.clear();
    _telephone_Controller.clear();
  }
}
