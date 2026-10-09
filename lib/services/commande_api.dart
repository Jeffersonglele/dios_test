import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'node_auth_service.dart';
import 'node_order_service.dart';
import 'session_service.dart';

class CommandeApi {
  const CommandeApi._();

  static Future<bool> verifyPickupOtp({
    required int orderId,
    required String otp,
  }) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      final session = await SessionService.readSession();
      final allOrders = await NodeOrderService.listForRestaurant(
        token: nodeToken,
        restaurateurId: session.userId,
        restaurantId: session.restaurantId,
      );
      Map<String, dynamic>? match;
      for (final o in allOrders) {
        if (o['orderId']?.toString() == orderId.toString()) {
          match = o;
          break;
        }
      }
      final uuid = match?['id']?.toString();
      if (uuid == null || uuid.isEmpty) {
        throw StateError('Commande Node introuvable pour vérification OTP.');
      }
      final response = await NodeAuthService.postJson(
        '/orders/$uuid/verify-pickup-otp',
        token: nodeToken,
        body: {'otp': otp.trim().toUpperCase()},
      );
      final data = response['data'];
      if (data is Map) {
        final ok = data['verified'] ?? data['success'];
        if (ok == true) return true;
      }
      return false;
    }
    final cloudFunction = ParseCloudFunction('verifyPickupOtp');
    final response = await cloudFunction.execute(parameters: {
      'commandeID': orderId,
      'otp': otp.trim().toUpperCase(),
    });
    if (!response.success) {
      throw Exception("Erreur cloud: ${response.error?.message ?? 'Inconnue'}");
    }
    final result = response.result as Map<String, dynamic>;
    return result['verified'] == true || result['success'] == true;
  }

  static Future<void> updateOrderStatus(
      String commandeId, String status) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      final session = await SessionService.readSession();
      final isRestaurantOwner =
          session.role.isProfessional || session.restaurantId != null;

      final userOrders = await NodeOrderService.listMine(
        token: nodeToken,
        userId: session.userId,
      );
      final restaurantOrders = isRestaurantOwner
          ? await NodeOrderService.listForRestaurant(
              token: nodeToken,
              restaurateurId: session.userId,
              restaurantId: session.restaurantId,
            )
          : const <Map<String, dynamic>>[];
      final isDeliverer = session.role.isDelivery;
      final delivererOrders = isDeliverer
          ? await NodeOrderService.listForDeliverer(
              token: nodeToken,
              delivererId: session.userId,
            )
          : const <Map<String, dynamic>>[];
      final orders = NodeOrderService.mergeOrders(
        NodeOrderService.mergeOrders(userOrders, restaurantOrders),
        delivererOrders,
      );
      Map<String, dynamic>? order;
      for (final candidate in orders) {
        if (candidate['orderId']?.toString() == commandeId) {
          order = candidate;
          break;
        }
      }
      final uuid = order?['id']?.toString();
      if (uuid == null || uuid.isEmpty) {
        throw StateError('Commande Node introuvable.');
      }

      final mappedStatus = _mapStatusForBackend(status, isRestaurantOwner);
      await NodeOrderService.updateStatus(
        token: nodeToken,
        orderId: uuid,
        status: mappedStatus,
      );
      return;
    }
    // Utiliser Parse Cloud Function au lieu de HTTP direct
    final cloudFunction = ParseCloudFunction('updateOrderStatus');
    final response = await cloudFunction.execute(parameters: {
      'commandeID': int.tryParse(commandeId),
      'status': status,
    });

    if (!response.success) {
      throw Exception("Erreur cloud: ${response.error?.message ?? 'Inconnue'}");
    }

    final result = response.result as Map<String, dynamic>;
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Erreur inconnue');
    }
  }

  static String _mapStatusForBackend(String status, bool isRestaurantOwner) {
    final normalized = status.toLowerCase().trim();

    if (isRestaurantOwner) {
      if (normalized == 'confirmée' || normalized == 'confirmee' || normalized == 'confirmed' || normalized == 'en_preparation' || normalized == 'en préparation') {
        return 'EN_PREPARATION';
      }
      if (normalized == 'annulée' || normalized == 'annulee' || normalized == 'cancelled' || normalized == 'canceled' || normalized == 'refusé' || normalized == 'refuse' || normalized == 'refusée') {
        return 'REFUSED';
      }
      if (normalized == 'prête' || normalized == 'prete' || normalized == 'ready') {
        return 'READY';
      }
    } else {
      if (normalized == 'annulée' || normalized == 'annulee' || normalized == 'cancelled' || normalized == 'canceled') {
        return 'CANCELLED';
      }
      if (normalized == 'confirmée' || normalized == 'confirmee' || normalized == 'confirmed') {
        return 'CONFIRMED';
      }
    }

    return status.toUpperCase();
  }
}
