import 'package:dios_delices/Screen/utilisateurs/UserIdentityRejected.dart';
import 'package:dios_delices/Screen/verif_confirm/WaitIdentityValidation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';
import '../../core/app_role.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../db/database_helper.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/strings.dart';
import '../../utils/toast.dart';
import '../restaurants/RestaurantFormPage.dart';
import '../verif_confirm/StartAddressSaving.dart';
import '../verif_confirm/StatusSelectionPage.dart';
import '../restaurants/RestaurantUpdateFormPage.dart';
import '../restaurants/WaitRestaurantValidation.dart';
import '../password/EmailInputScreen.dart';
import '../verif_confirm/VerificationPage.dart';
import '../../widgets/animations.dart';
import '../../widgets/auth_shell.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late AnimationController _btnCtrl;
  late Animation<double> _btnFade;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.3, 0.8, curve: AppMotion.standard)));
    _textSlide = Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.3, 0.8, curve: AppMotion.standard)));
    _textCtrl.forward();
    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: AppMotion.standard);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) { setState(() => _showButton = true); _btnCtrl.forward(); }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final session = await SessionService.readSession();
    if (mounted) {
      Users.chooseCurvedNavigation(session.role.id, session.country, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: OrderConfettiCelebration(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedSuccessCheck(),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(children: [
                        Text('Bienvenue !', style: AppTypography.headlineLarge(), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text('Votre compte a été créé avec succès.\nDécouvrez les meilleurs plats faits maison près de chez vous.',
                            style: AppTypography.bodyLarge(color: AppColors.inkMuted), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_showButton)
                    FadeTransition(
                      opacity: _btnFade,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _continue,
                          child: const Text('Découvrir'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool loginFailed = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant>? restausList = await Restaurant.fetchRestaurantsFromDB();
    setState(() {
      users = usersList;
      restaus = restausList ?? [];
    });
  }

  Future<void> performLogin() async {
    setState(() => isLoading = true);
    try {
      final user = await _findUserForLogin();
      if (user == null) { _handleLoginFailure(); return; }

      final role = AppRole.fromId(user.roleID);
      await SessionService.saveUserSession(
        userId: user.userID, role: role, country: user.country,
      );

      if (role.isAdmin) {
        firstLogin(user);
      } else if (user.status == "Verified") {
        _handleApprovedUser(user);
      } else {
        _redirectToVerification(user);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      Toast(context, 'Erreur de connexion. Vérifiez votre réseau.', false);
      _handleLoginFailure();
    }
  }

  Future<Users?> _findUserForLogin() async {
    Users? user = await Users.verifUser(users, nameController.text, passwordController.text);
    if (user != null) return user;

    user = await Users.loginUser(nameController.text, passwordController.text);
    if (user != null) {
      await DatabaseHelper.createUser(user);
      final fresh = await Users.fetchUsersFromDB();
      if (mounted) setState(() => users = fresh);
      return user;
    }

    await Users.getAllUsersDetails();
    final fresh = await Users.fetchUsersFromDB();
    if (mounted) setState(() => users = fresh);
    return Users.verifUser(fresh, nameController.text, passwordController.text);
  }

  void _handleApprovedUser(Users user) async {
    if (user.country.trim().isEmpty) {
      Navigator.pushReplacement(context, CupertinoPageRoute(
          builder: (_) => StartAddressSaving(userID: user.userID, roleID: user.roleID)));
    } else if (user.identity == "Verified") {
      final role = AppRole.fromId(user.roleID);
      if (role.isProfessional) {
        NotificationService.subscribeToRestaurantNotifications();
        _handleRestaurantValidation(user);
      } else {
        if (role.isIndividual) {
          final r = await Restaurant.getRestaurantByUser(restaus, user.userID);
          if (r != null) await SessionService.setRestaurantId(r.restaurantID);
        }
        NotificationService.subscribeToRestaurantNotifications();
        firstLogin(user);
      }
    } else if (user.identity == "En attente") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => WaitIdentityValidation()));
    } else if (user.identity == "Rejected") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserIdentityRejected(objectID: user.userID, user_roleID: user.roleID)));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => StatusSelectionPage(country: user.country, objectID: user.userID, user_roleID: user.roleID)));
    }
  }

  void _handleRestaurantValidation(Users user) async {
    final restau = await Restaurant.getRestaurantByUser(restaus, user.userID);
    if (restau == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantFormPage()));
    } else if (restau.valid == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => WaitRestaurantValidation()));
    } else if (restau.valid == 1) {
      await SessionService.setRestaurantId(restau.restaurantID);
      NotificationService.subscribeToRestaurantNotifications();
      firstLogin(user);
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => RestaurantUpdateFormPage(user: user, restaurant: restau)));
    }
  }

  void _redirectToVerification(Users user) {
    final country = user.country.trim().isEmpty ? "Bénin" : user.country.trim();
    Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationPage(
      userID: user.userID, email: user.email, roleID: user.roleID,
      password: passwordController.text, password_crypte: user.password,
      firstname: user.firstname, lastname: user.lastname, username: user.username,
      telephone: user.telephone.toString(), country: country,
      indicatif: _indicatif(country),
    )));
  }

  void _handleLoginFailure() {
    setState(() { isLoading = false; loginFailed = true; });
    Toast(context, Strings.of('login_failed'), false);
  }

  String _indicatif(String c) {
    switch (c) {
      case "Bénin": return "+229";
      case "Côte d'Ivoire": return "+225";
      case "France": return "+33";
      default: return "+229";
    }
  }

  Future<void> firstLogin(Users user) async {
    NotificationService.subscribeToRestaurantNotifications();
    if (user.last_login == null) {
      Navigator.push(context, CupertinoPageRoute(builder: (_) => const WelcomeScreen()));
    } else {
      await Users.updateDerniereConnexion(user.userID);
      Users.chooseCurvedNavigation(user.roleID, user.country, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AuthShell(
        title: Strings.of('login_title'),
        subtitle: Strings.of('login_subtitle'),
        form: _buildForm(size),
        footer: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            nameController.clear();
            passwordController.clear();
            _formKey.currentState?.reset();
          },
          child: RichText(
            text: TextSpan(
              text: Strings.of('dont_have_account'),
              style: kHaveAnAccountStyle(size),
              children: [
                TextSpan(
                  text: " ${Strings.of('signup')}",
                  style: kLoginOrSignUpTextStyle(size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(Size size) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            style: AppTypography.bodyLarge(),
            controller: nameController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded),
              hintText: Strings.of('username_or_email'),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return Strings.of('enter_username');
              if (v.length < 4) return Strings.of('min_4_chars');
              if (v.length > 13) return Strings.of('max_13_chars');
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            style: AppTypography.bodyLarge(),
            controller: passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              hintText: Strings.of('password'),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return Strings.of('enter_password');
              if (v.length < 7) return Strings.of('min_6_chars');
              if (v.length > 13) return Strings.of('max_13_chars');
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || passwordController.text.isEmpty) {
                  Toast(context, Strings.of('login_missing_fields'), false);
                } else {
                  await performLogin();
                }
              },
              child: Text(Strings.of('login')),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              nameController.clear();
              passwordController.clear();
              _formKey.currentState?.reset();
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EmailInputScreen(listusers: users)));
            },
            child: Align(
              alignment: Alignment.center,
              child: Text(
                Strings.of('forgotten_password'),
                style: AppTypography.labelLarge(color: AppColors.brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

