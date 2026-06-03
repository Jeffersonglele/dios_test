import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class CommandeApi {
  const CommandeApi._();

  static Future<void> updateOrderStatus(
      String commandeId, String status) async {
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
