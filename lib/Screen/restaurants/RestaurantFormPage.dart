import 'dart:io';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../Constant/Constant.dart';
import '../../providers/users_provider.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../AnimatedSplashScreen.dart';
import '../verif_confirm/ConfirmationPage.dart';

class RestaurantFormPage extends ConsumerStatefulWidget {
  @override
  _RestaurantFormPageState createState() => _RestaurantFormPageState();
}

class _RestaurantFormPageState extends ConsumerState<RestaurantFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
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

    String username = 'blandinedupont087@gmail.com'; // Remplacez par votre adresse Gmail
    String password = 'dtmd pleh ufau vjqd'; // Remplacez par votre mot de passe sécurisé

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address('blandinedupont087@gmail.com', 'Dios Délices')
      ..recipients.add('blandinedupont087@gmail.com') // Envoyer à l'admin
      ..subject = 'Nouvelle demande de Micro Restaurant'
      ..text = 'Nom du restaurant: $name\nAdresse: $address\nTéléphone: $phone';

    try {
      await send(message, smtpServer);
      print('Email envoyé avec succès');
    } on MailerException catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
    }

  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
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
                        _selectedHashtags = hashtags; // Mettre à jour les hashtags sélectionnés
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
                          final isAddressValid = await _isValidAddress(
                              _addressController.text);

                          if (!isAddressValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                Text("L'adresse saisie est invalide."),
                              ),
                            );
                            return;
                          }

                          final user = ref.read(usersProvider);
                          if (user != null) {
                            ParseFile? parseFile;
                            final _image = this._image;

                            if (_image != null) {
                              String fileName = p.basename(_image.path); // Get the file name
                              String extension = p.extension(fileName);  // Get the file extension (.jpg, .png)

                              // Check if name and user ID are not empty
                              if (_nameController.text.isNotEmpty && user.userID != null) {
                                String nom_image = _nameController.text + "_" + user.userID.toString();  // New image name
                                String newFileName = "$nom_image$extension";  // Combine name and extension

                                // Create the ParseFile with the new name
                                parseFile = ParseFile(File(_image.path), name: newFileName);
                                print("parseFile created: " + parseFile.toString());
                              } else {
                                print("Erreur : nom ou ID utilisateur manquant");
                                return;
                              }
                            }

                            // Now call the method to manage the restaurant
                            String createResult = await Restaurant.manageRestaurant(
                              userID: user.userID,
                              valid: 0,
                              nb_orders: 0,
                              note: 0.0,
                              categories: _selectedHashtags.join(', '),
                              description: _descriptionController.text,
                              adress: _addressController.text,
                              name: _nameController.text,
                              image: parseFile, // Pass the ParseFile here
                            );

                            if (createResult == "success") {
                              await _sendEmailToAdmin(
                                _nameController.text,
                                _addressController.text,
                                user.telephone.toString(),
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
