import 'package:dios_delices/models/dish.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../constants/constant.dart';
import '../../providers/users_provider.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/hashtag_text_input_formatter.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';

class DishFormPage extends ConsumerStatefulWidget {
  final Dish? dish;
  const DishFormPage({super.key, this.dish});

  bool get isEditing => dish != null;

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
  List<DishOption> _options = [];
  List<XFile> _selectedImages = [];
  int _dishRestauID = 0;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    final d = widget.dish;
    if (d != null) {
      _nameController.text = d.name ?? '';
      _descriptionController.text = d.description ?? '';
      _priceController.text = d.price?.toStringAsFixed(2) ?? '';
      _nbServingsController.text = d.nb_servings?.toString() ?? '';
      _selectedHashtags = (d.categories ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _dishRestauID = d.restauID;
      _options = _parseOptionsFromDish(d);
    }
    _initializeData();
  }

  List<DishOption> _parseOptionsFromDish(Dish d) {
    final result = <DishOption>[];
    for (final raw in [d.option1, d.option2, d.option3]) {
      if (raw == null || raw.isEmpty) continue;
      final parts = raw.split(' / ');
      if (parts.isEmpty) continue;
      final namePart = parts[0];
      final colonIdx = namePart.indexOf(':');
      final optName = colonIdx >= 0 ? namePart.substring(0, colonIdx).trim() : namePart.trim();
      final priceMatch = RegExp(r'^(\d+[.,]?\d*)\s*(?:€|FCFA|CDF)').firstMatch(parts.last.trim());
      final optPrice = priceMatch != null ? double.tryParse(priceMatch.group(1)!.replaceAll(',', '.')) ?? 0.0 : 0.0;
      final choices = <String>[];
      for (int i = 1; i < parts.length - (priceMatch != null ? 1 : 0); i++) {
        final c = parts[i].trim();
        if (c.isNotEmpty) choices.add(c);
      }
      result.add(DishOption(name: optName, choices: choices, price: optPrice));
    }
    return result;
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
    final file = await pickAndConfirmImage(context);
    if (file != null && mounted) {
      _updateState(() => _selectedImages.add(file));
    }
  }

  void _removeImage(int index) {
    _updateState(() => _selectedImages.removeAt(index));
  }

