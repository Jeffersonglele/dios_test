import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'geocoding_api_service.dart';

/// Service Singleton de mise en cache de la géolocalisation utilisateur.
/// Évite de solliciter le capteur GPS et l'API de géocodage à chaque navigation.
/// TTL par défaut : 10 minutes.
class LocationCacheService {
  LocationCacheService._();
  static final LocationCacheService instance = LocationCacheService._();

  static const Duration defaultTtl = Duration(minutes: 10);

  Position? _cachedPosition;
  String? _cachedDisplayName;
  String? _cachedCity;
  String? _cachedCountry;
  DateTime? _lastFetchTime;

  Position? get cachedPosition => _cachedPosition;
  String? get cachedDisplayName => _cachedDisplayName;
  String? get cachedCity => _cachedCity;
  String? get cachedCountry => _cachedCountry;
  DateTime? get lastFetchTime => _lastFetchTime;

  bool get hasValidCache {
    if (_cachedPosition == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < defaultTtl;
  }

  /// Met à jour manuellement le cache (ex: après sélection ou géocodage dans le panier)
  void updateCache({
    required Position position,
    String? displayName,
    String? city,
    String? country,
  }) {
    _cachedPosition = position;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _cachedDisplayName = displayName.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      _cachedCity = city.trim();
    }
    if (country != null && country.trim().isNotEmpty) {
      _cachedCountry = country.trim();
    }
    _lastFetchTime = DateTime.now();
  }

  /// Vide le cache
  void clear() {
    _cachedPosition = null;
    _cachedDisplayName = null;
    _cachedCity = null;
    _cachedCountry = null;
    _lastFetchTime = null;
  }

  /// Récupère la position utilisateur avec gestion du cache (TTL = 10 min)
  /// et cascade robuste GPS -> LastKnown -> Reverse Geocoding.
  Future<Position?> getPosition({bool forceRefresh = false}) async {
    if (!forceRefresh && hasValidCache) {
      return _cachedPosition;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Si le service est désactivé mais qu'on a déjà une position en cache, on la garde
        return _cachedPosition;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _cachedPosition;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        // En cas de timeout ou erreur, fallback sur la dernière position connue
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        return _cachedPosition;
      }

      _cachedPosition = pos;
      _lastFetchTime = DateTime.now();

      // Reverse geocoding en tâche de fond pour l'adresse textuelle
      _reverseGeocodeInBackground(pos.latitude, pos.longitude);

      return pos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationCacheService] Erreur récupération position : $e');
      }
      return _cachedPosition;
    }
  }

  Future<void> _reverseGeocodeInBackground(double lat, double lon) async {
    try {
      final result = await GeocodingApiService.reverse(lat, lon);
      if (result.displayName != null && result.displayName!.isNotEmpty) {
        _cachedDisplayName = result.displayName;
      }
      final city = result.locality ??
          result.subAdministrativeArea ??
          result.administrativeArea;
      if (city != null && city.isNotEmpty) {
        _cachedCity = city;
      }
      final country = result.country ?? result.countryCode;
      if (country != null && country.isNotEmpty) {
        _cachedCountry = country;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationCacheService] Reverse geocode background error: $e');
      }
    }
  }
}
