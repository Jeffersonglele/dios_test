import 'dart:io';
import 'package:dios_delices/modeles/dish.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../Constant/Constant.dart';
import '../../providers/users_provider.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/DeviseFormat.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/toast.dart';

class DishFormPage extends ConsumerStatefulWidget {
  const DishFormPage({super.key});

  @override
  _DishFormPageState createState() => _DishFormPageState();
}

class _DishFormPageState extends ConsumerState<DishFormPage> {
  String country = "";
  int currentUser_restau = 0;
  bool isLoading = false;
  bool _isMounted = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedHashtags = [];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _nbServingsController = TextEditingController();

  // Structure améliorée pour les options
  List<DishOption> _options = [];

  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _initializeData();
  }

  @override
  void dispose() {
    _isMounted = false;
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _nbServingsController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback callback) {
    if (_isMounted && mounted) {
      setState(callback);
    }
  }

  double _parsePrice(String value) {
    if (value.trim().isEmpty) return 0.0;
    // Supprimer les espaces
    String cleaned = value.replaceAll(' ', '');
    // Remplacer la virgule par un point
    cleaned = cleaned.replaceAll(',', '.');
    // S'assurer qu'il n'y a qu'un seul point
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = parts[0] + '.' + parts.sublist(1).join('');
    }
    double result = double.tryParse(cleaned) ?? 0.0;
    // Arrondir à 2 décimales
    return double.parse(result.toStringAsFixed(2));
  }

  // Nettoie le nombre de portions
  int _parseServings(String value) {
    if (value.trim().isEmpty) return 0;
    return int.tryParse(value.replaceAll(' ', '')) ?? 0;
  }

  void _removeOption(int index) {
    _updateState(() {
      _options.removeAt(index);
    });
  }

  void _editOption(int index) {
    _showOptionDialog(optionToEdit: _options[index], optionIndex: index);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () async {
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null && mounted) {
                    _updateState(() => _selectedImage = File(image.path));
                  }
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Caméra'),
                onTap: () async {
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.camera);
                  if (image != null && mounted) {
                    _updateState(() => _selectedImage = File(image.path));
                  }
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _initializeData() async {
    try {
      final session = await SessionService.readSession();
      _updateState(() {
        country = session.country;
        currentUser_restau = session.restaurantId ?? 0;
      });
    } catch (e) {
      debugPrint("Erreur d'initialisation: $e");
    }
  }

  void _clearFields() {
    _updateState(() {
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _nbServingsController.clear();
      _selectedHashtags = [];
      _options = [];
      _selectedImage = null;
    });
  }

  Future<void> _submitForm() async {
    // Vérification restaurant
    if (currentUser_restau <= 0) {
      Toast(
          context,
          "Restaurant non configuré. Veuillez d'abord configurer votre restaurant.",
          false);
      return;
    }

    // Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      Toast(context, "Veuillez remplir tous les champs obligatoires", false);
      return;
    }

    // Récupération de l'utilisateur depuis la session (solution fiable)
    final session = await SessionService.readSession();

    if (session.userId == null) {
      Toast(context, "Utilisateur non connecté. Veuillez vous reconnecter.",
          false);
      return;
    }

    final userId = session.userId!;

    _updateState(() => isLoading = true);

    try {
      // Formatage des options
      String option1 = "";
      String option2 = "";
      String option3 = "";

      for (int i = 0; i < _options.length && i < 3; i++) {
        final opt = _options[i];
        String choices = opt.choices.join(" / ");
        String optionText = "${opt.name}: $choices";
        if (opt.price > 0) {
          optionText += " / ${opt.price.toStringAsFixed(2)} €";
        }
        if (i == 0) {
          option1 = optionText;
        } else if (i == 1) {
          option2 = optionText;
        } else if (i == 2) {
          option3 = optionText;
        }
      }

      // Préparation de l'image
      ParseFile? parseFile;
      if (_selectedImage != null) {
        String fileName = p.basename(_selectedImage!.path);
        String extension = p.extension(fileName);
        String newFileName =
            "${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}$extension";
        parseFile = ParseFile(File(_selectedImage!.path), name: newFileName);
      }

      // Appel à la fonction de création
      String result = await Dish.manageDish(
        userID: userId,
        nb_orders: 0,
        note: 0.0,
        categories: _selectedHashtags.join(', '),
        description: _descriptionController.text,
        option1: option1,
        option2: option2,
        option3: option3,
        name: _nameController.text,
        price: _parsePrice(_priceController.text),
        nb_servings: _parseServings(_nbServingsController.text),
        restauID: currentUser_restau,
        status: 1,
        image: parseFile,
      );

      if (!mounted) return;

      if (result == "success") {
        Toast(context, "Plat ajouté avec succès", true);
        _clearFields();
        Navigator.of(context).pop(true);
      } else {
        Toast(context, "Erreur : $result", false);
      }
    } catch (e) {
      debugPrint("Erreur submission: $e");
      if (mounted) {
        Toast(context, "Erreur technique : ${e.toString()}", false);
      }
    } finally {
      if (mounted) _updateState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currency = country == "France" ? "€" : "FCFA";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ajouter un plat'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom du plat
                    _buildTextField(
                      controller: _nameController,
                      hintText: "Nom du plat",
                      icon: Icons.restaurant,
                      validator: (v) => v == null || v.isEmpty
                          ? "Nom requis"
                          : v.length < 4
                              ? "Au moins 4 caractères"
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Hashtags
                    HashtagTextInputFormatter(
                      onHashtagsChanged: (tags) =>
                          _updateState(() => _selectedHashtags = tags),
                    ),
                    const SizedBox(height: 16),

                    // Portions
                    _buildTextField(
                      controller: _nbServingsController,
                      hintText: "Nombre de portions",
                      icon: Icons.fastfood,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3)
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return "Nombre de portions requis";
                        }
                        if (int.tryParse(v.replaceAll(' ', '')) == null) {
                          return "Nombre invalide";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Prix
                    _buildTextField(
                      controller: _priceController,
                      hintText: "Prix du plat ($currency)",
                      icon: Icons.money,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: country == "France"
                          ? [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,2}(,\d{0,2})?')),
                              LengthLimitingTextInputFormatter(5)
                            ]
                          : [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5)
                            ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Prix requis";
                        if (_parsePrice(v) <= 0 && v.trim() != "0") {
                          return "Prix invalide";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      hintText: "Description du plat",
                      icon: Icons.description,
                      maxLines: 3,
                      validator: (v) =>
                          v == null || v.isEmpty ? "Description requise" : null,
                    ),
                    const SizedBox(height: 16),

                    // Bouton ajouter option
                    if (_options.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(children: [
                          Icon(Icons.tune_rounded, size: 36, color: AppColors.inkSubtle),
                          const SizedBox(height: 10),
                          Text('Aucune option', style: AppTypography.bodyMedium(color: AppColors.inkMuted)),
                          const SizedBox(height: 14),
                          SizedBox(width: double.infinity, child: OutlinedButton.icon(
                            onPressed: () { if (_options.length < 3) _showOptionDialog(optionIndex: _options.length); },
                            icon: Icon(Icons.add_rounded, color: AppColors.brand),
                            label: const Text('Ajouter une option'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), side: BorderSide(color: AppColors.brand.withValues(alpha: 0.3))),
                          )),
                        ]),
                      )
                    else ...[
                      ..._options.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final opt = e.value;
                        String display = '${opt.name}: ${opt.choices.join(" / ")}';
                        if (opt.price > 0) display += ' / +${opt.price.toStringAsFixed(2)} ${country == "France" ? "€" : "FCFA"}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10, top: 12),
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.brand.withValues(alpha: 0.15))),
                          child: Row(children: [
                            Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.brandSurface, borderRadius: BorderRadius.circular(6)), child: Center(child: Text('$i', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600, fontSize: 12)))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(display, style: AppTypography.bodyMedium().copyWith(fontSize: 13))),
                            IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.inkMuted), onPressed: () => _editOption(e.key)),
                            IconButton(icon: Icon(Icons.delete_rounded, size: 18, color: AppColors.error), onPressed: () => _removeOption(e.key)),
                          ]),
                        );
                      }),
                      if (_options.length < 3)
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(
                          onPressed: () => _showOptionDialog(optionIndex: _options.length),
                          icon: Icon(Icons.add_rounded, color: AppColors.brand),
                          label: Text('Ajouter une option (${_options.length}/3)'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), side: BorderSide(color: AppColors.brand.withValues(alpha: 0.25))),
                        )),
                    ],
                    const SizedBox(height: 16),

                    // Image
                    _buildImageSection(),
                    const SizedBox(height: 30),

                    // Bouton valider
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text("VALIDER",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Center(
      child: Column(
        children: [
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    width: 120,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 40),
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.image_outlined,
                      size: 40, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  Text("Aucune image",
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text("Choisir une image"),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptionsList() {
    List<Widget> widgets = [];
    for (int i = 0; i < _options.length; i++) {
      final option = _options[i];
      String display = "${option.name}: ${option.choices.join(' / ')}";
      if (option.price > 0) {
        display +=
            " / ${option.price.toStringAsFixed(2)} ${country == "France" ? "€" : "FCFA"}";
      }

      widgets.add(Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(Icons.tune, color: Colors.red, size: 20),
          title: Text(display, style: const TextStyle(fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editOption(i)),
              IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _removeOption(i)),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  void _showOptionDialog({DishOption? optionToEdit, int? optionIndex}) {
    final bool isEditing = optionToEdit != null;
    final int targetIndex = optionIndex ?? (_options.length);

    TextEditingController nomCtrl =
        TextEditingController(text: isEditing ? optionToEdit.name : "");
    TextEditingController c1Ctrl = TextEditingController(
        text: isEditing && optionToEdit.choices.isNotEmpty
            ? optionToEdit.choices[0]
            : "");
    TextEditingController c2Ctrl = TextEditingController(
        text: isEditing && optionToEdit.choices.length > 1
            ? optionToEdit.choices[1]
            : "");
    TextEditingController c3Ctrl = TextEditingController(
        text: isEditing && optionToEdit.choices.length > 2
            ? optionToEdit.choices[2]
            : "");
    TextEditingController prixCtrl = TextEditingController(
        text: isEditing && optionToEdit.price > 0
            ? optionToEdit.price.toString()
            : "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isEditing ? "Modifier l'option" : "Option ${targetIndex + 1}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nomCtrl,
                  decoration:
                      const InputDecoration(labelText: "Nom de l'option")),
              const SizedBox(height: 8),
              TextField(
                  controller: c1Ctrl,
                  decoration: const InputDecoration(
                      labelText: "Choix 1 (obligatoire)")),
              const SizedBox(height: 8),
              TextField(
                  controller: c2Ctrl,
                  decoration:
                      const InputDecoration(labelText: "Choix 2 (optionnel)")),
              const SizedBox(height: 8),
              TextField(
                  controller: c3Ctrl,
                  decoration:
                      const InputDecoration(labelText: "Choix 3 (optionnel)")),
              const SizedBox(height: 8),
              TextField(
                controller: prixCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,6}(,\d{0,2})?$')),
                  LengthLimitingTextInputFormatter(8)
                ],
                decoration: const InputDecoration(
                    labelText: "Prix de l'option (obligatoire, ex: 2,50)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          TextButton(
            onPressed: () {
              String nom = nomCtrl.text.trim();
              String choix1 = c1Ctrl.text.trim();
              String prixStr = prixCtrl.text.trim();

              if (nom.isEmpty) {
                Toast(context, "Le nom de l'option est obligatoire", false);
                return;
              }
              if (choix1.isEmpty) {
                Toast(context, "Au moins un choix est obligatoire", false);
                return;
              }
              if (prixStr.isEmpty) {
                Toast(context, "Le prix de l'option est obligatoire", false);
                return;
              }

              double prix = _parsePrice(prixStr);
              if (prix <= 0 && prixStr != "0") {
                Toast(context, "Prix invalide", false);
                return;
              }

              List<String> choices = [choix1];
              if (c2Ctrl.text.trim().isNotEmpty) {
                choices.add(c2Ctrl.text.trim());
              }
              if (c3Ctrl.text.trim().isNotEmpty) {
                choices.add(c3Ctrl.text.trim());
              }

              final newOption = DishOption(
                name: nom,
                choices: choices,
                price: prix,
              );

              _updateState(() {
                if (isEditing && optionIndex != null) {
                  _options[optionIndex] = newOption;
                } else {
                  _options.add(newOption);
                }
              });

              Navigator.pop(context);
            },
            child: const Text("Valider"),
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
        prefixIcon: Icon(icon, color: Colors.red),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
    );
  }
}

// Structure de données pour les options
class DishOption {
  final String name;
  final List<String> choices;
  final double price;

  DishOption({
    required this.name,
    required this.choices,
    required this.price,
  });
}
