import 'dart:convert';
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
      return await _determinePosition();
    } catch (e) {
      print('Erreur de localisation: $e');
      return null;
    }
  }

  Future<Map<String, double>> _getCoordinatesFromAddress(String address) async {
    // Construisez l'URL pour la requête API
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleApiKey');

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
          print("Adresse introuvable ou réponse vide: $address");
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
      final coordinates = await _getCoordinatesFromAddress(adress);

      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        coordinates['latitude']!,
        coordinates['longitude']!,
      );

      if (distance <= 3000) { // Filtrer les restaurants dans un rayon de 3 km
        filteredRestaurants.add({
          'name': restaurant.name,
          //'meal_name': restaurant.meal_name,
          //'price': restaurant.price,
          //'currency': restaurant.currency,
          'image': restaurant.image,
          'distance': distance,
        });
      }
    }

    setState(() {
      _nearbyRestaurants = filteredRestaurants;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView.builder(
        itemCount: _nearbyRestaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _nearbyRestaurants[index];
          return Card(
            child: Column(
              children: [
                Image.asset(
                  restaurant["image"],
                  height: 200,
                  width: 300,
                  fit: BoxFit.fitWidth,
                ),
                ListTile(
                  title: Text(restaurant["meal_name"]),
                  subtitle: Text(
                    "${restaurant["price"]} ${restaurant["currency"]} - ${restaurant["distance"].toStringAsFixed(2)} m",
                    style: TextStyle(color: Colors.red.withOpacity(0.6)),
                  ),
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
