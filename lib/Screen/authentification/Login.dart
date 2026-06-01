import 'package:dios_delices/Screen/utilisateurs/UserIdentityRejected.dart';
import 'package:dios_delices/Screen/verif_confirm/WaitIdentityValidation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../components/showConfetti.dart';
import '../../core/app_role.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../db/database_helper.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../utils/toast.dart';
import '../restaurants/RestaurantFormPage.dart';
import '../verif_confirm/StartAddressSaving.dart';
import '../verif_confirm/StatusSelectionPage.dart';
import '../restaurants/RestaurantUpdateFormPage.dart';
import '../restaurants/WaitRestaurantValidation.dart';
import '../password/EmailInputScreen.dart';
import '../verif_confirm/VerificationPage.dart';
import 'package:dios_delices/providers/users_provider.dart';
import '../../widgets/auth_shell.dart';

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
            telephone: prefs.getString('pendingTelephone') ?? '',
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
    String? telephone = prefs.getString('pendingTelephone');
    String? passwordCrypte = prefs.getString('pendingPasswordCrypte');
    String? password = prefs.getString('pendingPassword');
    String? firstname = prefs.getString('pendingFirstname');
    String? lastname = prefs.getString('pendingLastname');
    String? username = prefs.getString('pendingUsername');
    String? indicatif = prefs.getString('indicatif');
    String country = prefs.getString('pendingCountry') ??
        _getCountryFromIndicatif(indicatif);

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
            country: country,
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
      final user = await _findUserForLogin();
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
                  NotificationService.subscribeToRestaurantNotifications();
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
                  NotificationService.subscribeToRestaurantNotifications();
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
                    builder: (context) => UserIdentityRejected(
                        objectID: user.userID, user_roleID: user.roleID),
                  ),
                );
              } else {
                // faire la vérification d'identité
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatusSelectionPage(
                        country: user.country,
                        objectID: user.userID,
                        user_roleID: user.roleID),
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

  Future<Users?> _findUserForLogin() async {
    Users? user = await Users.verifUser(
      users,
      nameController.text,
      passwordController.text,
    );

    if (user != null) {
      return user;
    }

    user = await Users.loginUser(
      nameController.text,
      passwordController.text,
    );

    if (user != null) {
      await DatabaseHelper.createUser(user);
      final freshUsers = await Users.fetchUsersFromDB();
      if (mounted) {
        setState(() => users = freshUsers);
      }
      return user;
    }

    await Users.getAllUsersDetails();
    final freshUsers = await Users.fetchUsersFromDB();

    if (mounted) {
      setState(() {
        users = freshUsers;
      });
    }

    return Users.verifUser(
      freshUsers,
      nameController.text,
      passwordController.text,
    );
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
        NotificationService.subscribeToRestaurantNotifications();
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
    final country = _countryOrDefault(user.country);

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
          telephone: user.telephone.toString(),
          country: country,
          indicatif: _getIndicatif(country),
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
    Toast(context, 'login_failed'.tr, false);
  }

  String _getIndicatif(String country) {
    switch (_countryOrDefault(country)) {
      case "Bénin":
        return "+229";
      case "Côte d'Ivoire":
        return "+225";
      case "États-Unis":
        return "+1";
      case "France":
        return "+33";
      default:
        return "+229";
    }
  }

  String _getCountryFromIndicatif(String? indicatif) {
    switch (indicatif) {
      case "+229":
        return "Bénin";
      case "+225":
        return "Côte d'Ivoire";
      case "+1":
        return "États-Unis";
      case "+33":
        return "France";
      default:
        return "Bénin";
    }
  }

  String _countryOrDefault(String country) {
    final cleanCountry = country.trim();
    return cleanCountry.isEmpty ? "Bénin" : cleanCountry;
  }

  Future<void> firstLogin(Users user) async {
    NotificationService.subscribeToRestaurantNotifications();
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
    final size = MediaQuery.of(context).size;
    final simpleUIController = Get.find<SimpleUIController>();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: 'login_title'.tr,
        subtitle: 'login_subtitle'.tr,
        form: _buildForm(size, simpleUIController),
        footer: GestureDetector(
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
              text: 'dont_have_account'.tr,
              style: kHaveAnAccountStyle(size),
              children: [
                TextSpan(
                  text: " ${'signup'.tr}",
                  style: kLoginOrSignUpTextStyle(size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    Size size,
    SimpleUIController simpleUIController,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Champ username ou email
          TextFormField(
            style: kTextFormFieldStyle(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person),
              hintText: 'username_or_email'.tr,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
            ),
            controller: nameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'enter_username'.tr;
              } else if (value.length < 4) {
                return 'min_4_chars'.tr;
              } else if (value.length > 13) {
                return 'max_13_chars'.tr;
              }
              return null;
            },
          ),
          SizedBox(height: size.height * 0.02),
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
                hintText: 'password'.tr,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'enter_password'.tr;
                } else if (value.length < 7) {
                  return 'min_6_chars'.tr;
                } else if (value.length > 13) {
                  return 'max_13_chars'.tr;
                }
                return null;
              },
            ),
          ),
          SizedBox(height: size.height * 0.014),
          // Bouton de connexion
          loginButton(),
          SizedBox(height: size.height * 0.014),
          Align(
            alignment: Alignment.centerRight,
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
                    ),
                  ),
                );
              },
              child: RichText(
                text: TextSpan(
                  text: 'forgotten_password'.tr,
                  style: forgottenpasswordTextStyle(size),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bouton de connexion
  Widget loginButton() {
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
          if (nameController.text.trim().isEmpty ||
              passwordController.text.isEmpty) {
            Toast(context, 'login_missing_fields'.tr, false);
          } else {
            await performLogin();
          }
        },
        child: Text('login'.tr),
      ),
    );
  }
}