  Future<void> _initializeData() async {
    try {
      final session = await SessionService.readSession();
      _updateState(() {
        country = session.country;
        currentUser_restau = session.restaurantId ?? 0;
      });
    } catch (e) {
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
      _selectedImages = [];
    });
  }

  Future<void> _submitForm() async {
    // Vérification restaurant
    final restauID = widget.isEditing ? _dishRestauID : currentUser_restau;
    if (restauID <= 0) {
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
          optionText += " / ${CurrencyUtil.formatPrice(opt.price, country)}";
        }
        if (i == 0) {
          option1 = optionText;
        } else if (i == 1) {
          option2 = optionText;
        } else if (i == 2) {
          option3 = optionText;
        }
      }

      // Préparation des images
      ParseFileBase? parseFile;
      List<ParseFileBase> extraImages = [];
      if (_selectedImages.isNotEmpty) {
        String baseName = _nameController.text.replaceAll(RegExp(r'\s+'), '_');
        String extension = p.extension(_selectedImages.first.path);
        String newFileName =
            "${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension";
        parseFile = ParseXFile(_selectedImages.first, name: newFileName);

        for (int i = 1; i < _selectedImages.length; i++) {
          String ext = p.extension(_selectedImages[i].path);
          String name =
              "${baseName}_${DateTime.now().millisecondsSinceEpoch}_$i$ext";
          extraImages.add(ParseXFile(_selectedImages[i], name: name));
        }
      }

      // Appel à la fonction de création
      String result = await Dish.manageDish(
        dishID: widget.dish?.dishID,
        userID: userId,
        nb_orders: widget.dish?.nb_orders ?? 0,
        note: widget.dish?.note ?? 0.0,
        categories: _selectedHashtags.join(', '),
        description: _descriptionController.text,
        option1: option1,
        option2: option2,
        option3: option3,
        name: _nameController.text,
        price: _parsePrice(_priceController.text),
        nb_servings: _parseServings(_nbServingsController.text),
        restauID: restauID,
        status: widget.dish?.status ?? 1,
        image: parseFile,
        extraImages: extraImages.isNotEmpty ? extraImages : null,
        img_url: widget.isEditing ? widget.dish?.image : null,
        images: widget.isEditing ? widget.dish?.images : null,
      );

      if (!mounted) return;

      if (result == "success") {
        Toast(context, widget.isEditing ? "Plat modifié avec succès" : "Plat ajouté avec succès", true);
        _clearFields();
        Navigator.of(context).pop(true);
      } else {
        Toast(context, "Erreur : $result", false);
      }
    } catch (e) {
      if (mounted) {
        Toast(context, "Erreur technique : ${e.toString()}", false);
      }
    } finally {
      if (mounted) _updateState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final currency = CurrencyUtil.symbol(country);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final brandSurface = AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(widget.isEditing ? l10n.modify_dish : l10n.add_dish_title, style: AppTypography.titleSmall(color: Colors.white)),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
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
                    _buildSectionHeader('Informations', Icons.info_rounded, brand, ink),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      hintText: "Nom du plat",
                      icon: Icons.restaurant,
                      brand: brand, inkMuted: inkMuted, card: card, border: border,
                      validator: (v) => v == null || v.isEmpty
                          ? "Nom requis"
                          : v.length < 4
                              ? "Au moins 4 caractères"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    HashtagTextInputFormatter(
                      onHashtagsChanged: (tags) =>
                          _updateState(() => _selectedHashtags = tags),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nbServingsController,
                            hintText: "Portions",
                            icon: Icons.fastfood,
                            brand: brand, inkMuted: inkMuted, card: card, border: border,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3)
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Requis";
                              if (int.tryParse(v.replaceAll(' ', '')) == null) return "Invalide";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _priceController,
                            hintText: "Prix ($currency)",
                            icon: Icons.money,
                            brand: brand, inkMuted: inkMuted, card: card, border: border,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: country == "France"
                                ? [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(,\d{0,2})?')),
                                    LengthLimitingTextInputFormatter(5)
                                  ]
                                : [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5)
                                  ],
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Prix requis";
                              if (_parsePrice(v) <= 0 && v.trim() != "0") return "Prix invalide";
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      hintText: "Description du plat",
                      icon: Icons.description,
                      brand: brand, inkMuted: inkMuted, card: card, border: border,
                      maxLines: 3,
                      validator: (v) => v == null || v.isEmpty ? "Description requise" : null,
                    ),
                    const SizedBox(height: 24),

                    // Options
                    _buildSectionHeader('Options', Icons.tune_rounded, brand, ink),
                    const SizedBox(height: 12),
                    if (_options.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: border, width: 0.5),
                        ),
                        child: Column(children: [
                          Icon(Icons.tune_rounded, size: 36, color: inkMuted),
                          const SizedBox(height: 10),
                          Text(l10n.no_options_available, style: AppTypography.bodyMedium(color: inkMuted)),
                          const SizedBox(height: 14),
                          SizedBox(width: double.infinity, child: OutlinedButton.icon(
                            onPressed: () { if (_options.length < 3) _showOptionDialog(optionIndex: _options.length); },
                            icon: Icon(Icons.add_rounded, color: brand),
                            label: Text(l10n.add_option_button, style: TextStyle(color: brand)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                              side: BorderSide(color: brand.withValues(alpha: 0.3)),
                            ),
                          )),
                        ]),
                      )
                    else ...[
                      ..._options.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final opt = e.value;
                        String display = '${opt.name}: ${opt.choices.join(" / ")}';
                        if (opt.price > 0) display += ' / +${CurrencyUtil.formatPrice(opt.price, country)}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: brand.withValues(alpha: 0.15)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(6)),
                              child: Center(child: Text('$i', style: TextStyle(color: brand, fontWeight: FontWeight.w600, fontSize: 12))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(display, style: AppTypography.bodyMedium().copyWith(fontSize: 13, color: ink))),
                            IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: inkMuted), onPressed: () => _editOption(e.key)),
                            IconButton(icon: Icon(Icons.delete_rounded, size: 18, color: AppColors.error), onPressed: () => _removeOption(e.key)),
                          ]),
                        );
                      }),
                      if (_options.length < 3)
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(
                          onPressed: () => _showOptionDialog(optionIndex: _options.length),
                          icon: Icon(Icons.add_rounded, color: brand),
                          label: Text(l10n.add_option_count(_options.length), style: TextStyle(color: brand)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            side: BorderSide(color: brand.withValues(alpha: 0.25)),
                          ),
                        )),
                    ],
                    const SizedBox(height: 24),

                    // Image
                    _buildSectionHeader('Photo', Icons.image_rounded, brand, ink),
                    const SizedBox(height: 12),
                    _buildImageSection(brand: brand, card: card, inkMuted: inkMuted, border: border),
                    const SizedBox(height: 30),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(widget.isEditing ? l10n.save.toUpperCase() : l10n.validate.toUpperCase(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color brand, Color ink) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: brand),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTypography.titleMedium(color: ink)),
      ],
    );
  }

  Widget _buildImageSection({required Color brand, required Color card, required Color inkMuted, required Color border}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: pickedImagePreview(
                        _selectedImages[index],
                        height: 100, width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100, width: 100,
                            color: card,
                            child: Icon(Icons.broken_image, size: 40, color: inkMuted),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: -6, right: -6,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: Text(l10n.main_photo_badge, style: const TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Icon(Icons.image_outlined, size: 40, color: inkMuted),
                const SizedBox(height: 8),
                Text("Aucune image", style: TextStyle(color: inkMuted)),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.photo_library, color: brand),
              label: Text("Ajouter une image", style: TextStyle(color: brand)),
            ),
            if (_selectedImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${_selectedImages.length} image(s)',
                  style: TextStyle(color: inkMuted, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ],
    );
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
      builder: (ctx) {
        final dl10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
        title:
            Text(isEditing ? "${dl10n.modify} l'option" : "Option ${targetIndex + 1}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nomCtrl,
                  decoration:
                      InputDecoration(labelText: dl10n.option_name)),
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
                      RegExp(r'^\d{1,6}(,\d{0,2})?$')),
                  LengthLimitingTextInputFormatter(8)
                ],
                decoration: InputDecoration(
                    labelText: dl10n.option_price_hint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dl10n.cancel)),
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

              Navigator.pop(ctx);
            },
            child: Text(dl10n.validate),
          ),
        ],
      );
  },);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color brand,
    required Color inkMuted,
    required Color card,
    required Color border,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: brand),
        hintText: hintText,
        hintStyle: TextStyle(color: inkMuted),
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppDarkColors.ink : AppColors.ink),
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
