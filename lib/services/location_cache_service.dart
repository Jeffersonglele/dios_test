import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'geocoding_api_service.dart';

/// Service Singleton de mise en cache de la géolocalisation utilisateur.
/// Évite de solliciter le capteur GPS et l'API de géocodage à chaque navigation.
/// TTL par défaut : 10 minutes.
///
/// Notifie ses écouteurs dès que l'adresse textuelle est connue : le géocodage
/// inverse se termine APRÈS [getPosition], les écrans (header de l'accueil)
/// doivent donc écouter le service plutôt que lire le cache une seule fois.
class LocationCacheService extends ChangeNotifier {
  LocationCacheService._();
  static final LocationCacheService instance = LocationCacheService._();

  static const Duration defaultTtl = Duration(minutes: 10);

  Position? _cachedPosition;
  String? _cachedDisplayName;
  String? _cachedShortLabel;
  String? _cachedCity;
  String? _cachedCountry;
  DateTime? _lastFetchTime;
  Future<void>? _pendingGeocode;

  Position? get cachedPosition => _cachedPosition;
  String? get cachedDisplayName => _cachedDisplayName;

  /// Libellé court pour un header : « Avenue X, Gombe ».
  String? get cachedShortLabel => _cachedShortLabel;
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
      _cachedShortLabel = shortLabelFrom(displayName);
    }
    if (city != null && city.trim().isNotEmpty) {
      _cachedCity = city.trim();
    }
    if (country != null && country.trim().isNotEmpty) {
      _cachedCountry = country.trim();
    }
    _lastFetchTime = DateTime.now();
    notifyListeners();
  }

  /// Vide le cache
  void clear() {
    _cachedPosition = null;
    _cachedDisplayName = null;
    _cachedShortLabel = null;
    _cachedCity = null;
    _cachedCountry = null;
    _lastFetchTime = null;
    _pendingGeocode = null;
    notifyListeners();
  }

  /// Attend la fin du géocodage inverse en cours, s'il y en a un.
  Future<void> waitForAddress() => _pendingGeocode ?? Future<void>.value();

  /// Récupère la position utilisateur avec gestion du cache (TTL = 10 min)
  /// et cascade robuste GPS -> LastKnown -> Reverse Geocoding.
  Future<Position?> getPosition({bool forceRefresh = false}) async {
    if (!forceRefresh && hasValidCache) {
      // Position récente mais adresse jamais obtenue (réseau coupé au
      // premier essai) : on relance uniquement le géocodage.
      if (_cachedDisplayName == null) {
        _startReverseGeocode(_cachedPosition!);
      }
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
      notifyListeners();

      // Reverse geocoding en tâche de fond pour l'adresse textuelle.
      // Les écouteurs sont notifiés à la fin ; voir aussi [waitForAddress].
      _startReverseGeocode(pos);

      return pos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationCacheService] Erreur récupération position : $e');
      }
      return _cachedPosition;
    }
  }

  void _startReverseGeocode(Position pos) {
    _pendingGeocode ??= _reverseGeocode(pos.latitude, pos.longitude)
        .whenComplete(() => _pendingGeocode = null);
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final result = await GeocodingApiService.reverse(lat, lon);
      if (result.displayName != null && result.displayName!.isNotEmpty) {
        _cachedDisplayName = result.displayName;
      }
      _cachedShortLabel = _shortLabel(result) ?? _cachedShortLabel;
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
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationCacheService] Reverse geocode background error: $e');
      }
    }
  }

  /// « 12 Avenue X, Gombe » à partir des composants détaillés, sinon les
  /// deux premiers segments du nom complet.
  static String? _shortLabel(GeocodingResult r) {
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    final street = clean(r.street);
    final number = clean(r.thoroughfare);
    final line1 = street == null
        ? null
        : (number != null && !street.startsWith(number)
            ? '$number $street'
            : street);
    final area = clean(r.subLocality) ?? clean(r.locality);
    final parts = [line1, area].whereType<String>().toSet().toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return shortLabelFrom(r.displayName);
  }

  /// Garde les deux premiers segments d'une adresse « a, b, c, d ».
  static String? shortLabelFrom(String? fullAddress) {
    if (fullAddress == null) return null;
    final parts = fullAddress
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
