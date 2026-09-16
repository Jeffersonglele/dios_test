import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;
import '../../constants/constant.dart';
import '../../utils/image_picker_helper.dart';
import '../../models/users.dart';
import '../../providers/users_provider.dart';
import '../../utils/hashtag_text_input_formatter.dart';
import '../../utils/phone_number.dart';
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
  bool _isOpen = true;
  List<String> _selectedHashtags = [];

  XFile? _image;

  // Méthode pour ouvrir l'image picker
  Future<void> _pickImage() async {
    final file = await pickAndConfirmImage(context);
    if (file != null) setState(() => _image = file);
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
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _categoriesController.dispose();
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
  void initState() {
    super.initState();
    // Initialisez les champs avec les informations du restaurant
    _nameController.text = widget.restaurant.name;
    _addressController.text = widget.restaurant.location;
    _descriptionController.text = widget.restaurant.description;
    _categoriesController.text = widget.restaurant.categories;
    _openingHoursController.text = widget.restaurant.openingHours;
    _deliveryFeeController.text =
        widget.restaurant.deliveryFee.toStringAsFixed(2);
    _isOpen = widget.restaurant.isOpen == 1;
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
                  _buildTextField(
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
                            ParseFileBase? parseFile;
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
                                parseFile = ParseXFile(_image,
                                    name: newFileName);
                              } else {
                                return;
                              }
                            }

                            // Now call the method to manage the restaurant
                            String createResult =
                                await Restaurant.manageRestaurant(
                              restaurantID: widget.restaurant.restaurantID,
                              userID: user.userID,
                              valid: widget.restaurant.valid,
                              nb_orders: widget.restaurant.nb_orders,
                              note: widget.restaurant.note,
                              categories: _selectedHashtags.join(', '),
                              description: _descriptionController.text,
                              location: _addressController.text,
                              name: _nameController.text,
                              openingHours: _openingHoursController.text.trim(),
                              deliveryFee: double.parse(
                                _deliveryFeeController.text
                                    .replaceAll(',', '.'),
                              ),
                              isOpen: _isOpen ? 1 : 0,
                              image: parseFile,
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
