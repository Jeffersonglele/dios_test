import 'package:dios_delices/models/dish.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/hashtag_text_input_formatter.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/toast.dart';
import '../../l10n/app_localizations.dart';

const int _kMaxOptions = 3;
const int _kMaxChoices = 10;

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

double _parsePrice(String value) {
  if (value.trim().isEmpty) return 0.0;
  String cleaned = value.replaceAll(' ', '').replaceAll(',', '.');
  final parts = cleaned.split('.');
  if (parts.length > 2) {
    cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
  }
  final result = double.tryParse(cleaned) ?? 0.0;
  return double.parse(result.toStringAsFixed(2));
}

int _parseServings(String value) {
  if (value.trim().isEmpty) return 0;
  return int.tryParse(value.replaceAll(' ', '')) ?? 0;
}

/// 1500.0 -> "1500", 2.5 -> "2,50", 0 -> ""
String _priceToText(double v) {
  if (v <= 0) return '';
  return v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceAll('.', ',');
}

// ─────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────

class DishFormPage extends ConsumerStatefulWidget {
  final Dish? dish;
  const DishFormPage({super.key, this.dish});

  bool get isEditing => dish != null;

  @override
  ConsumerState<DishFormPage> createState() => _DishFormPageState();
}

class _DishFormPageState extends ConsumerState<DishFormPage> {
  String country = "";
  int currentUserRestau = 0;
  bool isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _nbServingsController = TextEditingController();

  List<String> _selectedHashtags = [];
  List<DishOption> _options = [];
  final List<XFile> _selectedImages = [];
  int _dishRestauID = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _nbServingsController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  // ── Données ────────────────────────────────────────────────

  Future<void> _initializeData() async {
    try {
      final session = await SessionService.readSession();
      _updateState(() {
        country = session.country;
        currentUserRestau = session.restaurantId ?? 0;
      });
    } catch (_) {}
  }

