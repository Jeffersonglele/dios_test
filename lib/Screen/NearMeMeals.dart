import 'dart:convert';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Controller/UiController.dart';

class NearMeMeals extends StatefulWidget {
  const NearMeMeals({Key? key}) : super(key: key);

  @override
  State<NearMeMeals> createState() => _NearMeMealsState();
}

class _NearMeMealsState extends State<NearMeMeals> {
  List _nearbyRestaurants = [];
  String googleApiKey = 'AIzaSyDbNMAeiSEuFBhS0rpObu1wBk8V3Xx33LA'; // Remplacez par votre clé API Google
  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  String? country = "";
  int currentUser_role = 0;

  @override
  void initState() {
    super.initState();
    fetchNearbyRestaurants();
  }

  Future<void> fetchNearbyRestaurants() async {
    Position? userPosition = await _getUserLocation();
    if (userPosition != null) {
      await loadData(userPosition);
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      // TODO decommenter return await _determinePosition();
      return Position(
          latitude: 44.8315, // Latitude pour 17 rue Forestier, 33800 Bordeaux
          longitude: -0.5716, // Longitude pour 17 rue Forestier, 33800 Bordeaux
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0);
    } catch (e) {
      print('Erreur de localisation: $e');
      return null;
    }
  }

  Future<String?> getCountryFromCoordinates(Position position) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Parcourir les résultats pour trouver le pays
          for (var component in data['results'][0]['address_components']) {
            if (component['types'].contains('country')) {
              return component['long_name']; // Nom complet du pays
            }
          }
        }
      } else {
        print("Erreur API: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erreur lors de la récupération du pays : $e");
    }

    return null; // Retourne null si le pays n'a pas pu être récupéré
  }

  Future<Map<String, double>> _getCoordinatesFromAddress(String address, String postalCode) async {
    // Combinez l'adresse et le code postal
    final fullAddress = "$address, $postalCode";

    // Construisez l'URL avec l'adresse complète
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(fullAddress)}&key=$googleApiKey');

    print("Requête envoyée à l'API Google: $url");

    try {
      // Envoyez la requête GET
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Vérifiez que les résultats contiennent des données de géolocalisation
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          final location = jsonResponse['results'][0]['geometry']['location'];
          return {
            'latitude': location['lat'],
            'longitude': location['lng'],
          };
        } else {
          print("Adresse introuvable ou réponse vide: $fullAddress");
        }
      } else {
        print("Erreur API: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erreur lors de l'appel de l'API Geocoding: $e");
    }

    // Retourne des valeurs par défaut en cas d'échec
    return {'latitude': 0.0, 'longitude': 0.0};
  }

  Future<void> loadData(Position userPosition) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // todo enelver : country = prefs.getString('currentUser_country');
    country = "France";
    currentUser_role = prefs.getInt('currentUser_role') ?? 0;

    List<Restaurant> restaurantsList = await Restaurant.fetchRestaurantsFromDB();

    List filteredRestaurants = [];

    for (var restaurant in restaurantsList) {
      final adress = "${restaurant.adress}, ${country}";
      final postalCode = "33800"; //todo enlever cette ligne
      //final postalCode = restaurant.postalCode; // Supposons que le modèle Restaurant inclut un code postal

      print("userPosition.latitude " + userPosition.latitude.toString());
      print("userPosition.longitude " + userPosition.longitude.toString());
      String? userCountry = await getCountryFromCoordinates(userPosition);
      print("Pays de l'utilisateur : $userCountry");

      try {
        final coordinates = await _getCoordinatesFromAddress(adress, postalCode);
        final distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          coordinates['latitude']!,
          coordinates['longitude']!,
        );

        print("distance " + distance.toString());

        if (distance <= 3000) {
          filteredRestaurants.add({
            'restaurantID': restaurant.restaurantID ,
            'image': restaurant.image ?? 'assets/images/default.png', // Image par défaut
            'name': restaurant.name ?? 'Nom indisponible',       // Nom par défaut
            //'currency': restaurant.currency ?? '€',                  // Devise par défaut
            'distance': distance,
          });
          filteredRestaurants.add({
            'name': restaurant.name ?? 'Nom indisponible',       // Nom par défaut
            //'currency': restaurant.currency ?? '€',                  // Devise par défaut
            'distance': distance,
          });
        }
      } catch (e) {
        print("Erreur lors du calcul de la distance : $e");
      }

    }

    setState(() {
      _nearbyRestaurants = filteredRestaurants;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restaurants à proximité'),
      ),
      body: _nearbyRestaurants.isEmpty
          ? Center(
        child: Text(
          'Aucun restaurant à proximité trouvé.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ) // Message si aucun restaurant
          : ListView.builder(
        itemCount: _nearbyRestaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _nearbyRestaurants[index];
          return Card(
            child: Column(
              children: [
                buildImage(restaurant["image"]),
                ListTile(
                  title: Text(
                    restaurant["name"] ?? "Nom indisponible",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                  ),
                  subtitle: Text(
                    "Situé à ${(restaurant["distance"] ?? 0.0).toStringAsFixed(2)} m",
                    style: TextStyle(color: Colors.red.withOpacity(0.6)),
                  ),
                  trailing: Icon(Icons.chevron_right), // Chevron droit
                  onTap: () {
                    print("restaurant " + restaurant.toString());
                    print("restaurant.restaurantID " + restaurant["restaurantID"].toString()); // Utilisation de ["restaurantID"]

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantDetails(
                          restaurant_id: restaurant["restaurantID"],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ), // Liste des restaurants si disponible
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
