import 'package:dios_delices/Screen/utilisateurs/UserIdentityRejected.dart';
import 'package:dios_delices/Screen/verif_confirm/WaitIdentityValidation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../components/showConfetti.dart';
import '../../core/app_role.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../services/session_service.dart';
import '../../utils/toast.dart';
import '../restaurants/RestaurantFormPage.dart';
import '../verif_confirm/StartAddressSaving.dart';
import '../verif_confirm/StatusSelectionPage.dart';
import '../restaurants/RestaurantUpdateFormPage.dart';
import '../restaurants/WaitRestaurantValidation.dart';
import '../verif_confirm/VerificationPage.dart';
import 'package:dios_delices/providers/users_provider.dart';

class Login extends ConsumerStatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  List<Users> users = [];
  List<Restaurant> restaus = [];

  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool loginFailed = false;

  @override
  void initState() {
    super.initState();
    Get.put(SimpleUIController());
    loadData();
    //checkVerificationStatus();
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /*Future<void> checkVerificationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isVerified = prefs.getBool('userVerified') ?? false;

    if (!isVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPage(
            userID: prefs.getInt('userID')!,
            email: prefs.getString('pendingEmail')!,
            roleID: prefs.getInt('pendingRoleID')!,
            telephone: prefs.getInt('pendingTelephone')!,
            password_crypte: prefs.getString('pendingPasswordCrypte')!,
            password: prefs.getString('pendingPassword')!,
            firstname: prefs.getString('pendingFirstname')!,
            lastname: prefs.getString('pendingLastname')!,
            username: prefs.getString('pendingUsername')!,
            indicatif: prefs.getString('indicatif')!,
          ),
        ),
      );
    }
  }*/
  Future<void> checkVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isVerified = prefs.getBool('userVerified') ?? false;

    // Vérifier si les données nécessaires sont bien présentes avant de continuer
    int? userID = prefs.getInt('userID');
    String? email = prefs.getString('pendingEmail');
    int? roleID = prefs.getInt('pendingRoleID');
    int? telephone = prefs.getInt('pendingTelephone');
    String? passwordCrypte = prefs.getString('pendingPasswordCrypte');
    String? password = prefs.getString('pendingPassword');
    String? firstname = prefs.getString('pendingFirstname');
    String? lastname = prefs.getString('pendingLastname');
    String? username = prefs.getString('pendingUsername');
    String? indicatif = prefs.getString('indicatif');

    // Si une des valeurs importantes est manquante, on ne redirige pas
    if (!isVerified &&
        userID != null &&
        email != null &&
        roleID != null &&
        telephone != null &&
        passwordCrypte != null &&
        password != null &&
        firstname != null &&
        lastname != null &&
        username != null &&
        indicatif != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPage(
            userID: userID,
            email: email,
            roleID: roleID,
            telephone: telephone,
            password_crypte: passwordCrypte,
            password: password,
            firstname: firstname,
            lastname: lastname,
            username: username,
            indicatif: indicatif,
          ),
        ),
      );
    } else {
      print(
          "Les données de vérification sont incomplètes ou utilisateur déjà vérifié.");
    }
  }

  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant>? restausList =
        await Restaurant.fetchRestaurantsFromDB(); // Vérifier ici

    setState(() {
      users = usersList;
      restaus = restausList ?? []; // Si `null`, assigner une liste vide
    });
  }

  Future<void> performLogin() async {
    try {
      final user = await Users.verifUser(
        users,
        nameController.text,
        passwordController.text,
      );
      ref.read(usersProvider.notifier).state = user;

      // l'user existe
      if (user != null) {
        final role = AppRole.fromId(user.roleID);
        await SessionService.saveUserSession(
          userId: user.userID,
          role: role,
          country: user.country,
        );

        // si c'est un admin ou un super admin il se connecte directement
        if (role.isAdmin) {
          firstLogin(user);
        } else {
          // l'email et le téléphone ont été vérifiés
          if (user.status == "Verified") {
            _handleApprovedUser(user);

            // l'user n'a pas d'adresse
            if (user.country.trim().isEmpty) {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                    builder: (ctx) => StartAddressSaving(
                      userID: user.userID,
                      roleID: user.roleID,
                    )),
              );

            } else {
              // l'user a une adresse
              // l'identité a été vérifiée
              if (user.identity == "Verified") {
                //si c'est un resto
                if (role.isProfessional) {
                  // on vérifie que le resto est enregistré et validé
                  _handleRestaurantValidation(user);
                } else {
                  // il peut se connecter ; tous les users qui ne sont pas des admins ont un restau
                  if (role.isIndividual) {
                    final restau = await Restaurant.getRestaurantByUser(
                      restaus,
                      user.userID,
                    );
                    if (restau != null) {
                      await SessionService.setRestaurantId(restau.restaurantID);
                    }
                  }
                  firstLogin(user);
                }
              } else if (user.identity == "En attente") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WaitIdentityValidation(),
                  ),
                );
              } else if (user.identity == "Rejected") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserIdentityRejected(objectID: user.userID, user_roleID: user.roleID),
                  ),
                );
              } else {
                // faire la vérification d'identité
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatusSelectionPage(country: user.country, objectID: user.userID, user_roleID: user.roleID),
                  ),
                );
              }
            }
          } else {
            _redirectToVerification(user);
          }
        }
      } else {
        _handleLoginFailure();
      }
    } catch (e) {
      _handleLoginFailure();
    }
  }

  void _handleApprovedUser(Users user) async {
    // si l'utilisateur ne s'est jamais connecté et s'il n'est ni un admin ni un super admin
    final role = AppRole.fromId(user.roleID);
    if (user.last_login == null && !role.isAdmin) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
            builder: (ctx) => StartAddressSaving(
              userID: user.userID,
              roleID: user.roleID,
            )),
      );
    } else {
      /*if (user.roleID == 1 || user.roleID == 2 || user.roleID == 4) {
                 firstLogin(user);

      } else {
        _handleRestaurantValidation(user, prefs);
      }*/
    }
  }

  void _handleRestaurantValidation(Users user) async {
    final restau = await Restaurant.getRestaurantByUser(restaus, user.userID);

    if (restau != null) {
      // le restau n'est pas encore validé
      if (restau.valid == 0) {
        _redirectToWaitValidation();
      } else if (restau.valid == 1) {
        // le restau est validé il peut se connecter
        await SessionService.setRestaurantId(restau.restaurantID);
        firstLogin(user);
      } else {
        // il y a des erreurs dans le formulaire
        _redirectToRestaurantUpdate(user, restau);
      }
    } else {
      // on va enregistrer le restau
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RestaurantFormPage()),
      );
      //Toast(context, "Erreur : Contactez les administrateurs.", false);
    }
  }

  void _redirectToVerification(Users user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationPage(
          userID: user.userID,
          email: user.email,
          roleID: user.roleID,
          password: passwordController.text,
          password_crypte: user.password,
          firstname: user.firstname,
          lastname: user.lastname,
          username: user.username,
          telephone: int.tryParse(user.telephone.toString()) ?? 0,
          indicatif: _getIndicatif(user.country),
        ),
      ),
    );
  }

  void _redirectToWaitValidation() {
    setState(() {
      loginFailed = true;
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => WaitRestaurantValidation()));
    });
  }

  void _redirectToRestaurantUpdate(Users user, Restaurant restau) {
    setState(() {
      loginFailed = true;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  RestaurantUpdateFormPage(user: user, restaurant: restau)));
    });
  }

  void _handleLoginFailure() {
    setState(() {
      isLoading = false;
      loginFailed = true;
    });
    Toast(context, "Erreur : Identifiant(s) incorrect(s)", false);
  }

  String _getIndicatif(String country) {
    switch (country) {
      case "Bénin":
        return "+229";
      case "Côte 'Ivoire":
        return "+225";
      case "États-Unis":
        return "+1";
      default:
        return "+33";
    }
  }

  Future<void> firstLogin(Users user) async {
    if (user.last_login == null) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => WelcomeScreen(),
        ),
      );
    } else {
      await Users.updateDerniereConnexion(user.userID);
      Users.chooseCurvedNavigation(user.roleID, user.country, context);
    }
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

                        /*Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => EmailInputScreen(
                                listusers: users,
                              )),
                        );*/
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
          if (nameController.text.trim().isEmpty ||
              passwordController.text.isEmpty) {
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
