import 'package:flutter/material.dart';
import 'AnimatedSplashScreen.dart';

class ConfirmationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Confirmation"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Votre demande a bien été prise en compte.",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              "Vous serez contacté si votre idée de micro-restaurant est acceptée.",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Retourner à l'écran splash
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => AnimatedSplashScreen()),
                      (Route<dynamic> route) => false,
                );
              },
              child: Text("Retourner à l'accueil"),
            ),
          ],
        ),
      ),
    );
  }
}
