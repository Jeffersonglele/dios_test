import 'dart:io';
import 'package:dios_delices/modeles/dish.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constant/Constant.dart';
import '../../providers/users_provider.dart';
import '../../utils/DeviseFormat.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/ThousandSeparatorInputFormatter.dart';
import '../../utils/toast.dart';

class DishFormPage extends ConsumerStatefulWidget {
  @override
  _DishFormPageState createState() => _DishFormPageState();
}

class _DishFormPageState extends ConsumerState<DishFormPage> {
  String country = "";
  int currentUser_restau = 0;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedHashtags = [];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _nbServingsController = TextEditingController();
  final TextEditingController _restauIDController = TextEditingController();

  List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  File? _image;

  void _removeOption(int index) {
    setState(() {
      // Supprime le contenu à l'index donné
      _optionControllers[index].clear();

      // Décale les options suivantes
      for (int i = index; i < 2; i++) {
        _optionControllers[i].text = _optionControllers[i + 1].text;
      }

      // Vide la dernière option
      _optionControllers[2].clear();
    });
  }


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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _nbServingsController.dispose();
    _restauIDController.dispose();
    super.dispose();
  }

  void clearFields() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _nbServingsController.clear();
    _restauIDController.clear();
  }

  Future<void> _initializeData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    country = prefs.getString('currentUser_country')!;
    currentUser_restau = prefs.getInt('currentUser_restau')!;
    print("country " + country);
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.01),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      'Votre plat',
                      style: kLoginTitleStyle(size),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Champ pour le nom du dish
                  _buildTextField(
                    controller: _nameController,
                    hintText: "Nom du plat",
                    icon: Icons.restaurant,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Entrez le nom de votre plat';
                      } else if (value.length < 4) {
                        return 'Au moins 4 caractères';
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
                  // Champ pour le nombre de portions
                  _buildTextField(
                    controller: _nbServingsController,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                      // Limite la saisie à 3 chiffres
                      ThousandSeparatorInputFormatter(),
                    ],
                    hintText: "Nombre de portions",
                    icon: Icons.fastfood,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Un nombre de portions est requis. Vous pourrez le modifier';
                      } else if (int.tryParse(value.replaceAll(' ', '')) ==
                          null) {
                        return 'Entrez un nombre valide';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Champ pour le prix
                  country == "France"
                      ? _buildTextField(
                          controller: _priceController,
                          hintText: "Prix du plat (en euro €)",
                          icon: Icons.money,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d{0,2}(,\d{0,2})?')),
                            // Autorise 2 chiffres pour la partie entière et 2 pour la décimale
                            LengthLimitingTextInputFormatter(5),
                            // Limite la saisie à 3 chiffres
                            FrenchFormat(decimalRange: 2)
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Entrez un prix';
                            } else if (double.tryParse(value
                                    .replaceAll(' ', '')
                                    .replaceAll(',', '.')) ==
                                null) {
                              return 'Entrez un prix valide';
                            }
                            return null;
                          },
                        )
                      : _buildTextField(
                          controller: _priceController,
                          hintText: "Prix du plat",
                          icon: Icons.money,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            // Autorise 2 chiffres pour la partie entière et 2 pour la décimale
                            LengthLimitingTextInputFormatter(5),
                            // Limite la saisie à 3 chiffres
                            CFAFormat(),
                            // Utilise le format CFA,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Entrez un prix';
                            } else if (double.tryParse(value
                                    .replaceAll(' ', '')
                                    .replaceAll(',', '.')) ==
                                null) {
                              return 'Entrez un prix valide';
                            }
                            return null;
                          },
                        ),
                  SizedBox(height: size.height * 0.02),
                  // Champ pour la description
                  _buildTextField(
                    controller: _descriptionController,
                    hintText:
                        "Description du plat (donnez-nous quelques informations)",
                    keyboardType: TextInputType.multiline,
                    icon: Icons.info,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Entrez une description';
                      }
                      return null;
                    },
                    maxLines: null,
                  ),
                  SizedBox(height: size.height * 0.02),
                  ElevatedButton(
                    onPressed: () {
                      int firstEmptyIndex = _optionControllers.indexWhere((c) => c.text.isEmpty);
                      if (firstEmptyIndex == -1) {
                        Toast(context, "Vous ne pouvez ajouter que 3 options", false);
                      } else {
                        _showOptionDialog(optionIndex: firstEmptyIndex);
                      }
                    },
                    child: Text("+ Ajouter une option"),
                  ),
                  SizedBox(height: size.height * 0.02),
                  Column(
                    children: List.generate(3, (index) {
                      if (_optionControllers[index].text.isEmpty) return SizedBox();

                      // EXTRACT DISPLAYABLE DATA
                      String displayText = _optionControllers[index].text;
                      try {
                        List<String> parts = displayText.split(':');
                        String nom = parts[0].trim();
                        List<String> choixList = parts.length > 1 ? parts[1].split('/').map((e) => e.trim()).toList() : [];
                        String? prix = choixList.length > 3 ? choixList.last : null;
                        List<String> choix = choixList.length > 3 ? choixList.sublist(0, choixList.length - 1) : choixList;

                        displayText = "$nom: ${choix.join(' / ')}";
                        if (prix != null && prix.isNotEmpty) {
                          displayText += " / $prix ${country == "France" ? "€" : "FCFA"}";
                        }
                      } catch (_) {
                        // fallback, laisse tel quel
                      }

                      return ListTile(
                        title: Text(displayText),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _showOptionDialog(optionIndex: index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _removeOption(index),
                            ),
                          ],
                        ),
                      );
                    }),
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

                            String createResult = await Dish.manageDish(
                              userID: user.userID,
                              nb_orders: 0,
                              note: 0.0,
                              categories: _selectedHashtags.join(', '),
                              description: _descriptionController.text,
                              option1: _optionControllers[0].text,
                              option2: _optionControllers[1].text,
                              option3: _optionControllers[2].text,
                              name: _nameController.text,
                              price: double.tryParse(_priceController.text) ?? 0.0,
                              nb_servings: int.tryParse(_nbServingsController.text) ?? 0,
                              restauID: currentUser_restau,
                              status: 1,
                              image: parseFile,
                            );

                            Toast(
                                context,
                                createResult == "success"
                                    ? "Plat ajouté avec succès"
                                    : "Erreur : $createResult",
                                createResult == "success"
                                    ? true
                                    : false);

                            if (createResult == "success") {
                              clearFields();
                              Navigator.of(context).pop();
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

  void _showOptionDialog({required int optionIndex}) {
    final existing = _optionControllers[optionIndex].text;

    List<String> parts = existing.split(": ");
    String nomInitial = parts.length > 1 ? parts[0] : "";
    List<String> choixParts = parts.length > 1 ? parts[1].split("/") : ["", "", "", ""];

    TextEditingController nomController = TextEditingController(text: nomInitial);
    TextEditingController choix1Controller = TextEditingController(text: choixParts.isNotEmpty ? choixParts[0].trim() : "");
    TextEditingController choix2Controller = TextEditingController(text: choixParts.length > 1 ? choixParts[1].trim() : "");
    TextEditingController choix3Controller = TextEditingController(text: choixParts.length > 2 ? choixParts[2].trim() : "");
    TextEditingController prixController = TextEditingController(text: choixParts.length > 3 ? choixParts[3].trim() : "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Option ${optionIndex + 1}"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: "Nom de l'option"),
              ),
              TextField(
                controller: choix1Controller,
                decoration: InputDecoration(labelText: "Choix 1"),
              ),
              TextField(
                controller: choix2Controller,
                decoration: InputDecoration(labelText: "Choix 2"),
              ),
              TextField(
                controller: choix3Controller,
                decoration: InputDecoration(labelText: "Choix 3"),
              ),
              TextField(
                controller: prixController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(,\d{0,2})?$')),
                  LengthLimitingTextInputFormatter(6), // Par exemple : "999,99"
                ],
                decoration: InputDecoration(labelText: "Prix de l'option (format 00,00)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Valider"),
            onPressed: () {
              String nom = nomController.text.trim();
              String c1 = choix1Controller.text.trim();
              String c2 = choix2Controller.text.trim();
              String c3 = choix3Controller.text.trim();
              String prix = prixController.text.trim();

              if (nom.isEmpty || c1.isEmpty || prix.isEmpty) {
                Toast(context, "Nom, choix 1 et prix sont obligatoires", false);
                return;
              }

              String result = "$nom: $c1 / $c2 / $c3 / $prix";

              setState(() {
                _optionControllers[optionIndex].text = result;
              });

              Navigator.pop(context);
            },
          ),
        ],
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
