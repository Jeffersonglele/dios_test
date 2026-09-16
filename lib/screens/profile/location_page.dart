import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/address.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/session_service.dart';

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
  String? _detectedCity;
  String? _detectedCountry;

  TextEditingController locationController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController fullAddressController = TextEditingController();

  Future<void> getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      print('Starting location detection...');

      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        if (mounted) {
          Toast(
              context, AppLocalizations.of(context)!.location_disabled, false);
        }
        return;
      }

      print('Location services are enabled');

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('New permission status after request: $permission');
        if (permission == LocationPermission.denied) {
          if (mounted) {
            Toast(context, AppLocalizations.of(context)!.location_disabled,
                false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          Toast(
              context, AppLocalizations.of(context)!.location_disabled, false);
        }
        return;
      }

      print('Permissions are granted');

      // Essayer d'obtenir la position actuelle
      Position? newPosition;
      try {
        print('Trying to get current position...');
        newPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15));
        print('Got current position: $newPosition');
      } catch (e) {
        print('Error getting current position: $e');
        // Si ça échoue, essayer de récupérer la dernière position connue
        print('Trying to get last known position...');
        newPosition = await Geolocator.getLastKnownPosition();
        print('Last known position: $newPosition');
      }

      if (newPosition == null) {
        print('Could not get any position');
        if (mounted) {
          Toast(context, AppLocalizations.of(context)!.location_detect_failed,
              false);
        }
        return;
      }

      print('Trying to get address from coordinates...');
      List<Placemark> placeMarks = [];
      try {
        placeMarks = await placemarkFromCoordinates(
            newPosition.latitude, newPosition.longitude);
        print('Got ${placeMarks.length} placemarks');
      } catch (e) {
        print('Error getting placemarks: $e');
      }

      if (placeMarks.isNotEmpty) {
        Placemark pMarks = placeMarks[0];
        print('Placemark: $pMarks');

        _detectedCity = _firstNonEmpty([
          pMarks.locality,
          pMarks.subAdministrativeArea,
          pMarks.administrativeArea,
        ]);
        _detectedCountry = _firstNonEmpty([pMarks.country]);
        completeAddress = _joinAddressParts([
          pMarks.thoroughfare,
          pMarks.subLocality,
          pMarks.locality,
          pMarks.administrativeArea,
          pMarks.country,
        ]);
        // Certains résultats de géocodage contiennent des champs vides.
        // Les coordonnées restent néanmoins une adresse de livraison valide.
        if (completeAddress!.isEmpty) {
          completeAddress = _gpsAddress(newPosition);
        }
        locationController.text = completeAddress!;
        print('Complete address: $completeAddress');
      } else {
        print('No placemarks found');
        _setGpsAddress(newPosition);
        if (mounted) {
          Toast(
              context,
              'Position GPS détectée. L\'adresse exacte est indisponible.',
              false);
        }
      }
      if (mounted) setState(() => position = newPosition);
    } catch (e) {
      print('Unexpected error: $e');
      if (mounted) {
        Toast(context, 'Erreur inattendue: $e', false);
      }
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

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _joinAddressParts(List<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      if (value == null || value.trim().isEmpty) continue;
      final part = value.trim();
      if (!parts.any((existing) =>
          existing.toLowerCase() == part.toLowerCase())) {
        parts.add(part);
      }
    }
    return parts.join(', ');
  }

  String _gpsAddress(Position gpsPosition) =>
      'Position GPS : ${gpsPosition.latitude.toStringAsFixed(6)}, '
      '${gpsPosition.longitude.toStringAsFixed(6)}';

  void _setGpsAddress(Position gpsPosition) {
    _detectedCity = null;
    _detectedCountry = null;
    completeAddress = _gpsAddress(gpsPosition);
    locationController.text = completeAddress!;
  }

  void saveDetectedAddress() async {
    final session = await SessionService.readSession();
    final userCountry = session.country.trim().toLowerCase();
    final city = _firstNonEmpty([
          _detectedCity,
          _extractCity(),
          cityController.text,
        ]) ??
        '';
    final state = _firstNonEmpty([
          _detectedCountry,
          _extractState(),
          stateController.text,
          session.country,
        ]) ??
        '';
    final fullAddress =
        locationController.text.isNotEmpty
            ? locationController.text
            : position == null
                ? ''
                : _gpsAddress(position!);
    final lat = position?.latitude.toString();
    final long = position?.longitude.toString();

    // Vérifier que le pays détecté correspond au pays de l'utilisateur
    if (_detectedCountry != null &&
        state.trim().isNotEmpty &&
        userCountry.isNotEmpty) {
      final stateLower = state.trim().toLowerCase();
      if (!stateLower.contains(userCountry) &&
          !userCountry.contains(stateLower)) {
        Toast(
            context,
            AppLocalizations.of(context)!
                .address_not_match_country(state.trim()),
            false);
        setState(() => _isSaving = false);
        return;
      }
    }

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
        Toast(
            context, AppLocalizations.of(context)!.address_already_saved, true);
        return;
      }

      if (validationResult is int) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);
        Toast(
            context, AppLocalizations.of(context)!.address_saved_success, true);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        Toast(context, validationResult, false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void saveManualAddress() async {
    final session = await SessionService.readSession();
    final userCountry = session.country.trim();
    final city = cityController.text.trim();
    final quarter = stateController.text.trim();
    final fullAddress = fullAddressController.text.trim();

    if (city.isEmpty || fullAddress.isEmpty) {
      Toast(context,
          AppLocalizations.of(context)!.address_fill_city_and_address, false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Géocodage adapté : adresse complète + quartier + ville + pays
      final query = [fullAddress, quarter, city, userCountry]
          .where((s) => s.isNotEmpty)
          .join(', ');
      List<Location> locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        // Réessayer sans le quartier
        final query2 = [fullAddress, city, userCountry]
            .where((s) => s.isNotEmpty)
            .join(', ');
        locations = await locationFromAddress(query2);
      }
      if (locations.isEmpty) {
        Toast(context, AppLocalizations.of(context)!.address_not_found_check,
            false);
        return;
      }

      double lat = locations.first.latitude;
      double long = locations.first.longitude;

      dynamic validationResult = await Address.manageAddress(
        city: city,
        state: quarter.isNotEmpty ? quarter : userCountry,
        fullAddress: fullAddress,
        lat: lat.toString(),
        object: "User",
        objectID: widget.objectID,
        long: long.toString(),
        user_roleID: widget.user_roleID,
      );

      if (validationResult == "EXISTING_ADDRESS") {
        setState(() => addressExists = true);
        Toast(
            context, AppLocalizations.of(context)!.address_already_saved, true);
        return;
      }

      if (validationResult is int) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('userVerified', true);
        Toast(
            context, AppLocalizations.of(context)!.address_saved_success, true);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        Toast(context, validationResult, false);
      }
    } catch (e) {
      Toast(context, AppLocalizations.of(context)!.address_not_found_verify,
          false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
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
              if (!isWide) const Center(child: BrandAvatarLogo()),
              SizedBox(height: size.height * 0.03),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  l10n.location_my_address,
                  style: AppTypography.displayMedium(),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  l10n.location_instruction,
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
                    _isLocating ? l10n.location_locating : l10n.location_get,
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
                  labelText: l10n.address_detected,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: locationController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            locationController.clear();
                            position = null;
                            completeAddress = null;
                            _detectedCity = null;
                            _detectedCountry = null;
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      showManualEntry = !showManualEntry;
                      if (showManualEntry) {
                        // Fermer l'adresse détectée
                        locationController.clear();
                        position = null;
                        completeAddress = null;
                        _detectedCity = null;
                        _detectedCountry = null;
                      }
                    });
                  },
                  icon: Icon(
                    showManualEntry
                        ? Icons.expand_less
                        : Icons.edit_location_alt_outlined,
                  ),
                  label: Text(
                    showManualEntry
                        ? l10n.hide_form
                        : l10n.enter_address_manually,
                  ),
                ),
              ),
              if (showManualEntry) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: l10n.city,
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
                    labelText: l10n.district,
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
                    labelText: l10n.full_address_hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      cityController.clear();
                      stateController.clear();
                      fullAddressController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.clear),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkMuted),
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
                      : () async {
                          final hasDetected = position != null;
                          final hasManual =
                              fullAddressController.text.isNotEmpty ||
                                  cityController.text.isNotEmpty ||
                                  stateController.text.isNotEmpty;

                          if (!hasDetected && !hasManual) {
                            Toast(
                                context,
                                AppLocalizations.of(context)!
                                    .enter_or_detect_address,
                                false);
                            return;
                          }

                          if (hasDetected && hasManual) {
                            // Les deux sont disponibles → demander à l'user
                            final choice = await showDialog<String>(
                              context: context,
                              builder: (ctx) {
                                final dl10n = AppLocalizations.of(ctx)!;
                                return AlertDialog(
                                  title: Text(dl10n.which_address_use),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(dl10n.address_detected_label,
                                          style: AppTypography.labelMedium()),
                                      Text(locationController.text,
                                          style: AppTypography.bodyMedium()),
                                      const SizedBox(height: 12),
                                      Text(dl10n.address_manual_label,
                                          style: AppTypography.labelMedium()),
                                      Text(
                                          '${fullAddressController.text}, ${cityController.text}, ${stateController.text}',
                                          style: AppTypography.bodyMedium()),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'manual'),
                                      child: Text(dl10n.manual),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'detected'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.brand,
                                          foregroundColor: Colors.white),
                                      child: Text(dl10n.detected),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (choice == 'detected') {
                              saveDetectedAddress();
                            } else if (choice == 'manual') {
                              saveManualAddress();
                            }
                          } else if (hasDetected) {
                            saveDetectedAddress();
                          } else {
                            saveManualAddress();
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
                          l10n.save_address,
                          style: const TextStyle(
                            color: AppColors.surface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: size.height * 0.06),
            ],
          ),
        ),
      ),
    );
  }
}
