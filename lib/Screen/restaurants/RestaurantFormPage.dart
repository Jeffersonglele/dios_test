import 'dart:io';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/address.dart' as address_model;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../Constant/Constant.dart';
import '../../providers/users_provider.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/phone_number.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../AnimatedSplashScreen.dart';
import '../verif_confirm/ConfirmationPage.dart';

class RestaurantFormPage extends ConsumerStatefulWidget {
  const RestaurantFormPage({super.key});

  @override
  _RestaurantFormPageState createState() => _RestaurantFormPageState();
}

class _RestaurantFormPageState extends ConsumerState<RestaurantFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _openingHoursController =
      TextEditingController(text: '09:00 - 20:00');
  final TextEditingController _deliveryFeeController =
      TextEditingController(text: '0');
  List<String> _selectedHashtags = [];

  File? _image;

  // Méthode pour ouvrir l'image picker
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();

    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Galerie'),
                    onTap: () async {
                      final XFile? image =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          _image = File(image.path);
                        });
                      }
                      Navigator.of(context).pop();
                    }),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Caméra'),
                  onTap: () async {
                    final XFile? image =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() {
                        _image = File(image.path);
                      });
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  // Fonction pour envoyer un email à l'admin avec les infos du restaurant
  Future<void> _sendEmailToAdmin(
      String name, String address, String phone) async {
    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': 'blandinedupont087@gmail.com',
        'subject': 'Nouvelle demande de Restaurant',
        'text': 'Nom du restaurant: $name\nAdresse: $address\nTéléphone: $phone',
      });
      print('Email envoyé avec succès');
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _openingHoursController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  // Méthode pour valider si l'adresse est réelle en utilisant Geocoding
  Future<bool> _isValidAddress(String value) async {
    try {
      List<geo.Location> locations = await geo.locationFromAddress(value);
      return locations.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
            leading: IconButton(
          icon: Icon(Icons.home), // Icône personnalisée (ex: home)
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => AnimatedSplashScreen()),
              (Route<dynamic> route) => false,
            );
          },
        )),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.1),
                  size.width > 600
                      ? Container()
                      : const Center(child: BrandAvatarLogo()),
                  SizedBox(height: size.height * 0.03),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      'Votre restaurant',
                      style: kLoginTitleStyle(size),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Champ pour le nom du restaurant
                  _buildTextField(
                    controller: _nameController,
                    hintText: "Nom du restaurant",
                    icon: Icons.restaurant,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the name of your restaurant';
                      } else if (value.length < 4) {
                        return 'At least enter 4 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Champ pour l'adresse
                  _buildTextField(
                    controller: _addressController,
                    hintText: "Adresse du restaurant (ou la vôtre)",
                    icon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an address';
                      } else if (value.length < 4) {
                        return 'At least enter 4 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  HashtagTextInputFormatter(
                    onHashtagsChanged: (hashtags) {
                      setState(() {
                        _selectedHashtags =
                            hashtags; // Mettre à jour les hashtags sélectionnés
                      });
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Champ pour la description
                  _buildTextField(
                    controller: _descriptionController,
                    hintText:
                        "Description du restaurant (donnez-nous quelques informations)",
                    keyboardType: TextInputType.multiline,
                    icon: Icons.info,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      } else if (value.length < 30) {
                        return 'At least enter 30 characters';
                      }
                      return null;
                    },
                    maxLines: null,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _openingHoursController,
                    hintText: "Horaires d'ouverture (ex: 09:00 - 20:00)",
                    icon: Icons.access_time,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Entrez les horaires d'ouverture";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildTextField(
                    controller: _deliveryFeeController,
                    hintText: "Frais de livraison",
                    icon: Icons.delivery_dining,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+[.,]?\d{0,2}$')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Entrez les frais de livraison';
                      }
                      final normalized = value.replaceAll(',', '.');
                      if (double.tryParse(normalized) == null) {
                        return 'Entrez un montant valide';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Sélection de l'image
                  Center(
                    child: Column(
                      children: <Widget>[
                        _image == null
                            ? const Text(
                                'Aucune image sélectionnée',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              )
                            : Image.file(_image!, width: 100, height: 60),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _pickImage,
                          child: const Text(
                            'Sélectionner une image',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Bouton de validation
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
                        if (_formKey.currentState!.validate()) {
                          final isAddressValid =
                              await _isValidAddress(_addressController.text);

                          if (!isAddressValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("L'adresse saisie est invalide."),
                              ),
                            );
                            return;
                          }

                          final user = ref.read(usersProvider);
                          if (user != null) {
                            ParseFile? parseFile;
                            final _image = this._image;

                            if (_image != null) {
                              String fileName =
                                  p.basename(_image.path); // Get the file name
                              String extension = p.extension(
                                  fileName); // Get the file extension (.jpg, .png)

                              // Check if name and user ID are not empty
                              if (_nameController.text.isNotEmpty &&
                                  user.userID != null) {
                                String nom_image = _nameController.text +
                                    "_" +
                                    user.userID.toString(); // New image name
                                String newFileName =
                                    "$nom_image$extension"; // Combine name and extension

                                // Create the ParseFile with the new name
                                parseFile = ParseFile(File(_image.path),
                                    name: newFileName);
                                print("parseFile created: " +
                                    parseFile.toString());
                              } else {
                                print(
                                    "Erreur : nom ou ID utilisateur manquant");
                                return;
                              }
                            }

                            // Créer l'adresse via le modèle Address avant le restaurant
                            int? addressID;
                            final addressText = _addressController.text.trim();
                            if (addressText.isNotEmpty) {
                              try {
                                List<geo.Location> locations =
                                    await geo.locationFromAddress(addressText);
                                double lat =
                                    locations.isNotEmpty ? locations.first.latitude : 0.0;
                                double lng =
                                    locations.isNotEmpty ? locations.first.longitude : 0.0;

                                dynamic addrResult =
                                    await address_model.Address.manageAddress(
                                  city: "",
                                  state: user.country,
                                  fullAddress: addressText,
                                  numero: 0,
                                  lat: lat.toString(),
                                  long: lng.toString(),
                                  object: "Restaurant",
                                  objectID: user.userID,
                                  user_roleID: user.roleID,
                                );

                                if (addrResult is int) {
                                  addressID = addrResult;
                                }
                              } catch (e) {
                                print("Erreur geocoding adresse restaurant: $e");
                              }
                            }

                            // Now call the method to manage the restaurant
                            String createResult =
                                await Restaurant.manageRestaurant(
                              userID: user.userID,
                              valid: 0,
                              nb_orders: 0,
                              note: 0.0,
                              categories: _selectedHashtags.join(', '),
                              description: _descriptionController.text,
                              location: _addressController.text,
                              name: _nameController.text,
                              openingHours: _openingHoursController.text.trim(),
                              deliveryFee: double.parse(
                                _deliveryFeeController.text
                                    .replaceAll(',', '.'),
                              ),
                              isOpen: 1,
                              addressID: addressID,
                              image: parseFile, // Pass the ParseFile here
                            );

                            if (createResult == "success") {
                              await _sendEmailToAdmin(
                                _nameController.text,
                                _addressController.text,
                                formatPhoneForCountry(
                                  phone: user.telephone,
                                  country: user.country,
                                ),
                              );

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ConfirmationPage(),
                                ),
                              );
                            } else {
                              print("Error: $createResult");
                            }
                          }
                        }
                      },
                      child: const Text('Valider'),
                    ),
                  ),
                  SizedBox(height: size.height * 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
    );
  }
}
