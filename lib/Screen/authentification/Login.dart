import 'package:dios_delices/Screen/password/EmailInputScreen.dart';
import 'package:dios_delices/providers/users_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../restaurants/RestaurantUpdateFormPage.dart';
import '../restaurants/WaitRestaurantValidation.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../utils/toast.dart';
import '../LocationPage.dart';


class Login extends ConsumerStatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  // Chargement des données locales
  List<Users> users = [];
  List<Restaurant> restaus = [];

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool loginFailed = false;

  @override
  void initState() {
    super.initState();
    Get.put(SimpleUIController());
    loadData();
  }

  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();

    setState(() {
      users = usersList;
      restaus = restausList;
    });
  }

  Future<void> performLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      // Vérification des informations d'identification de l'utilisateur
      final user = await Users.verifUser(
        users,
        nameController.text,
        passwordController.text,
      );

      // Stockage de l'utilisateur dans le state de Riverpod
      ref.read(usersProvider.notifier).state = user;

      // Si user existe
      if (user != null) {
        // Créer un objet ParseUser avec les informations de connexion
        // ParseUser parseUser = ParseUser(nameController.text, passwordController.text, null);

        // Sauvegarder l'état de connexion dans SharedPreferences
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('loggedUserID', user.userID);
        await prefs.setInt('currentUser_role', user.roleID);
        await prefs.setString('currentUser_country', user.country);

        // Si c'est la première connexion, sauf si c'est un admin rediriger vers la page de localisation
        print("user.roleID " + user.roleID.toString());
        if ((user.last_login == null || user.last_login == " ") && (user.roleID != 1 || user.roleID != 4)) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (ctx) => LocationPage(), // Page de localisation
            ),
          );
        } else {
          // Redirection après connexion réussie
         // On vérifie le rôle
          if (user.roleID == 1 || user.roleID == 2 || user.roleID == 4) {
            // ajouter connexion
            await Users.updateDerniereConnexion(user.userID);

            // L'admin ou un particulier peuvent directement accéder à l'appli
            Users.chooseCurvedNavigation(user.roleID, context);

          } else {
            // vérifier que le restau a été validé
            Restaurant? restau = await Restaurant.getRestaurantByUser(restaus, user.userID);

            if (restau != null) {
              if(restau.valid == 0){
                setState(() {
                  loginFailed = true; // Afficher un message d'erreur
                  prefs.setBool('isLoggedIn', false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WaitRestaurantValidation(),
                    ),
                  );
                });
              } else if(restau.valid == 1){
                // Le restau est validé il peut se connecter
                await prefs.setInt('currentUser_restau', restau.restaurantID);
                Users.chooseCurvedNavigation(user.roleID, context);
              } else {
                // restau.valid == 2
                // la validation a échoué, il faut rajouter des informations
                setState(() {
                  loginFailed = true; // Afficher un message d'erreur
                  prefs.setBool('isLoggedIn', false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantUpdateFormPage(user: user, restaurant: restau),
                    ),
                  );
                });
              }
            } else {
              Toast(
                  context,
                  "Erreur : Contactez  les administrateurs.",
                  false);
            }
          }
        }

        // Mettre à jour l'état de l'interface utilisateur
        setState(() {
          loginFailed = false; // La connexion a réussi
        });
      } else {
        // Si la connexion échoue
        setState(() {
          loginFailed = true; // Afficher un message d'erreur
          prefs.setBool('isLoggedIn', false);
        });
        Toast(
            context,
            "Erreur : Aucun utilisateur trouvé ou identifiant(s) incorrect(s)",
            false);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        loginFailed = true;
        prefs.setBool('isLoggedIn', false); // En cas d'erreur
      });
      Toast(
          context,
          "Erreur : Aucun utilisateur trouvé ou identifiant(s) incorrect(s)",
          false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    SimpleUIController simpleUIController = Get.find<SimpleUIController>();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildLargeScreen(size, simpleUIController);
            } else {
              return _buildSmallScreen(size, simpleUIController);
            }
          },
        ),
      ),
    );
  }

  // Écran large
  Widget _buildLargeScreen(
    Size size,
    SimpleUIController simpleUIController,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: RotatedBox(
            quarterTurns: 3,
          ),
        ),
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(
            size,
            simpleUIController,
          ),
        ),
      ],
    );
  }

  // Écran petit
  Widget _buildSmallScreen(
    Size size,
    SimpleUIController simpleUIController,
  ) {
    return Center(
      child: _buildMainBody(
        size,
        simpleUIController,
      ),
    );
  }

  // Corps principal
  Widget _buildMainBody(
    Size size,
    SimpleUIController simpleUIController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        SizedBox(height: size.height * 0.1),
        size.width > 600
            ? Container()
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
        SizedBox(
          height: size.height * 0.03,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Text(
            'Login',
            style: kLoginTitleStyle(size),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Champ username ou email
                TextFormField(
                  style: kTextFormFieldStyle(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Username or email address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                    ),
                  ),
                  controller: nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter username';
                    } else if (value.length < 4) {
                      return 'At least enter 4 characters';
                    } else if (value.length > 13) {
                      return 'Maximum character is 13';
                    }
                    return null;
                  },
                ),
                SizedBox(
                  height: size.height * 0.02,
                ),
                // Champ mot de passe
                Obx(
                  () => TextFormField(
                    style: kTextFormFieldStyle(),
                    controller: passwordController,
                    obscureText: simpleUIController.isObscure.value,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_open),
                      suffixIcon: IconButton(
                        icon: Icon(
                          simpleUIController.isObscure.value
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          simpleUIController.isObscureActive();
                        },
                      ),
                      hintText: 'Password',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      } else if (value.length < 7) {
                        return 'At least enter 6 characters';
                      } else if (value.length > 13) {
                        return 'Maximum character is 13';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  height: size.height * 0.01,
                ),
                // Bouton de connexion
                loginButton(),
                SizedBox(
                  height: size.height * 0.01,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Visibility(
                    visible: loginFailed,
                    // Affiche seulement si la connexion a échoué
                    child: GestureDetector(
                      onTap: () {
                        nameController.clear();
                        emailController.clear();
                        passwordController.clear();
                        _formKey.currentState?.reset();
                        simpleUIController.isObscure.value = true;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => EmailInputScreen(
                                    listusers: users,
                                  )),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Forgotten password ?',
                          style: forgottenpasswordTextStyle(size),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: size.height * 0.03,
                ),
                // Lien vers l'inscription
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    nameController.clear();
                    emailController.clear();
                    passwordController.clear();
                    _formKey.currentState?.reset();
                    simpleUIController.isObscure.value = true;
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Don\'t have an account?',
                      style: kHaveAnAccountStyle(size),
                      children: [
                        TextSpan(
                          text: " Sign up",
                          style: kLoginOrSignUpTextStyle(
                            size,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Bouton de connexion
  Widget loginButton() {
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
          if (nameController.text == null ||
              passwordController.text.isEmpty ||
              nameController.text == null ||
              passwordController.text.isEmpty) {
            //await DatabaseHelper.cleanUpDatabase(false);
            Toast(
                context, "Erreur : Entrez un login et un mot de passe", false);
          } else {
            await performLogin();
          }
        },
        child: const Text('Login'),
      ),
    );
  }
}
