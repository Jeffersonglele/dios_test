import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import 'node_auth_service.dart';
import 'session_service.dart';

class GeocodingResult {
  const GeocodingResult({
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.displayName,
    this.street,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.administrativeArea,
    this.country,
    this.countryCode,
    this.postalCode,
    this.thoroughfare,
    this.raw,
  });

  final double latitude;
  final double longitude;
  final String? placeId;
  final String? displayName;
  final String? street;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? administrativeArea;
  final String? country;
  final String? countryCode;
  final String? postalCode;
  final String? thoroughfare;
  final Map<String, dynamic>? raw;
}

class SearchResult {
  const SearchResult({
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.displayName,
    this.city,
    this.country,
    this.countryCode,
    this.type,
    this.classTag,
    this.address,
    this.raw,
  });

  final double latitude;
  final double longitude;
  final String? placeId;
  final String? displayName;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? type;
  final String? classTag;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? raw;
}

/// Service de géocodage qui préfère le backend Dios Delices (Nominatim + cache
/// PostGIS) et retombe sur le plugin `geocoding` local si le serveur est
/// indisponible. Garantit une disponibilité offline minimale.
class GeocodingApiService {
  const GeocodingApiService._();

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Reverse géocodage : coordonnées GPS → adresse textuelle.
  ///
  /// Priorité : backend `/geocoding/reverse` → fallback plugin `geocoding`.
  static Future<GeocodingResult> reverse(
    double latitude,
    double longitude, {
    List<String>? countryCodes,
  }) async {
    GeocodingResult? result;
    try {
      result = await _reverseViaApi(latitude, longitude, countryCodes: countryCodes);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[GeocodingApiService.reverse] API indisponible : $error\n'
            'Fall back sur le plugin geocoding.\n$stack');
      }
    }
    if (result != null) return result;

    return _reverseViaPlugin(latitude, longitude);
  }

  /// Recherche textuelle d'adresse.
  ///
  /// Priorité : backend `/geocoding/search` → fallback plugin `geocoding`.
  static Future<List<SearchResult>> search(
    String query, {
    int limit = 5,
    List<String>? countryCodes,
  }) async {
    List<SearchResult>? result;
    try {
      result = await _searchViaApi(query, limit: limit, countryCodes: countryCodes);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('[GeocodingApiService.search] API indisponible : $error\n'
            'Fall back sur le plugin geocoding.\n$stack');
      }
    }
    if (result != null) return result;

    return _searchViaPlugin(query, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Implémentation via API Node.js
  // ---------------------------------------------------------------------------

  static Future<GeocodingResult> _reverseViaApi(
    double latitude,
    double longitude, {
    List<String>? countryCodes,
  }) async {
    final token = await SessionService.readNodeToken();
    if (token == null || token.trim().isEmpty) {
      throw const NodeAuthException("Aucun jeton d'authentification.");
    }
    final queryParameters = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (countryCodes != null && countryCodes.isNotEmpty)
        'countryCodes': countryCodes.join(','),
    };
    final response = await NodeAuthService.getJson(
      '/geocoding/reverse',
      token: token,
      queryParameters: queryParameters,
    );
    final envelope = response['data'];
    if (envelope is! Map) {
      throw const NodeAuthException('Réponse de géocodage invalide.');
    }
    final inner = envelope['result'];
    if (inner is! Map || inner.isEmpty) {
      throw const NodeAuthException('Aucun résultat de géocodage.');
    }
    final lat = _parseDouble(inner['latitude']);
    final lng = _parseDouble(inner['longitude']);
    if (lat == null || lng == null) {
      throw const NodeAuthException('Coordonnées manquantes dans la réponse.');
    }
    final address = inner['address'] is Map
        ? Map<String, dynamic>.from(inner['address'] as Map)
        : const <String, dynamic>{};
    return GeocodingResult(
      latitude: lat,
      longitude: lng,
      placeId: inner['placeId']?.toString(),
      displayName: inner['displayName']?.toString(),
      street: _firstNonEmpty([
        address['road'],
        address['street'],
        address['footway'],
        address['pedestrian'],
        address['path'],
      ]),
      subLocality: _firstNonEmpty([
        address['neighbourhood'],
        address['quarter'],
        address['suburb'],
        address['city_district'],
      ]),
      locality: _firstNonEmpty([
        address['city'],
        address['town'],
        address['village'],
        address['municipality'],
      ]),
      subAdministrativeArea: _firstNonEmpty([
        address['county'],
        address['state_district'],
      ]),
      administrativeArea: _firstNonEmpty([
        address['state'],
        address['region'],
        address['province'],
      ]),
      country: _firstNonEmpty([address['country']]),
      countryCode: address['country_code']?.toString().toLowerCase(),
      postalCode: _firstNonEmpty([address['postcode']]),
      thoroughfare: _firstNonEmpty([address['house_number'], address['conscription_number']]),
      raw: Map<String, dynamic>.from(inner),
    );
  }

  static Future<List<SearchResult>> _searchViaApi(
    String query, {
    required int limit,
    List<String>? countryCodes,
  }) async {
    final token = await SessionService.readNodeToken();
    if (token == null || token.trim().isEmpty) {
      throw const NodeAuthException("Aucun jeton d'authentification.");
    }
    final safeLimit = limit < 1 ? 5 : (limit > 10 ? 10 : limit);
    final queryParameters = <String, String>{
      'q': query.trim(),
      'limit': safeLimit.toString(),
      if (countryCodes != null && countryCodes.isNotEmpty)
        'countryCodes': countryCodes.join(','),
    };
    final response = await NodeAuthService.getJson(
      '/geocoding/search',
      token: token,
      queryParameters: queryParameters,
    );
    final envelope = response['data'];
    final rows = envelope is Map ? envelope['results'] : null;
    if (rows is! List) return const [];
    final out = <SearchResult>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final lat = _parseDouble(row['latitude']);
      final lng = _parseDouble(row['longitude']);
      if (lat == null || lng == null) continue;
      final address = row['address'] is Map
          ? Map<String, dynamic>.from(row['address'] as Map)
          : const <String, dynamic>{};
      out.add(SearchResult(
        latitude: lat,
        longitude: lng,
        placeId: row['placeId']?.toString(),
        displayName: row['displayName']?.toString(),
        city: _firstNonEmpty([
          address['city'],
          address['town'],
          address['village'],
          address['municipality'],
        ]),
        country: _firstNonEmpty([address['country']]),
        countryCode: address['country_code']?.toString().toLowerCase(),
        type: row['type']?.toString(),
        classTag: row['class']?.toString(),
        address: address,
        raw: Map<String, dynamic>.from(row),
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Implémentation fallback via plugin geocoding (OS / locale)
  // ---------------------------------------------------------------------------

  static Future<GeocodingResult> _reverseViaPlugin(
    double latitude,
    double longitude,
  ) async {
    final placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
    final p = placemarks.isNotEmpty ? placemarks.first : const geo.Placemark();
    return GeocodingResult(
      latitude: latitude,
      longitude: longitude,
      placeId: null,
      displayName: _firstNonEmpty([
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ]),
      street: (p.street ?? '').trim().isNotEmpty ? p.street!.trim() : null,
      subLocality: (p.subLocality ?? '').trim().isNotEmpty ? p.subLocality!.trim() : null,
      locality: (p.locality ?? '').trim().isNotEmpty ? p.locality!.trim() : null,
      subAdministrativeArea: (p.subAdministrativeArea ?? '').trim().isNotEmpty
          ? p.subAdministrativeArea!.trim()
          : null,
      administrativeArea: (p.administrativeArea ?? '').trim().isNotEmpty
          ? p.administrativeArea!.trim()
          : null,
      country: (p.country ?? '').trim().isNotEmpty ? p.country!.trim() : null,
      countryCode: (p.isoCountryCode ?? '').trim().isNotEmpty
          ? p.isoCountryCode!.trim().toLowerCase()
          : null,
      postalCode: (p.postalCode ?? '').trim().isNotEmpty ? p.postalCode!.trim() : null,
      thoroughfare: (p.thoroughfare ?? '').trim().isNotEmpty
          ? p.thoroughfare!.trim()
          : null,
      raw: null,
    );
  }

  static Future<List<SearchResult>> _searchViaPlugin(
    String query, {
    required int limit,
  }) async {
    final locations = await geo.locationFromAddress(query);
    final out = <SearchResult>[];
    final safeLimit = limit < 1 ? 5 : limit;
    for (final loc in locations.take(safeLimit)) {
      out.add(SearchResult(
        latitude: loc.latitude,
        longitude: loc.longitude,
        placeId: null,
        displayName: query,
        city: null,
        country: null,
        countryCode: null,
        type: null,
        classTag: null,
        address: null,
        raw: null,
      ));
    }
    return out;
  }
}
