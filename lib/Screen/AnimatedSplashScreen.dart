import 'dart:async';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:dios_delices/Screen/authentification/Signup.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../Constant/Constant.dart';
import '../modeles/dish.dart';
import '../modeles/users.dart';

import '../utils/toast.dart';
import 'authentification/Login.dart';

class AnimatedSplashScreen extends ConsumerStatefulWidget {
  const AnimatedSplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends ConsumerState<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  List<Users> listUsers = [];
  List<Restaurant> listRestaurants = [];
  List<Dish> listDishes = [];
  bool isLoading = false;

  Future<bool> isConnectedToInternet() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  var _visible = true;
  late AnimationController animationController;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    // Initialisation de l'animation
    animationController = new AnimationController(
        vsync: this, duration: new Duration(seconds: 4));
    animation = new CurvedAnimation(parent: animationController, curve: Curves.easeOut);

    animation.addListener(() => this.setState(() {}));
    animationController.forward();

    // Démarrage de l'animation
    setState(() {
      _visible = !_visible;
    });

    // Démarrer la récupération des données après 3 secondes (animation terminée)
    startTime();
  }

  // Fonction pour commencer un timer de 3 secondes avant de récupérer les données
  startTime() async {
    var _duration = new Duration(seconds: 3);
    return new Timer(_duration, getData); // Appelle performLogin après le délai
  }

  // Fonction pour récupérer les données et naviguer vers la bonne page
  Future<void> getData() async {
    // Vérifie la connexion internet
    if (!(await isConnectedToInternet())) {
      Toast(context, "Connectez-vous à internet pour continuer", false);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Récupération des données
      await Users.getAllUsersDetails();
      await Restaurant.getAllRestaurantsDetails();
      await Dish.getAllDishesDetails();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Toast(context, e.toString(), false);
    }
    Navigator.push(context, CupertinoPageRoute(builder: (ctx) => const SignUpView()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Ajout de l'image de fond
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'), // Votre image de fond
                fit: BoxFit.cover, // Ajustement de l'image pour couvrir tout l'écran
              ),
            ),
          ),
          // Les éléments par-dessus l'image de fond
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: AvatarGlow(
                  duration: Duration(seconds: 2),
                  glowColor: Colors.white24,
                  repeat: true,
                  startDelay: Duration(seconds: 1),
                  child: Material(
                    elevation: 12.0,  // Augmenter l'élévation pour un effet de profondeur
                    shape: CircleBorder(),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage('assets/images/logo_sm01.jpg'),
                      radius: 100.0,  // Augmenter le rayon pour agrandir l'image
                    ),
                  ),
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(), // Loading indicator
                ),
            ],
          ),

        ],
      ),
    );
  }
}