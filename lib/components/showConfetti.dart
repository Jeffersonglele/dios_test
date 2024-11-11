import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modeles/users.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // Initialiser le contrôleur de confettis
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));

    // Démarrer les confettis
    _confettiController.play();

    // Attendre 5 secondes avant de rediriger l'utilisateur
    Future.delayed(Duration(seconds: 5), () async {
      // Récupérer le rôle de l'utilisateur depuis SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int userRole = prefs.getInt('currentUser_role') ?? 0;
      String userCountry = prefs.getString('currentUser_country') ?? "France";

      // Rediriger vers la bonne page en fonction du rôle de l'utilisateur
      Users.chooseCurvedNavigation(userRole, userCountry, context);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose(); // Ne pas oublier de disposer le contrôleur de confettis
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Widget des confettis
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive, // Éparpillement
            shouldLoop: false, // Ne pas répéter les confettis
            colors: [Colors.red, Colors.green, Colors.blue, Colors.orange], // Couleurs des confettis
          ),
          // Message de bienvenue
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Bienvenue sur Dios Délices",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                CircularProgressIndicator(), // Indicateur de chargement pendant l'attente
              ],
            ),
          ),
        ],
      ),
    );
  }
}
