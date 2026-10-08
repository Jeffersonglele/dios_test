import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session_service.dart';

// ═══════════════════════════════════════════════════════════
// DeliveryOrdersService — « Open Market » du livreur
//   GET  /deliveries/available?lat=&lng=&radiusKm=5
//   POST /deliveries/{orderId}/accept
// (même base URL / même token que WalletService)
// ═══════════════════════════════════════════════════════════

class DeliveryException implements Exception {
  DeliveryException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  /// 409 : un autre livreur a déjà pris la commande.
  bool get isConflict => statusCode == 409;

  /// 403 : plafond d'espèces atteint (reversement nécessaire).
  bool get isCashCeiling => statusCode == 403;

  @override
  String toString() => message;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

String? _firstString(Map j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v != null && v is! Map && v is! List && v.toString().trim().isNotEmpty) {
      return v.toString();
    }
  }
  return null;
}

/// Adresse sous forme de texte (chaîne ou objet {label, street, city…}).
String? _address(dynamic v) {
  if (v == null) return null;
  if (v is Map) {
    final parts = [
      _firstString(v, ['label', 'address', 'street', 'name', 'description']),
      _firstString(v, ['district', 'neighborhood', 'city']),
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class AvailableDelivery {
  const AvailableDelivery({
    required this.routeId,
    required this.orderNumber,
    required this.restaurantName,
    this.pickupAddress,
    this.dropoffAddress,
    this.distanceKm,
    required this.deliveryFee,
    this.totalAmount,
    required this.isCash,
    this.cashToCollect,
    this.currency = 'CDF',
    this.createdAt,
  });

  /// Identifiant utilisé dans l'URL …/deliveries/{routeId}/accept
  final String routeId;
  final String orderNumber;
  final String restaurantName;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? distanceKm;
  final double deliveryFee;
  final double? totalAmount;
  final bool isCash;
  final double? cashToCollect;
  final String currency;
  final DateTime? createdAt;

  factory AvailableDelivery.fromJson(Map<String, dynamic> j) {
    final resto = j['restaurant'] is Map ? j['restaurant'] as Map : const {};
    final payment = (j['paymentMethod'] ?? j['payment'] ?? '').toString();
    final cash = _toDoubleOrNull(j['cashToCollect'] ?? j['cashAmount']);
    final isCash = payment.toUpperCase().contains('CASH') ||
        j['isCash'] == true ||
        (cash != null && cash > 0);
    final total = _toDoubleOrNull(j['totalAmount'] ?? j['total']);
    final numeric = _firstString(j, ['orderId', 'commandeID']);
    final uuid = _firstString(j, ['id']);

    return AvailableDelivery(
      // l'URL attend « orderId » : on privilégie le numéro de commande
      routeId: numeric ?? uuid ?? '',
      orderNumber: numeric ?? uuid ?? '',
      restaurantName: _firstString(resto, ['name']) ??
          _firstString(j, ['restaurantName']) ??
          'Restaurant',
      pickupAddress: _address(
          j['pickupAddress'] ?? resto['address'] ?? j['restaurantAddress']),
      dropoffAddress: _address(
          j['dropoffAddress'] ?? j['deliveryAddress'] ?? j['address']),
      distanceKm: _toDoubleOrNull(j['distanceKm'] ?? j['distance']),
      deliveryFee:
          _toDouble(j['courierFee'] ?? j['deliveryFee'] ?? j['fee']),
      totalAmount: total,
      isCash: isCash,
      cashToCollect: cash ?? (isCash ? total : null),
      currency: _firstString(j, ['currency', 'currencyCode']) ?? 'CDF',
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    );
  }
}

class DeliveryOrdersService {
  DeliveryOrdersService._();

  static Uri _uri(String path) {
    final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/v1$path');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await SessionService.readNodeToken();
    if (token == null || token.isEmpty) {
      throw DeliveryException('Session expirée. Reconnectez-vous.',
          statusCode: 401);
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _message(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final m = body['message'] ?? body['error'];
        if (m != null && m.toString().trim().isNotEmpty) return m.toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DeliveryException {
      rethrow;
    } on TimeoutException {
      throw DeliveryException('Le serveur met trop de temps à répondre.');
    } on SocketException {
      throw DeliveryException('Connexion impossible. Vérifiez votre réseau.');
    } on http.ClientException {
      throw DeliveryException('Connexion impossible. Vérifiez votre réseau.');
    }
  }

  /// GET /deliveries/available?lat={lat}&lng={lng}&radiusKm=5
  /// Version typée qui LÈVE une DeliveryException (utilisée par l'onglet).
  static Future<List<AvailableDelivery>> fetchAvailableDeliveries(
    double lat,
    double lng, {
    int radiusKm = 5,
  }) =>
      _guard(() async {
        final uri = _uri('/deliveries/available').replace(
          queryParameters: {
            'lat': lat.toString(),
            'lng': lng.toString(),
            'radiusKm': radiusKm.toString(),
          },
        );
        final res = await http
            .get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 30));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw DeliveryException(
            _message(res, 'Impossible de charger les commandes disponibles.'),
            statusCode: res.statusCode,
          );
        }

        dynamic data;
        try {
          data = jsonDecode(res.body);
        } catch (_) {
          data = null;
        }
        // { data: [...] } ou { data: { deliveries|orders|items: [...] } } ou [...]
        if (data is Map) data = data['data'] ?? data;
        if (data is Map) {
          data = data['deliveries'] ?? data['orders'] ?? data['items'] ?? [];
        }
        final list = data is List ? data : const [];

        return [
          for (final e in list)
            if (e is Map)
              AvailableDelivery.fromJson(Map<String, dynamic>.from(e)),
        ].where((d) => d.routeId.isNotEmpty).toList();
      });

  /// POST /deliveries/{orderId}/accept
  ///  • 409 → DeliveryException.isConflict   (déjà prise)
  ///  • 403 → DeliveryException.isCashCeiling (plafond d'espèces atteint)
  static Future<Map<String, dynamic>?> acceptOrder(String orderId) =>
      _guard(() async {
        final res = await http
            .post(
              _uri('/deliveries/$orderId/accept'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            final body = jsonDecode(res.body);
            final data = body is Map ? body['data'] : null;
            return data is Map ? Map<String, dynamic>.from(data) : null;
          } catch (_) {
            return null;
          }
        }

        throw DeliveryException(
          _message(
            res,
            res.statusCode == 409
                ? 'Un autre livreur a déjà pris cette commande.'
                : res.statusCode == 403
                    ? 'Plafond d\'espèces atteint. Vous devez effectuer un reversement.'
                    : 'Impossible d\'accepter la course.',
          ),
          statusCode: res.statusCode,
        );
      });

  /// POST /deliveries/{orderId}/arrive
  /// Renvoie l'heure d'arrivée enregistrée par le serveur si elle est fournie
  /// (arrivedAt / arrivalAt), sinon null.
  static Future<DateTime?> arrive(String orderId) => _guard(() async {
        final res = await http
            .post(
              _uri('/deliveries/$orderId/arrive'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw DeliveryException(
            _message(res, "Impossible de confirmer votre arrivée."),
            statusCode: res.statusCode,
          );
        }
        try {
          var body = jsonDecode(res.body);
          if (body is Map) body = body['data'] ?? body;
          if (body is Map) {
            final raw = body['arrivedAt'] ?? body['arrivalAt'];
            return DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
          }
        } catch (_) {}
        return null;
      });

  /// POST /deliveries/{orderId}/client-unreachable
  static Future<void> clientUnreachable(String orderId) => _guard(() async {
        final res = await http
            .post(
              _uri('/deliveries/$orderId/client-unreachable'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw DeliveryException(
            _message(res, 'Impossible de clôturer la course.'),
            statusCode: res.statusCode,
          );
        }
      });

  /// POST /orders/{orderId}/verify-retrieval   { otp, proofPhotoUrl }
  /// 400 → code incorrect (le message du serveur est conservé).
  static Future<void> verifyRetrieval(
    String orderId, {
    required String otp,
    required String proofPhotoUrl,
  }) =>
      _guard(() async {
        final res = await http
            .post(
              _uri('/orders/$orderId/verify-retrieval'),
              headers: await _headers(),
              body: jsonEncode({
                'otp': otp.trim().toUpperCase(),
                'proofPhotoUrl': proofPhotoUrl,
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw DeliveryException(
            _message(
              res,
              res.statusCode == 400
                  ? 'Code incorrect. Vérifiez auprès du client.'
                  : 'La validation a échoué. Réessayez.',
            ),
            statusCode: res.statusCode,
          );
        }
      });

  // ── Vos méthodes d'origine, inchangées ───────────────────

  static Future<List<Map<String, dynamic>>> getAvailableDeliveries({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return [];

      final response = await http.get(
        _uri('/deliveries/available').replace(queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusKm': radiusKm.toString(),
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final deliveries = data['data'] as List?;
        return deliveries?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('Error fetching available deliveries: $e');
      return [];
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
}