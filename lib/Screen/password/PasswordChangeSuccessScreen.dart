import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../authentification/Login.dart';
import '../../utils/strings.dart';

class PasswordChangeSuccessScreen extends StatelessWidget {
  const PasswordChangeSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Succès"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            Text(
              Strings.of('password_updated'),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  // Couleur de fond du bouton
                  foregroundColor: Colors.white,
                  //Couleur du texte
                  textStyle: const TextStyle(
                    fontSize: 18, // Taille du texte
                    fontWeight:
                        FontWeight.bold, // (Optionnel) Style de texte en gras
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15), // Bordure du bouton
                  ),
                ),
                onPressed: () {
                  Navigator.push(context,
                      CupertinoPageRoute(builder: (ctx) => const Login()));
                  // Navigator.popUntil(context, ModalRoute.withName('/login')); // Retour à la page de login
                },
                child: Text(Strings.of('back_to_login')),
              ),
            )
          ],
        ),
      ),
    );
  }
}
