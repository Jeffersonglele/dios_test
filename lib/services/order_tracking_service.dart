import 'package:latlong2/latlong.dart';

import 'node_auth_service.dart';
import 'session_service.dart';

/// Livreur assigné à une commande, tel que le client et le restaurant le
/// voient : photo, nom, véhicule et plaque (jamais ses documents).
class CourierProfile {
  const CourierProfile({
    required this.userId,
    required this.displayName,
    this.firstname = '',
    this.lastname = '',
    this.photoUrl,
    this.phone,
    this.vehicleType,
    this.vehiclePlate,
    this.position,
    this.positionAt,
  });

  final int userId;
  final String displayName;
  final String firstname;
  final String lastname;
  final String? photoUrl;
  final String? phone;

  /// moto, velo ou voiture.
  final String? vehicleType;
  final String? vehiclePlate;

  /// Dernière position connue (avant la première mise à jour en direct).
  final LatLng? position;
  final DateTime? positionAt;

  String get initials {
    final letters = [firstname, lastname]
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim()[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  factory CourierProfile.fromMap(Map<String, dynamic> map) {
    String? text(String key) {
      final v = map[key]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return CourierProfile(
      userId: int.tryParse('${map['userId']}') ?? 0,
      displayName: text('displayName') ?? 'Livreur',
      firstname: text('firstname') ?? '',
      lastname: text('lastname') ?? '',
      photoUrl: text('photoUrl'),
      phone: text('phone'),
      vehicleType: text('vehicleType'),
      vehiclePlate: text('vehiclePlate'),
      position: OrderTracking._point(map['latitude'], map['longitude']),
      positionAt: DateTime.tryParse('${map['locationAt']}'),
    );
  }
}

/// Point d'une course (restaurant ou client).
class TrackingPlace {
  const TrackingPlace({this.name, this.address, this.image, this.position});
  final String? name;
  final String? address;
  final String? image;
  final LatLng? position;

  factory TrackingPlace.fromMap(Map<String, dynamic> map) => TrackingPlace(
        name: map['name']?.toString(),
        address: map['address']?.toString(),
        image: map['image']?.toString(),
        position: OrderTracking._point(map['latitude'], map['longitude']),
      );
}

/// Suivi d'une commande renvoyé par `GET /orders/:id/tracking`.
class OrderTracking {
  const OrderTracking({
    required this.orderId,
    this.deliveryStatus,
    this.pickup,
    this.destination,
    this.courier,
    this.viewer = 'customer',
  });

  final int orderId;
  final String? deliveryStatus;
  final TrackingPlace? pickup;
  final TrackingPlace? destination;
  final CourierProfile? courier;

  /// Rôle de celui qui consulte : courier, restaurant, customer ou admin.
  final String viewer;

  static LatLng? _point(dynamic lat, dynamic lng) {
    final la = double.tryParse('$lat');
    final lo = double.tryParse('$lng');
    if (la == null || lo == null) return null;
    if (la.abs() > 90 || lo.abs() > 180 || (la == 0 && lo == 0)) return null;
    return LatLng(la, lo);
  }

  factory OrderTracking.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? obj(String key) => map[key] is Map
        ? Map<String, dynamic>.from(map[key] as Map)
        : null;
    final pickup = obj('pickup');
    final destination = obj('destination');
    final courier = obj('courier');
    return OrderTracking(
      orderId: int.tryParse('${map['orderId']}') ?? 0,
      deliveryStatus: map['deliveryStatus']?.toString(),
      pickup: pickup == null ? null : TrackingPlace.fromMap(pickup),
      destination:
          destination == null ? null : TrackingPlace.fromMap(destination),
      courier: courier == null ? null : CourierProfile.fromMap(courier),
      viewer: map['viewer']?.toString() ?? 'customer',
    );
  }
}

class OrderTrackingService {
  const OrderTrackingService._();

  /// null si hors ligne ou si la commande n'est pas accessible.
  static Future<OrderTracking?> fetch(int orderId) async {
    final token = await SessionService.readNodeToken();
    if (token == null || orderId <= 0) return null;
    try {
      final response =
          await NodeAuthService.getJson('/orders/$orderId/tracking', token: token);
      final data = response['data'];
      if (data is! Map) return null;
      return OrderTracking.fromMap(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }
}
