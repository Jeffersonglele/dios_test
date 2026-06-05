import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modeles/address.dart';
import '../widgets/brand_avatar_logo.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
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
  bool _isLocating = false;
  bool _isSaving = false;

  TextEditingController locationController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController fullAddressController = TextEditingController();

  Future<void> getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        Toast(context, 'Localisation désactivée. Activez-la dans les paramètres.', false);
        return;
      }
      Position newPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => position = newPosition);

      List<Placemark> placeMarks =
          await placemarkFromCoordinates(position!.latitude, position!.longitude);
      if (placeMarks.isNotEmpty) {
        Placemark pMarks = placeMarks[0];
        completeAddress =
            '${pMarks.thoroughfare ?? ''}, ${pMarks.locality ?? ''}, ${pMarks.administrativeArea ?? ''}, ${pMarks.country ?? ''}'
                .replaceAll(RegExp(r'^,\s*|\s*,\s*$'), '');
        locationController.text = completeAddress!;
      }
    } catch (e) {
      Toast(context, 'Impossible de détecter la position.', false);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  String? _extractCity() {
    final parts = locationController.text.split(', ');
    return parts.length > 1 ? parts[1] : null;
  }

  String? _extractState() {
    final parts = locationController.text.split(', ');
    return parts.length > 3 ? parts[3] : null;
  }

  void saveDetectedAddress() async {
    final city = _extractCity() ?? cityController.text;
    final state = _extractState() ?? stateController.text;
    final fullAddress = locationController.text.isNotEmpty
        ? locationController.text
        : '';
    final lat = position?.latitude.toString();
    final long = position?.longitude.toString();

    setState(() => _isSaving = true);
    try {
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
        setState(() => addressExists = true);
        Toast(context, "Adresse déjà enregistrée.", true);
        return;
      }

      if (validationResult is int) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);
        Toast(context, "Adresse enregistrée avec succès !", true);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatusSelectionPage(
                  country: state,
                  objectID: widget.objectID,
                  user_roleID: widget.user_roleID),
            ),
          );
        }
      } else {
        Toast(context, validationResult, false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void saveManualAddress() async {
    final city = cityController.text.trim();
    final state = stateController.text.trim();
    final fullAddress = fullAddressController.text.trim();

    if (city.isEmpty || state.isEmpty || fullAddress.isEmpty) {
      Toast(context, "Veuillez remplir tous les champs d'adresse.", false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      List<Location> locations =
          await locationFromAddress("$fullAddress, $city, $state");
      if (locations.isEmpty) {
        Toast(context, "Adresse introuvable. Vérifiez l'exactitude.", false);
        return;
      }

      double lat = locations.first.latitude;
      double long = locations.first.longitude;

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
        setState(() => addressExists = true);
        Toast(context, "Adresse déjà enregistrée.", true);
        return;
      }

      if (validationResult is int) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);
        Toast(context, "Adresse enregistrée avec succès !", true);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatusSelectionPage(
                  country: state,
                  objectID: widget.objectID,
                  user_roleID: widget.user_roleID),
            ),
          );
        }
      } else {
        Toast(context, validationResult, false);
      }
    } catch (e) {
      Toast(context, "Adresse introuvable, vérifiez les informations.", false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context);
    final isWide = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.06),
              if (!isWide)
                const Center(child: BrandAvatarLogo()),
              SizedBox(height: size.height * 0.03),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  'Mon adresse',
                  style: AppTypography.displayMedium(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  'Indiquez votre adresse pour recevoir vos commandes.',
                  style: AppTypography.bodyLarge(
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLocating ? null : getCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.my_location, color: AppColors.surface),
                  label: Text(
                    _isLocating ? 'Localisation...' : 'Obtenir ma localisation',
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Adresse détectée",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => showManualEntry = !showManualEntry),
                  icon: Icon(
                    showManualEntry
                        ? Icons.expand_less
                        : Icons.edit_location_alt_outlined,
                  ),
                  label: Text(
                    showManualEntry
                        ? "Masquer le formulaire"
                        : "Entrer mon adresse manuellement",
                  ),
                ),
              ),
              if (showManualEntry) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: "Ville",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: stateController,
                  decoration: InputDecoration(
                    labelText: "État / Région",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: fullAddressController,
                  decoration: InputDecoration(
                    labelText: "Adresse complète",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (locationController.text.isNotEmpty) {
                            saveDetectedAddress();
                          } else if (fullAddressController.text.isNotEmpty) {
                            saveManualAddress();
                          } else {
                            Toast(
                              context,
                              "Veuillez entrer ou détecter une adresse.",
                              false,
                            );
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : Text(
                          "Enregistrer l'adresse",
                          style: const TextStyle(
                            color: AppColors.surface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (addressExists) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatusSelectionPage(
                            country: stateController.text.isNotEmpty
                                ? stateController.text
                                : _extractState() ?? '',
                            objectID: widget.objectID,
                            user_roleID: widget.user_roleID,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, color: AppColors.surface),
                    label: const Text(
                      "Poursuivre",
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                    ),
                  ),
                ),
              ],
              SizedBox(height: size.height * 0.06),
            ],
          ),
        ),
      ),
    );
  }
}
