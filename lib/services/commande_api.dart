import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'node_order_service.dart';
import 'session_service.dart';

class CommandeApi {
  const CommandeApi._();

  static Future<void> updateOrderStatus(
      String commandeId, String status) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      final session = await SessionService.readSession();
      final orders = await NodeOrderService.listMine(
        token: nodeToken,
        userId: session.userId,
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
      await NodeOrderService.updateStatus(
        token: nodeToken,
        orderId: uuid,
        status: status,
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
}
