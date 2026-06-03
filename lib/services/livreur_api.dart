import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class LivreurApi {
  // Récupérer les livraisons assignées à un livreur
  static Future<List<Map<String, dynamic>>> getLivreurDeliveries(int livreurID) async {
    final cloud = ParseCloudFunction('getLivreurDeliveries');
    final response = await cloud.execute(parameters: {'livreurID': livreurID});
    if (response.success && response.result != null) {
      final list = response.result as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // Calculer les gains d'un livreur
  static Future<Map<String, dynamic>> getLivreurEarnings(int livreurID, {String period = 'week'}) async {
    final cloud = ParseCloudFunction('getLivreurEarnings');
    final response = await cloud.execute(parameters: {
      'livreurID': livreurID,
      'period': period,
    });
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result as Map);
    }
    return {'success': false, 'totalLivraisons': 0, 'totalGains': 0};
  }

  // Activer/désactiver le statut en ligne
  static Future<bool> toggleOnlineStatus(int livreurID, bool isOnline) async {
    final cloud = ParseCloudFunction('toggleOnlineStatus');
    final response = await cloud.execute(parameters: {
      'livreurID': livreurID,
      'isOnline': isOnline,
    });
    return response.success;
  }

  // Mettre à jour la position GPS du livreur
  static Future<bool> updatePosition(int livreurID, double lat, double lng) async {
    final cloud = ParseCloudFunction('updateLivreurPosition');
    final response = await cloud.execute(parameters: {
      'livreurID': livreurID,
      'latitude': lat,
      'longitude': lng,
    });
    return response.success;
  }

  // Mettre à jour le statut de livraison d'une commande
  static Future<bool> updateDeliveryStatus(int commandeID, String status) async {
    final cloud = ParseCloudFunction('updateDeliveryStatus');
    final response = await cloud.execute(parameters: {
      'commandeID': commandeID,
      'status': status,
    });
    return response.success;
  }

  // Assigner un livreur à une commande
  static Future<bool> assignLivreur(int commandeID, int livreurID) async {
    final cloud = ParseCloudFunction('assignLivreur');
    final response = await cloud.execute(parameters: {
      'commandeID': commandeID,
      'livreurID': livreurID,
    });
    return response.success;
  }
}
