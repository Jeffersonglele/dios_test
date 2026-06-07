import 'dart:io';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/modeles/address.dart' as address_model;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../Constant/Constant.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/HashtagTextInputFormatter.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../verif_confirm/ConfirmationPage.dart';

class RestaurantFormPage extends ConsumerStatefulWidget {
  final Restaurant? restaurant;
  const RestaurantFormPage({super.key, this.restaurant});

  bool get isEditing => restaurant != null;

  @override
  _RestaurantFormPageState createState() => _RestaurantFormPageState();
}

class _RestaurantFormPageState extends ConsumerState<RestaurantFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  File? _imageFile;
  List<String> _selectedHashtags = [];
  List<String> _selectedDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 20, minute: 0);
  String _recoveryMode = 'delivery';
  bool _isDetecting = false;
  bool _isSaving = false;
  bool _removeExistingImage = false;

  static const List<String> _allDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const Map<String, String> _dayLabels = {
    'Lun': 'Lundi', 'Mar': 'Mardi', 'Mer': 'Mercredi',
    'Jeu': 'Jeudi', 'Ven': 'Vendredi', 'Sam': 'Samedi', 'Dim': 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    if (r != null) {
      _nameController.text = r.name;
      _addressController.text = r.location ?? '';
      _descriptionController.text = r.description;
      _selectedHashtags = r.categories
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (r.openingDays.isNotEmpty) {
        _selectedDays = r.openingDays
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (r.openingHours.contains('-')) {
        final parts = r.openingHours.split('-');
        final open = _parseTime(parts[0].trim());
        final close = _parseTime(parts[1].trim());
        if (open != null) _openingTime = open;
        if (close != null) _closingTime = close;
      }
      if (r.recoveryMode.isNotEmpty) {
        _recoveryMode = r.recoveryMode;
      }
    }
  }

  TimeOfDay? _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await pickAndConfirmImage(context);
    if (file != null) setState(() => _imageFile = file);
  }

  Future<void> _detectPosition() async {
    setState(() => _isDetecting = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.country != null && p.country!.isNotEmpty) p.country!,
        ];
        setState(() => _addressController.text = parts.join(', '));
      }
    } catch (e) {
      if (context.mounted) Toast(context, 'Impossible de détecter la position', false);
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<bool> _validateAddressCountry(String address) async {
    final session = await SessionService.readSession();
    if (session.userId == 0) return false;
    try {
      final locations = await geo.locationFromAddress(address).timeout(const Duration(seconds: 10));
      if (locations.isEmpty) return false;
      final placemarks = await geo.placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      );
      if (placemarks.isEmpty) return false;
      final country = placemarks.first.country;
      if (country == null || country.isEmpty) return false;
      return country.toLowerCase().contains(session.country.toLowerCase()) ||
          session.country.toLowerCase().contains(country.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final current = isOpening ? _openingTime : _closingTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _sendEmailToAdmin(String name, String address, String phone) async {
    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': 'blandinedupont087@gmail.com',
        'subject': 'Nouvelle demande de Restaurant',
        'text': 'Nom du restaurant: $name\nAdresse: $address\nTéléphone: $phone',
      });
    } catch (_) {}
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Modifier mon restaurant' : 'Créer mon restaurant'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: widget.isEditing
              ? [TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                )]
              : null,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.05),
                  if (size.width <= 600)
                    const Center(child: BrandAvatarLogo()),
                  SizedBox(height: size.height * 0.02),
                  Text('Votre restaurant', style: kLoginTitleStyle(size)),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Nom du restaurant',
                    icon: Icons.restaurant,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Entrez le nom du restaurant';
                      if (v.length < 4) return 'Au moins 4 caractères';
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.015),

                  _buildAddressField(),
                  SizedBox(height: size.height * 0.015),

                  HashtagTextInputFormatter(
                    onHashtagsChanged: (h) => setState(() => _selectedHashtags = h),
                  ),
                  SizedBox(height: size.height * 0.015),

                  _buildTextField(
                    controller: _descriptionController,
                    hintText: 'Description du restaurant',
                    icon: Icons.info,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Entrez une description';
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.015),

                  _buildDaysSection(),
                  SizedBox(height: size.height * 0.015),

                  _buildHoursSection(),
                  SizedBox(height: size.height * 0.015),

                  _buildDeliveryModeSection(),
                  SizedBox(height: size.height * 0.02),

                  _buildImageSection(),
                  SizedBox(height: size.height * 0.02),

                  _buildSubmitButton(),
                  SizedBox(height: size.height * 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: _addressController,
            hintText: 'Adresse du restaurant',
            icon: Icons.location_city,
            validator: (v) {
              if (v == null || v.isEmpty) return "Entrez l'adresse";
              if (v.length < 4) return 'Au moins 4 caractères';
              return null;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: _isDetecting
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : IconButton(
                  onPressed: _detectPosition,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Détecter ma position',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text('Jours d\'ouverture', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allDays.map((day) {
            final selected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  if (selected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHoursSection() {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final containerBg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Text('Horaires', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onSurface)),
          const Spacer(),
          GestureDetector(
            onTap: () => _pickTime(isOpening: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text(_formatTime(_openingTime),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('—', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: onSurface)),
          ),
          GestureDetector(
            onTap: () => _pickTime(isOpening: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text(_formatTime(_closingTime),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Text('Mode de retrait', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _ModeChip(
              value: 'delivery',
              label: 'Livraison',
              icon: Icons.delivery_dining,
              selected: _recoveryMode == 'delivery' || _recoveryMode == 'both',
              multi: _recoveryMode == 'both',
              onTap: () => setState(() => _recoveryMode = _recoveryMode == 'delivery' ? 'both' : 'delivery'),
            ),
            _ModeChip(
              value: 'pickup',
              label: 'À emporter',
              icon: Icons.takeout_dining,
              selected: _recoveryMode == 'pickup' || _recoveryMode == 'both',
              multi: _recoveryMode == 'both',
              onTap: () => setState(() => _recoveryMode = _recoveryMode == 'pickup' ? 'both' : 'pickup'),
            ),
            _ModeChip(
              value: 'both',
              label: 'Les deux',
              icon: Icons.swap_horiz,
              selected: _recoveryMode == 'both',
              multi: false,
              onTap: () => setState(() => _recoveryMode = 'both'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final existingImage = widget.isEditing && !_removeExistingImage ? widget.restaurant?.image : null;
    final displayFile = _imageFile;

    return Center(
      child: Column(children: [
        if (displayFile != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(displayFile, width: 120, height: 80, fit: BoxFit.cover),
              ),
              Positioned(
                top: -8, right: -8,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _imageFile = null),
                  ),
                ),
              ),
            ],
          )
        else if (existingImage != null && existingImage.isNotEmpty)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(existingImage, width: 120, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 120, height: 80,
                    child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                ),
              ),
              Positioned(
                top: -8, right: -8,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _removeExistingImage = true),
                  ),
                ),
              ),
            ],
          )
        else
          const Text('Aucune image sélectionnée', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('Sélectionner une image'),
        ),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: () async {
          if (_isSaving) return;
          if (!_formKey.currentState!.validate()) {
            if (context.mounted) Toast(context, 'Veuillez corriger les champs en rouge.', false);
            return;
          }
          setState(() => _isSaving = true);
          try {
            final addressText = _addressController.text.trim();

            if (widget.isEditing && addressText == (widget.restaurant?.location ?? '')) {
              // unchanged address en mode édition → déjà valide
            } else if (!await _validateAddressCountry(addressText)) {
              if (context.mounted) Toast(context, "L'adresse n'est pas valide ou ne correspond pas à votre pays.", false);
              return;
            }

            final session = await SessionService.readSession();
            if (session.userId == 0) {
              if (context.mounted) Toast(context, 'Utilisateur non connecté.', false);
              return;
            }
            final userID = session.userId;
            final userCountry = session.country;
            final userRoleID = session.role.id;

            ParseFile? parseFile;
            final img = _imageFile;
            if (img != null && _nameController.text.isNotEmpty) {
              final ext = p.extension(img.path);
              final name = '${_nameController.text}_$userID$ext';
              parseFile = ParseFile(File(img.path), name: name);
            }

            int? addressID;
            final addressChanged = !widget.isEditing || addressText != (widget.restaurant?.location ?? '');
            if (addressChanged && addressText.isNotEmpty) {
              try {
                final locations = await geo.locationFromAddress(addressText).timeout(const Duration(seconds: 10));
                final lat = locations.isNotEmpty ? locations.first.latitude : 0.0;
                final lng = locations.isNotEmpty ? locations.first.longitude : 0.0;
                final result = await address_model.Address.manageAddress(
                  city: '',
                  state: userCountry,
                  fullAddress: addressText,
                  numero: 0,
                  lat: lat.toString(),
                  long: lng.toString(),
                  object: 'Restaurant',
                  objectID: userID,
                  user_roleID: userRoleID,
                );
                if (result is int) addressID = result;
              } catch (_) {}
            }

            final openingHours = '${_formatTime(_openingTime)} - ${_formatTime(_closingTime)}';
            final openingDays = _selectedDays.join(',');

            final result = await Restaurant.manageRestaurant(
            restaurantID: widget.restaurant?.restaurantID,
            userID: userID,
            valid: widget.restaurant?.valid ?? 0,
            nb_orders: widget.restaurant?.nb_orders ?? 0,
            note: widget.restaurant?.note ?? 0.0,
            categories: _selectedHashtags.join(', '),
            description: _descriptionController.text,
            location: addressText,
            name: _nameController.text,
            openingHours: openingHours,
            isOpen: widget.restaurant?.isOpen ?? 1,
            addressID: addressID,
            openingDays: openingDays,
            recoveryMode: _recoveryMode,
            image: parseFile,
            img_url: widget.isEditing && !_removeExistingImage ? widget.restaurant?.image : null,
            date_creation: widget.isEditing ? widget.restaurant?.date_creation : null,
          );

          if (result == "success") {
            if (context.mounted) Toast(context, 'Restaurant enregistré avec succès !', true);
            if (widget.isEditing) {
              if (context.mounted) Navigator.pop(context, true);
            } else {
              final usersList = await Users.fetchUsersFromDB();
              final dbUser = usersList.cast<Users?>().firstWhere(
                (u) => u?.userID == userID,
                orElse: () => null,
              );
              await _sendEmailToAdmin(
                _nameController.text,
                addressText,
                dbUser?.telephone ?? session.email ?? '',
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ConfirmationPage()),
                );
              }
            }
          } else {
            if (context.mounted) Toast(context, 'Erreur : $result', false);
          }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
        child: _isSaving
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(widget.isEditing ? 'Enregistrer' : 'Valider'),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
      maxLines: maxLines,
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  const _ModeChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final surface = Theme.of(context).colorScheme.surface;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: 0.12) : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? brand.withValues(alpha: 0.5) : outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            multi ? Icons.check_circle : icon,
            size: 18,
            color: selected ? brand : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? brand : Theme.of(context).colorScheme.onSurfaceVariant,
          )),
        ]),
      ),
    );
  }
}