  List<DishOption> _parseOptionsFromDish(Dish d) {
    final result = <DishOption>[];
    for (final raw in [d.option1, d.option2, d.option3]) {
      if (raw == null || raw.isEmpty) continue;
      final parts = raw.split(' / ');
      if (parts.isEmpty) continue;

      final namePart = parts[0];
      final colonIdx = namePart.indexOf(':');
      final optName = colonIdx >= 0
          ? namePart.substring(0, colonIdx).trim()
          : namePart.trim();

      final choices = <DishChoice>[];
      for (int i = 1; i < parts.length; i++) {
        final choicePart = parts[i].trim();
        if (choicePart.isEmpty) continue;

        if (choicePart.contains('(inclus)')) {
          final choiceName = choicePart.replaceAll('(inclus)', '').trim();
          if (choiceName.isNotEmpty) {
            choices.add(DishChoice(name: choiceName, price: 0.0));
          }
        } else {
          final priceMatch =
              RegExp(r'(\d+[.,]?\d*)\s*(?:€|FCFA|CDF|XOF)').firstMatch(choicePart);
          if (priceMatch != null) {
            final choiceName =
                choicePart.substring(0, priceMatch.start).replaceAll('+', '').trim();
            final choicePrice =
                double.tryParse(priceMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
            if (choiceName.isNotEmpty) {
              choices.add(DishChoice(name: choiceName, price: choicePrice));
            }
          } else {
            choices.add(DishChoice(name: choicePart, price: 0.0));
          }
        }
      }

      if (choices.isNotEmpty) {
        result.add(DishOption(name: optName, choices: choices));
      }
    }
    return result;
  }

  String _formatOption(DishOption opt) {
    final choices = opt.choices.map((c) {
      return c.price > 0
          ? '${c.name} +${CurrencyUtil.formatPrice(c.price, country)}'
          : '${c.name} (inclus)';
    }).join(' / ');
    return '${opt.name}: $choices';
  }

  // ── Actions ────────────────────────────────────────────────

  void _removeOption(int index) => _updateState(() => _options.removeAt(index));

  /// Ouvre l'éditeur d'option dans un bottom sheet.
  /// Les controllers vivent dans le State du sheet et sont disposés
  /// par Flutter une fois l'animation de fermeture terminée.
  Future<void> _openOptionSheet({int? index}) async {
    final result = await showModalBottomSheet<DishOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(
        initial: index != null ? _options[index] : null,
        number: (index ?? _options.length) + 1,
        currency: CurrencyUtil.symbol(CurrencyUtil.code(country)),
      ),
    );
    if (result == null) return;
    _updateState(() {
      if (index != null) {
        _options[index] = result;
      } else {
        _options.add(result);
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await pickAndConfirmImage(context);
    if (file != null) _updateState(() => _selectedImages.add(file));
  }

  void _removeImage(int index) =>
      _updateState(() => _selectedImages.removeAt(index));

  Future<void> _submitForm() async {
    final restauID = widget.isEditing ? _dishRestauID : currentUserRestau;
    if (restauID <= 0) {
      Toast(context,
          "Restaurant non configuré. Veuillez d'abord configurer votre restaurant.",
          false);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      Toast(context, "Veuillez remplir tous les champs obligatoires", false);
      return;
    }

    final session = await SessionService.readSession();
    if (!mounted) return;

    if (session.userId == null) {
      Toast(context, "Utilisateur non connecté. Veuillez vous reconnecter.", false);
      return;
    }

    _updateState(() => isLoading = true);

    try {
      final formatted = List<String>.generate(
        3,
        (i) => i < _options.length ? _formatOption(_options[i]) : "",
      );

      final imagePaths = _selectedImages.map((x) => x.path).toList();

      final result = await Dish.manageDish(
        dishID: widget.dish?.dishID,
        userID: session.userId!,
        nb_orders: widget.dish?.nb_orders ?? 0,
        note: widget.dish?.note ?? 0.0,
        categories: _selectedHashtags.join(', '),
        description: _descriptionController.text,
        option1: formatted[0],
        option2: formatted[1],
        option3: formatted[2],
        name: _nameController.text,
        price: _parsePrice(_priceController.text),
        nb_servings: _parseServings(_nbServingsController.text),
        restauID: restauID,
        status: widget.dish?.status ?? 1,
        imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
        img_url: widget.isEditing ? widget.dish?.image : null,
        images: widget.isEditing ? widget.dish?.images : null,
      );

      if (!mounted) return;

      if (result == "success") {
        Toast(context,
            widget.isEditing ? "Plat modifié avec succès" : "Plat ajouté avec succès",
            true);
        Navigator.of(context).pop(true);
      } else {
        Toast(context, "Erreur : $result", false);
      }
    } catch (e) {
      if (mounted) Toast(context, "Erreur technique : $e", false);
    } finally {
      _updateState(() => isLoading = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = CurrencyUtil.symbol(CurrencyUtil.code(country));
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final brandSurface =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            widget.isEditing ? l10n.modify_dish : l10n.add_dish_title,
            style: AppTypography.titleSmall(color: Colors.white),
          ),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Informations ─────────────────────────
                    _Section(
                      title: 'Informations',
                      icon: Icons.info_rounded,
                      brand: brand, ink: ink, card: card, border: border,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: "Nom du plat",
                            icon: Icons.restaurant,
                            brand: brand, inkMuted: inkMuted, fill: surface, border: border,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Nom requis"
                                : v.trim().length < 4
                                    ? "Au moins 4 caractères"
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _descriptionController,
                            label: "Description",
                            icon: Icons.notes_rounded,
                            brand: brand, inkMuted: inkMuted, fill: surface, border: border,
                            maxLines: 3,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Description requise"
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _priceController,
                                  label: "Prix ($currency)",
                                  icon: Icons.payments_rounded,
                                  brand: brand, inkMuted: inkMuted, fill: surface, border: border,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: country == "France"
                                      ? [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d{0,2}(,\d{0,2})?')),
                                          LengthLimitingTextInputFormatter(5),
                                        ]
                                      : [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(5),
                                        ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Prix requis";
                                    if (_parsePrice(v) <= 0 && v.trim() != "0") {
                                      return "Prix invalide";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _nbServingsController,
                                  label: "Portions",
                                  icon: Icons.people_alt_rounded,
                                  brand: brand, inkMuted: inkMuted, fill: surface, border: border,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Requis";
                                    if (int.tryParse(v.replaceAll(' ', '')) == null) {
                                      return "Invalide";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          HashtagTextInputFormatter(
                            onHashtagsChanged: (tags) =>
                                _updateState(() => _selectedHashtags = tags),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Options ──────────────────────────────
                    _Section(
                      title: 'Options',
                      icon: Icons.tune_rounded,
                      trailing: '${_options.length}/$_kMaxOptions',
                      brand: brand, ink: ink, card: card, border: border,
                      inkMuted: inkMuted,
                      child: _buildOptionsContent(
                        l10n: l10n,
                        brand: brand, brandSurface: brandSurface,
                        ink: ink, inkMuted: inkMuted, border: border, fill: surface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Photos ───────────────────────────────
                    _Section(
                      title: 'Photos',
                      icon: Icons.image_rounded,
                      trailing: _selectedImages.isEmpty ? null : '${_selectedImages.length}',
                      brand: brand, ink: ink, card: card, border: border,
                      inkMuted: inkMuted,
                      child: _buildImageSection(
                        l10n: l10n,
                        brand: brand, brandSurface: brandSurface,
                        inkMuted: inkMuted, border: border, fill: surface,
                      ),
                    ),
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

        // Bouton d'action toujours visible
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: surface,
            border: Border(top: BorderSide(color: border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: brand.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.isEditing ? l10n.save : l10n.validate,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsContent({
    required AppLocalizations l10n,
    required Color brand,
    required Color brandSurface,
    required Color ink,
    required Color inkMuted,
    required Color border,
    required Color fill,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: inkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.no_options_available,
                      style: AppTypography.bodyMedium(color: inkMuted)),
                ),
              ],
            ),
          )
        else
          ..._options.asMap().entries.map((e) {
            final opt = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.name,
                          style: AppTypography.bodyMedium(color: ink)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.edit_rounded, size: 18, color: inkMuted),
                        onPressed: () => _openOptionSheet(index: e.key),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                        onPressed: () => _removeOption(e.key),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: opt.choices.map((c) {
                        final label = c.price > 0
                            ? '${c.name}  +${CurrencyUtil.formatPrice(c.price, country)}'
                            : c.name;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.price > 0 ? brandSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: c.price > 0
                                ? null
                                : Border.all(color: border, width: 0.8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.price > 0 ? brand : inkMuted,
                              fontWeight: c.price > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (_options.length < _kMaxOptions)
          OutlinedButton.icon(
            onPressed: () => _openOptionSheet(),
            icon: Icon(Icons.add_rounded, color: brand),
            label: Text(
              _options.isEmpty ? l10n.add_option_button : l10n.add_option_count(_options.length),
              style: TextStyle(color: brand),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              side: BorderSide(color: brand.withValues(alpha: 0.3)),
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection({
    required AppLocalizations l10n,
    required Color brand,
    required Color brandSurface,
    required Color inkMuted,
    required Color border,
    required Color fill,
  }) {
    const double size = 96;
    return SizedBox(
      height: size + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 8, right: 8),
        itemCount: _selectedImages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          // Tuile d'ajout toujours en premier
          if (i == 0) {
            return InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: brandSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brand.withValues(alpha: 0.35)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, color: brand, size: 28),
                    const SizedBox(height: 4),
                    Text('Ajouter', style: TextStyle(color: brand, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          final index = i - 1;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: pickedImagePreview(
                  _selectedImages[index],
                  height: size, width: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: size, width: size,
                    color: fill,
                    child: Icon(Icons.broken_image, size: 36, color: inkMuted),
                  ),
                ),
              ),
              Positioned(
                top: -6, right: -6,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
              if (index == 0)
                Positioned(
                  bottom: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(l10n.main_photo_badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color brand,
    required Color inkMuted,
    required Color fill,
    required Color border,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
  }) {
    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppDarkColors.ink
            : AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: inkMuted),
        floatingLabelStyle: TextStyle(color: brand),
        prefixIcon: Icon(icon, color: brand, size: 20),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(brand, 2),
        errorBorder: outline(AppColors.error),
        focusedErrorBorder: outline(AppColors.error, 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section (titre + contenu dans une seule surface)
// ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? trailing;
  final Color brand;
  final Color ink;
  final Color? inkMuted;
  final Color card;
  final Color border;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.brand,
    required this.ink,
    required this.card,
    required this.border,
    required this.child,
    this.trailing,
    this.inkMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: brand),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTypography.titleMedium(color: ink))),
              if (trailing != null)
                Text(trailing!,
                    style: TextStyle(color: inkMuted ?? ink, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom sheet d'édition d'une option
//
// CORRECTIF : les TextEditingController appartiennent à ce State.
// Flutter appelle dispose() uniquement quand la route est réellement
// retirée de l'arbre (après l'animation de fermeture), donc plus
// aucun TextField ne peut utiliser un controller déjà disposé.
// ─────────────────────────────────────────────────────────────

class _ChoiceFields {
  final TextEditingController name;
  final TextEditingController price;

  _ChoiceFields({String initialName = '', String initialPrice = ''})
      : name = TextEditingController(text: initialName),
        price = TextEditingController(text: initialPrice);

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _OptionSheet extends StatefulWidget {
  final DishOption? initial;
  final int number;
  final String currency;

  const _OptionSheet({
    required this.number,
    required this.currency,
    this.initial,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late final TextEditingController _nameCtrl;
  final List<_ChoiceFields> _fields = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final o = widget.initial;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    for (final c in o?.choices ?? const <DishChoice>[]) {
      _fields.add(_ChoiceFields(
        initialName: c.name,
        initialPrice: _priceToText(c.price),
      ));
    }
    if (_fields.isEmpty) _fields.add(_ChoiceFields());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _addChoice() {
    if (_fields.length >= _kMaxChoices) return;
    setState(() => _fields.add(_ChoiceFields()));
  }

  void _removeChoice(int index) {
    if (_fields.length <= 1) return;
    final removed = _fields.removeAt(index);
    setState(() {});
    // On dispose après le prochain frame, quand le TextField a été retiré
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Le nom de l'option est obligatoire");
      return;
    }

    final choices = <DishChoice>[];
    for (final f in _fields) {
      final n = f.name.text.trim();
      if (n.isEmpty) continue;
      choices.add(DishChoice(name: n, price: _parsePrice(f.price.text)));
    }
    if (choices.isEmpty) {
      setState(() => _error = "Ajoutez au moins un choix");
      return;
    }

    // ":" et "/" servent de séparateurs dans le texte enregistré
    final forbidden = RegExp(r'[:/]');
    if (forbidden.hasMatch(name) || choices.any((c) => forbidden.hasMatch(c.name))) {
      setState(() => _error = "Évitez les caractères « : » et « / » dans les noms");
      return;
    }

    Navigator.pop(context, DishOption(name: name, choices: choices));
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final l10n = AppLocalizations.of(context)!;

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    InputDecoration deco(String label, {String? hint, String? suffix}) => InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          labelStyle: TextStyle(color: inkMuted),
          floatingLabelStyle: TextStyle(color: brand),
          filled: true,
          fillColor: card,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: outline(border),
          enabledBorder: outline(border),
          focusedBorder: outline(brand, 2),
        );

    return Padding(
      // Remonte le sheet quand le clavier s'ouvre
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.initial != null
                      ? "${l10n.modify} l'option"
                      : "Option ${widget.number}",
                  style: AppTypography.titleMedium(color: ink),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: ink),
                  decoration: deco(l10n.option_name, hint: "Ex : Accompagnement"),
                ),
                const SizedBox(height: 18),
                Text("Choix",
                    style: AppTypography.bodyMedium(color: ink)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text("Laissez le prix vide si le choix est inclus.",
                    style: TextStyle(color: inkMuted, fontSize: 12)),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int i = 0; i < _fields.length; i++)
                          Padding(
                            // La key garantit que chaque ligne garde SON controller
                            key: ObjectKey(_fields[i]),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _fields[i].name,
                                    style: TextStyle(color: ink),
                                    decoration: deco("Choix ${i + 1}"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _fields[i].price,
                                    style: TextStyle(color: ink),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                                      LengthLimitingTextInputFormatter(9),
                                    ],
                                    decoration: deco("Prix", hint: "Inclus", suffix: widget.currency),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: _fields.length > 1 ? AppColors.error : border,
                                  ),
                                  onPressed: _fields.length > 1 ? () => _removeChoice(i) : null,
                                ),
                              ],
                            ),
                          ),
                        if (_fields.length < _kMaxChoices)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _addChoice,
                              icon: Icon(Icons.add_rounded, color: brand, size: 20),
                              label: Text("Ajouter un choix", style: TextStyle(color: brand)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l10n.cancel, style: TextStyle(color: inkMuted)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l10n.validate,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────────────────────

class DishOption {
  final String name;
  final List<DishChoice> choices;

  DishOption({required this.name, required this.choices});
}

class DishChoice {
  final String name;
  final double price;

  DishChoice({required this.name, required this.price});
}