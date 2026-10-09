import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:io';
import '../../constants/constant.dart';
import '../../utils/image_picker_helper.dart';
import '../../models/users.dart';
import '../../providers/users_provider.dart';
import '../../utils/hashtag_text_input_formatter.dart';
import '../../utils/phone_number.dart';
import '../../services/node_admin_service.dart';
import '../../services/session_service.dart';
import '../../services/upload_service.dart';
import '../../services/geocoding_api_service.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../widgets/dios_image.dart';
import '../splash/animated_splash_screen.dart';
import '../onboarding/confirmation_page.dart';

class RestaurantUpdateFormPage extends ConsumerStatefulWidget {
  final Users user;
  final Restaurant restaurant;

  RestaurantUpdateFormPage({required this.user, required this.restaurant});

  @override
  _RestaurantUpdateFormPageState createState() =>
      _RestaurantUpdateFormPageState();
}

class _RestaurantUpdateFormPageState
    extends ConsumerState<RestaurantUpdateFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoriesController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isOpen = true;
  bool _isDetecting = false;
  List<String> _selectedHashtags = [];
  List<String> _selectedDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  static const _allDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  XFile? _image;

  Future<void> _detectPosition() async {
    setState(() => _isDetecting = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (context.mounted) Toast(context, 'Service de localisation désactivé', false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (context.mounted) Toast(context, 'Permission de localisation refusée', false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (context.mounted) Toast(context, 'Impossible de détecter votre position GPS', false);
        return;
      }

      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);

      try {
        final reverse = await GeocodingApiService.reverse(
          position.latitude,
          position.longitude,
        );
        final parts = <String>[
          if (reverse.thoroughfare != null && reverse.thoroughfare!.isNotEmpty) reverse.thoroughfare!,
          if (reverse.street != null && reverse.street!.isNotEmpty) reverse.street!,
          if (reverse.subLocality != null && reverse.subLocality!.isNotEmpty) reverse.subLocality!,
          if (reverse.locality != null && reverse.locality!.isNotEmpty) reverse.locality!,
          if (reverse.country != null && reverse.country!.isNotEmpty) reverse.country!,
        ];
        final addressText = parts.isNotEmpty
            ? parts.join(', ')
            : (reverse.displayName ?? '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
        if (addressText.isNotEmpty) {
          _addressController.text = addressText;
        }
      } catch (_) {}
      if (context.mounted) Toast(context, 'Position GPS détectée avec succès !', true);
    } catch (e) {
      if (context.mounted) Toast(context, 'Erreur lors de la détection GPS', false);
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  // Méthode pour ouvrir l'image picker
  Future<void> _pickImage() async {
    final file = await pickAndConfirmImage(context);
    if (file != null) setState(() => _image = file);
  }

  // Fonction pour envoyer un email à l'admin avec les infos du restaurant
  Future<void> _sendEmailToAdmin(
      String name, String address, String phone) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return;
    await NodeAdminService.sendEmail(
      to: 'blandinedupont087@gmail.com',
      subject: 'Nouvelle demande de Restaurant',
      text: 'Nom du restaurant: $name\nAdresse: $address\nTéléphone: $phone',
      token: token,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _categoriesController.dispose();
    _openingHoursController.dispose();
    _deliveryFeeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
  void initState() {
    super.initState();
    // Initialisez les champs avec les informations du restaurant
    _nameController.text = widget.restaurant.name;
    _addressController.text = widget.restaurant.location;
    _descriptionController.text = widget.restaurant.description;
    _categoriesController.text = widget.restaurant.categories;
    _openingHoursController.text = widget.restaurant.openingHours;
    if (widget.restaurant.openingDays.isNotEmpty) {
      _selectedDays = widget.restaurant.openingDays
          .split(',')
          .map((day) => day.trim())
          .where((day) => day.isNotEmpty)
          .toList();
    }
    _deliveryFeeController.text =
        widget.restaurant.deliveryFee.toStringAsFixed(2);
    _isOpen = widget.restaurant.isOpen == 1;
    // Pré-remplir les coordonnées GPS si disponibles
    if (widget.restaurant.latitude != null) {
      _latitudeController.text = widget.restaurant.latitude.toString();
    }
    if (widget.restaurant.longitude != null) {
      _longitudeController.text = widget.restaurant.longitude.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.restaurant_form_section_restaurant,
                      style: kLoginTitleStyle(size),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Champs avec valeurs pré-remplies
                  _buildTextField(
                    controller: _nameController,
                    hintText: l10n.restaurant_form_name_hint,
                    icon: Icons.restaurant,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.restaurant_form_name_required;
                      } else if (value.length < 4) {
                        return l10n.restaurant_form_name_min_length;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildOpeningDays(l10n),
                  SizedBox(height: size.height * 0.02),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _addressController,
                          hintText: l10n.restaurant_form_address_hint,
                          icon: Icons.location_city,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.restaurant_form_address_required;
                            } else if (value.length < 4) {
                              return l10n.restaurant_form_name_min_length;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          onPressed: _isDetecting ? null : _detectPosition,
                          icon: _isDetecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.gps_fixed, color: Colors.red),
                          tooltip: 'Actualiser ma position GPS',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ],
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
                  _buildTextField(
                    controller: _descriptionController,
                    hintText: l10n.restaurant_form_desc_hint,
                    keyboardType: TextInputType.multiline,
                    icon: Icons.info,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.restaurant_form_desc_required;
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
                    hintText: l10n.restaurant_form_opening_hours_hint,
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
                    hintText: l10n.restaurant_form_delivery_fee_hint,
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
                  // Coordonnées GPS & Détection
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latitudeController,
                          hintText: 'Latitude (optionnel)',
                          icon: Icons.my_location,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _longitudeController,
                          hintText: 'Longitude (optionnel)',
                          icon: Icons.my_location,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isDetecting ? null : _detectPosition,
                        icon: _isDetecting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gps_fixed, color: Colors.red),
                        tooltip: 'Actualiser ma position GPS',
                      ),
                    ],
                  ),
                  SizedBox(height: size.height * 0.02),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.restaurant_form_open_now),
                    value: _isOpen,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _isOpen = value;
                      });
                    },
                  ),
                  SizedBox(height: size.height * 0.02),
                  // Sélection de l'image
                  Center(
                    child: Column(
                      children: <Widget>[
                        _image != null
                            ? pickedImagePreview(
                                _image!,
                                width: 100,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                          : widget.restaurant.image!.isNotEmpty
                              ? SizedBox(
                                  width: 100,
                                  height: 60,
                                  child: DiosImage(
                                    url: widget.restaurant.image,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : Text(
                                    l10n.restaurant_form_no_image,
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _pickImage,
                          child: Text(
                            l10n.restaurant_form_select_image,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                          if (_selectedDays.isEmpty) {
                            Toast(context, l10n.restaurant_form_day_required, false);
                            return;
                          }
                          final manualLat = double.tryParse(_latitudeController.text.trim());
                          final manualLng = double.tryParse(_longitudeController.text.trim());
                          final hasCoords = manualLat != null && manualLng != null && manualLat.isFinite && manualLng.isFinite;
                          final isAddressValid = hasCoords || await _isValidAddress(_addressController.text);

                          if (!isAddressValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("L'adresse saisie est invalide. Veuillez utiliser la détection GPS."),
                              ),
                            );
                            return;
                          }

                          final user = ref.read(usersProvider);
                          if (user != null) {
                            String? imageUrl;
                            final _image = this._image;

                            if (_image != null) {
                              if (_nameController.text.isNotEmpty &&
                                  user.userID != null) {
                                // Upload vers R2 via le nouveau backend
                                final imageFile = File(_image.path);
                                imageUrl = await UploadService.uploadImage(imageFile, scope: 'restaurants');
                                if (imageUrl == null) {
                                  Toast(context, 'Erreur lors de l\'upload de l\'image', false);
                                  return;
                                }
                              } else {
                                return;
                              }
                            }

                            // Now call the method to manage the restaurant
                            double? geoLat = widget.restaurant.latitude;
                            double? geoLng = widget.restaurant.longitude;
                            final addressChanged = _addressController.text.trim() != widget.restaurant.location;
                            final manualLat = double.tryParse(_latitudeController.text.trim());
                            final manualLng = double.tryParse(_longitudeController.text.trim());

                            // Priorité: coordonnées manuelles > géocodage si adresse changée > coordonnées existantes
                            if (manualLat != null && manualLng != null) {
                              geoLat = manualLat;
                              geoLng = manualLng;
                              print('🚚 Using manual coordinates: $geoLat, $geoLng');
                            } else if (addressChanged) {
                              try {
                                final geo = await GeocodingApiService.search(_addressController.text, limit: 3).timeout(const Duration(seconds: 10));
                                final lat = geo.isNotEmpty ? geo.first.latitude : 0.0;
                                final lng = geo.isNotEmpty ? geo.first.longitude : 0.0;
                                if (lat.isFinite && lng.isFinite && (lat != 0.0 || lng != 0.0)) {
                                  geoLat = lat;
                                  geoLng = lng;
                                  print('🚚 Geocoded restaurant ${widget.restaurant.restaurantID}: $geoLat, $geoLng');
                                }
                              } catch (e) {
                                print('🚚 Geocoding failed: $e');
                              }
                            }

                            String createResult =
                                await Restaurant.manageRestaurant(
                              restaurantID: widget.restaurant.restaurantID,
                              userID: user.userID,
                              country: user.country,
                              valid: widget.restaurant.valid,
                              nb_orders: widget.restaurant.nb_orders,
                              note: widget.restaurant.note,
                              categories: _selectedHashtags.join(', '),
                              description: _descriptionController.text,
                              location: _addressController.text,
                              name: _nameController.text,
                              openingHours: _openingHoursController.text.trim(),
                              openingDays: _selectedDays.join(','),
                              deliveryFee: double.parse(
                                _deliveryFeeController.text
                                    .replaceAll(',', '.'),
                              ),
                              isOpen: _isOpen ? 1 : 0,
                              image: null, // On utilise imageUrl à la place
                              img_url: imageUrl ?? widget.restaurant.image,
                              latitude: geoLat,
                              longitude: geoLng,
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
                              Toast(context, "$createResult", false);
                            }
                          }
                        }
                      },
                      child: Text(l10n.restaurant_form_update),
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

  Widget _buildOpeningDays(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(l10n.restaurant_form_opening_days,
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allDays.map((day) {
            final selected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: selected,
              onSelected: (_) => setState(() {
                if (selected) {
                  _selectedDays.remove(day);
                } else {
                  _selectedDays.add(day);
                }
              }),
            );
          }).toList(),
        ),
      ],
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
