import 'dart:math';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Controller/UiController.dart';
import '../../modeles/address.dart';
import '../../modeles/users.dart';

class NearMeRestaurants extends StatefulWidget {
  const NearMeRestaurants({Key? key}) : super(key: key);

  @override
  State<NearMeRestaurants> createState() => _NearMeRestaurantsState();
}

class _NearMeRestaurantsState extends State<NearMeRestaurants> {
  String googleApiKey = 'AIzaSyDbNMAeiSEuFBhS0rpObu1wBk8V3Xx33LA'; // Remplacez par votre clé API Google
  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  String? country = "";
  int currentUser_role = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  List<Map<String, dynamic>> filteredRestaurants = [];
  List<Users> users = [];
  List<Restaurant> restaus = [];
  List<Address> addresses = [];

  int current_userID = 0;
  int current_user_role = 0;
  int current_user_restau = 0;

  void loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int userID = prefs.getInt('loggedUserID') ?? 0;
    int userRole = prefs.getInt('currentUser_role') ?? 0;
    int userRestauID = prefs.getInt('currentUser_restau') ?? 0;

    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();
    List<Address> addressesList = await Address.fetchAddressesFromDB();

    setState(() {
      current_userID = userID;
      current_user_role = userRole;
      current_user_restau = userRestauID;

      users = usersList;
      restaus = restausList;
      addresses = addressesList;
    });
    await _filterRestaurants();
  }

  Future<void> _filterRestaurants() async {
    for (var a in addresses) {
      if (a.objectID == current_userID) {
        Address userAddress = a;

        const double maxDistanceKm = 10.0;
        List<Map<String, dynamic>> nearbyRestaurants = [];

        for (var restau in restaus) {
          // 🔥 1. Récupérer l'utilisateur du restaurant
          Users? associatedUser = Users.getUsersByUserId(users, restau.userID);

          // 🔥 2. Vérifier si cet utilisateur est particulier (roleID == 2)
          if (associatedUser == null || associatedUser.roleID == 2 || restau.userID == current_userID) {
            continue; // ❌ Exclure ce restaurant
          }

          Address? restauAddress = Address.getAddressByObject(addresses, "User", restau.userID);
          if (restauAddress == null) continue;

          try {
            double userLat = double.parse(userAddress.lat ?? "");
            double userLon = double.parse(userAddress.long ?? "");
            double restauLat = double.parse(restauAddress.lat ?? "");
            double restauLon = double.parse(restauAddress.long ?? "");

            double distance = _calculateDistance(userLat, userLon, restauLat, restauLon);

            if (distance <= maxDistanceKm) {
              nearbyRestaurants.add({
                "restaurant": restau, // ⬅️ Stocke l'objet
                "distance": distance, // ⬅️ Stocke la distance
              });
            }
          } catch (e) {
            print("Erreur de parsing des coordonnées : $e");
          }
        }

        setState(() {
          filteredRestaurants = nearbyRestaurants;
        });
      }
    }
  }


  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon de la Terre en kilomètres

    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restaurants à proximité'),
      ),
      body: filteredRestaurants.isEmpty
          ? Center(
        child: Text(
          'Aucun restaurant à proximité trouvé.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: filteredRestaurants.length,
        itemBuilder: (context, index) {
          final item = filteredRestaurants[index];
          final Restaurant restaurant = item["restaurant"];
          final double distance = item["distance"];

          return Card(
            child: Column(
              children: [
                buildImage(restaurant.image),
                ListTile(
                  title: Text(
                    restaurant.name ?? "Nom indisponible",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                  ),
                  subtitle: Text(
                    "Situé à ${distance.toStringAsFixed(2)} km",
                    style: TextStyle(color: Colors.red.withOpacity(0.6)),
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantDetails(
                          restaurant_id: restaurant.restaurantID,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),

    );
  }

}

// Fonction pour obtenir la position actuelle avec gestion des permissions
Future<Position?> _determinePosition() async {
  LocationPermission permission;

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Le service de localisation est désactivé.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Les permissions de localisation sont refusées');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Les permissions de localisation sont refusées définitivement');
  }

  return await Geolocator.getCurrentPosition();
}


Widget buildImage(String? imageUrl) {
  // Vérifie si le lien est une URL valide
  if (imageUrl != null && Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
    return Image.network(
      imageUrl,
      height: 200,
      width: 300,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/no_image.png', // Image par défaut si le chargement échoue
          height: 200,
          width: 300,
          fit: BoxFit.fitWidth,
        );
      },
    );
  } else {
    // Si ce n'est pas une URL valide, utilisez une image locale
    return Image.asset(
      'assets/images/no_image.png',
      height: 200,
      width: 300,
      fit: BoxFit.fitWidth,
    );
  }
}
