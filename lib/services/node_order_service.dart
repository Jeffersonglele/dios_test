import '../models/commande.dart';
import 'node_auth_service.dart';

class NodeOrderService {
  const NodeOrderService._();

  static Future<Map<String, dynamic>> create({
    required String token,
    required int userId,
    required int restaurantId,
    required List<Map<String, dynamic>> lines,
    required String deliveryMode,
    int? addressId,
    String paymentMethod = 'CASH',
    double reduction = 0,
    String? promoCode,
    int? cityId,
  }) async {
    final response = await NodeAuthService.postJson(
      '/orders',
      token: token,
      body: {
        'order': {
          'userId': userId,
          'restaurantId': restaurantId,
          'deliveryMode':
              deliveryMode == 'À Emporter' || deliveryMode.toUpperCase() == 'PICKUP'
                  ? 'PICKUP'
                  : 'DELIVERY',
          'paymentMethod': paymentMethod,
          if (addressId != null) 'deliveryAddressId': addressId,
          if (reduction > 0) 'reduction': reduction,
          if (promoCode?.trim().isNotEmpty == true) 'promoCode': promoCode,
          if (cityId != null) 'cityId': cityId,
        },
        'lines': lines,
      },
    );
    final data = response['data'];
    if (data is! Map) {
      throw const NodeAuthException('Réponse de commande invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> quoteDelivery({
    required String token,
    required int restaurantId,
    required int addressId,
  }) async {
    final response = await NodeAuthService.postJson(
      '/delivery/quote',
      token: token,
      body: {'restaurantId': restaurantId, 'addressId': addressId},
    );
    final data = response['data'];
    if (data is! Map) {
      throw const NodeAuthException('Réponse de livraison invalide.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Map<String, dynamic>>> listMine({
    required String token,
    required int userId,
  }) async {
    final response = await NodeAuthService.getJson(
      '/orders',
      token: token,
      queryParameters: {'userId': '$userId', 'pageSize': '100'},
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<Map<String, dynamic>> updateStatus({
    required String token,
    required String orderId,
    required String status,
  }) async {
    final response = await NodeAuthService.patchJson(
      '/orders/$orderId/status',
      token: token,
      body: {'status': status},
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  static Future<Map<String, dynamic>> initializeNyole({
    required String token,
    required String orderUuid,
  }) async {
    final response = await NodeAuthService.postJson(
      '/payments/nyole/initialize',
      token: token,
      body: {'orderId': orderUuid},
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  static Commande toLegacyCommande(Map<String, dynamic> order) {
    final rawDate = order['orderedAt'] ?? order['dateCommande'];
    final date = DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final id = int.tryParse(
          (order['orderId'] ?? order['commandeID'] ?? order['id']).toString(),
        ) ??
        0;
    return Commande(
      commandeID: id,
      userID: _int(order['userId'] ?? order['userID']),
      restauID: _int(order['restaurantId'] ?? order['restauID']),
      restaurateurID: _int(order['restaurateurId'] ?? order['restaurateurID']),
      moyenPaiementID: _int(order['paymentMethodId'] ?? order['moyenPaiementID']),
      fraisLivraison: _double(order['deliveryFee'] ?? order['fraisLivraison']),
      reduction: _double(order['reduction'] ?? order['globalReduction']),
      dateCommande: date,
      heure: order['orderedTime']?.toString() ?? _time(date),
      addressID: _nullableInt(order['deliveryAddressId'] ?? order['addressId']),
      status: order['status']?.toString() ?? 'PENDING',
      deliveryStatus: order['deliveryStatus']?.toString(),
      livreurID: _nullableInt(order['delivererId'] ?? order['livreurID']),
      livreurLat: _nullableDouble(order['delivererLatitude'] ?? order['livreurLat']),
      livreurLng: _nullableDouble(order['delivererLongitude'] ?? order['livreurLng']),
      cityID: _int(order['cityId'] ?? order['cityID'], fallback: 1),
      totalAmount: _double(order['totalAmount']),
      subtotalAmount: _double(order['subtotalAmount']),
      deliveryMode: order['deliveryMode']?.toString(),
      country: order['country']?.toString() ?? 'RDC',
      paymentStatus: order['paymentProvider']?.toString(),
    );
  }

  static int _int(Object? value, {int fallback = 0}) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  static int? _nullableInt(Object? value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed == 0 ? null : parsed;
  }

  static double _double(Object? value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static double? _nullableDouble(Object? value) =>
      value == null ? null : double.tryParse(value.toString());

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
