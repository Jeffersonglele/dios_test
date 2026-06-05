import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modeles/address.dart';
import '../providers/address_provider.dart';
import '../widgets/brand_avatar_logo.dart';
import '../../Constant/Constant.dart';
import 'verif_confirm/StatusSelectionPage.dart';

class LocationPage extends ConsumerStatefulWidget {
  final int objectID;
  final int user_roleID;

  LocationPage({required this.objectID, required this.user_roleID});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  Position? position;
  String? completeAddress;
  bool showManualEntry = false;
  bool addressExists = false;

  TextEditingController locationController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController fullAddressController = TextEditingController();

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      position = newPosition;
    });

    List<Placemark> placeMarks =
        await placemarkFromCoordinates(position!.latitude, position!.longitude);
    Placemark pMarks = placeMarks[0];

    completeAddress =
        '${pMarks.thoroughfare}, ${pMarks.locality}, ${pMarks.administrativeArea}, ${pMarks.country}';
    setState(() {
      locationController.text = completeAddress!;
    });
  }

  void saveAddress() async {
    final newAddress = Address(
      city: cityController.text,
      state: stateController.text,
      fullAddress: fullAddressController.text,
      lat: position != null ? position!.latitude.toString() : null,
      long: position != null ? position!.longitude.toString() : null,
      objectID: null,
    );

    // 🔹 Enregistrer via Riverpod Provider
    await ref.read(addressProvider.notifier).addAddress(newAddress);

    Toast(context, "Adresse enregistrée avec succès !", true);

    setState(() {
      showManualEntry = false;
    });
  }

  void saveDetectedAddress() async {

    // Vérification pour éviter une erreur de type
    String city =
        (position != null && locationController.text.split(', ').length > 1)
            ? locationController.text.split(', ')[1]
            : "";

    String state =
        (position != null && locationController.text.split(', ').length > 2)
            ? locationController.text.split(', ')[3]
            : "";


    String fullAddress =
        locationController.text.isNotEmpty ? locationController.text : "";

    String? lat = position?.latitude.toString();
    String? long = position?.longitude.toString();

    // c'est l'adresse d'un user
    dynamic validationResult = await Address.manageAddress(
      city: city,
      state: state,
      fullAddress: fullAddress,
      lat: lat ?? "",
      object: "User",
      objectID: widget.objectID,
      long: long ?? "",
      user_roleID: widget.user_roleID,
    );


    if (validationResult == "EXISTING_ADDRESS") {
      setState(() {
        addressExists = true; // ✅ Affiche "Poursuivre >"
      });
      Toast(context, "Adresse déjà enregistrée.", true);
      return;
    }

    if (validationResult is int) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('userVerified', true);

      Toast(context, "Adresse enregistrée avec succès !", true);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StatusSelectionPage(
              country: state,
              objectID: widget.objectID,
              user_roleID: widget.user_roleID),
        ),
      );
    } else {
      Toast(context, validationResult, false);
    }
  }

  void saveManualAddress() async {

    String city = cityController.text;
    String state = stateController.text;
    String fullAddress = fullAddressController.text;

    if (city.isEmpty || state.isEmpty || fullAddress.isEmpty) {
      Toast(context, "Veuillez remplir tous les champs d'adresse.", false);
      return;
    }

    try {
      // 🔹 Convertir l'adresse en coordonnées GPS
      List<Location> locations =
          await locationFromAddress("$fullAddress, $city, $state");
      if (locations.isEmpty) {
        Toast(context, "Adresse introuvable. Veuillez vérifier l'exactitude.",
            false);
        return;
      }

      double lat = locations.first.latitude;
      double long = locations.first.longitude;


      // 📌 Envoyer l'adresse avec les coordonnées GPS
      dynamic validationResult = await Address.manageAddress(
        city: city,
        state: state,
        fullAddress: fullAddress,
        lat: lat.toString(),
        object: "User",
        objectID: widget.objectID,
        long: long.toString(),
        user_roleID: widget.user_roleID,
      );

      if (validationResult == "EXISTING_ADDRESS") {
        setState(() {
          addressExists = true;
        });
        Toast(context, "Adresse déjà enregistrée.", true);
        return;
      }

      if (validationResult is int) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);

        Toast(context, "Adresse enregistrée avec succès !", true);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StatusSelectionPage(
                country: state,
                objectID: widget.objectID,
                user_roleID: widget.user_roleID),
          ),
        );
      } else {
        Toast(context, validationResult, false);
      }
    } catch (e) {
      Toast(context,
          "Impossible de trouver l'adresse, vérifiez les informations.", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: size.width > 600
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.1),
                size.width > 600
                    ? Container()
                    : const Center(child: BrandAvatarLogo()),
                SizedBox(height: size.height * 0.03),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    'Mon adresse',
                    style: kLoginTitleStyle(size),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Please enter your email adress :",
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: getCurrentLocation,
                        icon:
                            const Icon(Icons.location_on, color: Colors.white),
                        label: const Text('Obtenir ma localisation',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                      ),
                      SizedBox(height: 20),
                      TextField(
                          controller: locationController,
                          readOnly: true,
                          decoration: InputDecoration(
                              labelText: "Adresse détectée",
                              border: OutlineInputBorder())),
                      SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () =>
                            setState(() => showManualEntry = !showManualEntry),
                        child: Text(
                            showManualEntry
                                ? "Masquer le formulaire"
                                : "Entrer mon adresse manuellement",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 15),
                      if (showManualEntry)
                        Column(
                          children: [
                            TextField(
                                controller: cityController,
                                decoration: InputDecoration(
                                    labelText: "Ville",
                                    border: OutlineInputBorder())),
                            SizedBox(height: 15),
                            TextField(
                                controller: stateController,
                                decoration: InputDecoration(
                                    labelText: "État/Région",
                                    border: OutlineInputBorder())),
                            SizedBox(height: 15),
                            TextField(
                                controller: fullAddressController,
                                decoration: InputDecoration(
                                    labelText: "Adresse complète",
                                    border: OutlineInputBorder())),
                            SizedBox(height: 20),

                            /*ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: saveAddress,
                              child: Text("Enregistrer l'adresse", style: TextStyle(color: Colors.white)),
                            )*/
                          ],
                        ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          if (locationController.text.isNotEmpty) {
                            // Si l'adresse est détectée automatiquement
                            saveDetectedAddress();
                          } else if (fullAddressController.text.isNotEmpty) {
                            // Si l'adresse est entrée manuellement
                            saveManualAddress();
                          } else {
                            Toast(
                                context,
                                "Veuillez entrer ou détecter une adresse avant d'enregistrer.",
                                false);
                          }
                        },
                        child: Text("Enregistrer l'adresse",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 20),
                      if (addressExists)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StatusSelectionPage(
                                    country: stateController.text,
                                    objectID: widget.objectID,
                                    user_roleID: widget.user_roleID),
                              ),
                            );
                          },
                          child: Text("Poursuivre >",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
