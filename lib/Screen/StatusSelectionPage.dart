import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importer Riverpod

import '../Constant/Constant.dart';
import '../components/showConfetti.dart';
import '../modeles/users.dart';
import '../providers/users_provider.dart';
import 'AnimatedSplashScreen.dart';
import 'curved_navigation/CurvedNavigation.dart';
import 'restaurants/RestaurantFormPage.dart';

class StatusSelectionPage extends ConsumerWidget {
  final String country;

  StatusSelectionPage({required this.country});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<String> statusOptions = ["Particulier", "Micro restaurant"];
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.home), // Icône personnalisée (ex: home)
            onPressed: () {
              // Navigation vers l'écran de splash lorsqu'on clique sur l'icône
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => AnimatedSplashScreen()),
                    (Route<dynamic> route) => false, // Supprime toutes les routes précédentes
              );
            },
          )
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: size.width > 600
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
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
                'Sélectionnez votre statut',
                style: kLoginTitleStyle(size), // Assurez-vous que cette fonction est bien définie
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var status in statusOptions)
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          int roleID = status == "Particulier" ? 2 : 3;

                          // Récupérer l'utilisateur du Provider
                          final user = ref.read(usersProvider);

                          if (user != null) {
                            await Users.updateCountryAndRole(user.userID, country, roleID);
                            await Users.updateDerniereConnexion(user.userID);
                            if(status == "Particulier"){
                              //todo : animation bienvenue sur dios délices
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => WelcomeScreen(),
                                ),
                              );

                              // Rediriger vers la page principale
                              /*Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (ctx) => CurvedNavigation(specified_index: 0),
                                ),
                              );*/
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RestaurantFormPage()),
                              );
                            }
                          } else {
                            // Gérer le cas où l'utilisateur n'est pas trouvé
                            print("Utilisateur non trouvé.");
                          }
                        },
                        child: Text(status),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
