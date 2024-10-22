import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../modeles/users.dart';
import '../providers/users_provider.dart';
import 'AnimatedSplashScreen.dart';
import 'CurvedNavigation.dart';
import 'Login.dart';
import 'StatusSelectionPage.dart';

class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {

  String _currentCountry = "En cours de localisation...";
  bool _isLoading = true;

  // Liste des pays avec leurs drapeaux
  List<Map<String, String>> _countries = [
    {"name": "France", "flag": "🇫🇷"},
    {"name": "Bénin", "flag": "🇧🇯"},
    {"name": "Côte d'Ivoire", "flag": "🇨🇮"},
    {"name": "États-Unis", "flag": "🇺🇸"} // Ajout des États-Unis
  ];

  String? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Fonction pour déterminer la position actuelle de l'utilisateur
  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Obtenir le nom du pays à partir de la position
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String detectedCountry = placemarks[0].country ?? "Pays inconnu";

      // Vérifier si le pays détecté est dans la liste des pays autorisés
      bool isCountryAllowed = _countries.any((country) => country["name"] == detectedCountry);

      setState(() {
        _currentCountry = detectedCountry;
        _selectedCountry = isCountryAllowed ? _currentCountry : null;
        _isLoading = false;
      });

      if (!isCountryAllowed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CountryNotAvailablePage()), // Page de pays non disponible
        );
      }
    } else {
      setState(() {
        _currentCountry = "Permission refusée";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Votre pays : $_currentCountry",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: _selectedCountry,
              hint: Text("Sélectionnez un pays"),
              items: _countries.map((Map<String, String> country) {
                return DropdownMenuItem<String>(
                  value: country["name"],
                  child: Row(
                    children: [
                      Text(country["flag"] ?? ""),
                      SizedBox(width: 10),
                      Text(country["name"] ?? ""),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCountry = newValue!;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Couleur de fond du bouton
                foregroundColor: Colors.white, //Couleur du texte
                textStyle: TextStyle(
                  fontSize: 18, // Taille du texte
                  fontWeight: FontWeight.bold, // (Optionnel) Style de texte en gras
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), // Bordure du bouton
                ),
              ),
              onPressed: () async {
                if (_selectedCountry != null) {
                  // en France l'utilisateur ne peut être que particulier
                  //todo : decommenter
                  /*if(_selectedCountry == "France" || _selectedCountry == "États-Unis"){
                    final user = ref.read(usersProvider);
                    if (user != null) {
                      await Users.updateCountryAndRole(user.userID, _selectedCountry!, 2);
                      await  Users.updateDerniereConnexion(user.userID);
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (ctx) => CurvedNavigation(specified_index: 0)),
                      );
                    }
                  } else {
                    // Rediriger vers la page de sélection du statut
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatusSelectionPage(country: _selectedCountry!),
                      ),
                    );
                  }*/
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatusSelectionPage(country: _selectedCountry!),
                    ),
                  );
                }
              },
              child: const Text('Continuer'),
            )
          ],
        ),
      ),
    );
  }
}

// Page de pays non disponible
class CountryNotAvailablePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Indisponible")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 100),
            SizedBox(height: 20),
            Text(
              "Cette application n'est pas encore disponible dans votre pays.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Couleur de fond du bouton
                foregroundColor: Colors.white, //Couleur du texte
                textStyle: TextStyle(
                  fontSize: 18, // Taille du texte
                  fontWeight: FontWeight.bold, // (Optionnel) Style de texte en gras
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), // Bordure du bouton
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Efface toutes les préférences

                // Réinitialise les fournisseurs
                // widget.ref.invalidate(usersProvider); // Invalide le fournisseur

                await DatabaseHelper.cleanUpDatabase(true); // Nettoie la base de données

                // Retour à l'écran de démarrage
                Navigator.pushAndRemoveUntil(
                  context,
                  CupertinoPageRoute(
                      builder: (ctx) =>
                      const AnimatedSplashScreen()),
                      (Route<dynamic> route) => false, // Supprime toutes les routes
                );
              },
              child: const Text('Quitter'),
            ),
          ],
        ),
      ),
    );
  }
}
