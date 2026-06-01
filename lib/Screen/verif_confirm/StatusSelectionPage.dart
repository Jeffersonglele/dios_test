import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importer Riverpod

import '../../Constant/Constant.dart';
import '../../components/showConfetti.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../providers/users_provider.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../AnimatedSplashScreen.dart';
import 'StartIdentityVerification.dart';
import '../restaurants/RestaurantFormPage.dart';

class StatusSelectionPage extends ConsumerWidget {
  final String country;
  final int objectID;
  final int user_roleID;

  StatusSelectionPage(
      {required this.country,
      required this.objectID,
      required this.user_roleID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<String> statusOptions = ["Particulier", "Restaurateur"];
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
            (Route<dynamic> route) =>
                false, // Supprime toutes les routes précédentes
          );
        },
      )),
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
                : const Center(child: BrandAvatarLogo()),
            SizedBox(height: size.height * 0.03),
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Text(
                'Sélectionnez votre statut',
                style: kLoginTitleStyle(
                    size), // Assurez-vous que cette fonction est bien définie
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var status in statusOptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 58,
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

                            //créer un restaurant pour l'utilisateur pour des questions de base de données

                            // Récupérer l'utilisateur du Provider
                            final user = ref.read(usersProvider);

                            if (roleID == 2) {
                              print("créer le restau du particulier");
                              final fictifName = "La cuisine de ${user!.firstname}";
                              String createResult =
                                  await Restaurant.manageRestaurant(
                                      userID: user!.userID,
                                      valid: 1,
                                      nb_orders: 0,
                                      note: 0.0,
                                      categories: "",
                                      description: "",
                                      adress: "",
                                      name: fictifName);
                              print("createResult restau " + createResult);
                            }

                            if (user != null) {
                              await Users.updateCountryAndRole(
                                  user.userID, country, roleID);
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      StartIdentityVerification(
                                    objectID: objectID,
                                    user_roleID: roleID,
                                  ),
                                ),
                              );
                            } else {
                              // Gérer le cas où l'utilisateur n'est pas trouvé
                              print("Utilisateur non trouvé.");
                            }
                          },
                          child: Text(status),
                        ),
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
