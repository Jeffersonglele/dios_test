import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class LivreurApi {
  // Récupérer les livraisons assignées à un livreur
  static Future<List<Map<String, dynamic>>> getLivreurDeliveries(int livreurID) async {
    final cloud = ParseCloudFunction('getMyDeliveries');
    final response = await cloud.execute();
    if (response.success && response.result != null) {
      final list = response.result as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // Calculer les gains d'un livreur
  static Future<Map<String, dynamic>> getLivreurEarnings(int livreurID, {String period = 'week'}) async {
    final cloud = ParseCloudFunction('getLivreurEarnings');
    final response = await cloud.execute(parameters: {'period': period});
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result as Map);
    }
    return {'success': false, 'totalLivraisons': 0, 'totalGains': 0};
  }

  // Activer/désactiver le statut en ligne
  static Future<bool> toggleOnlineStatus(int livreurID, bool isOnline) async {
    final cloud = ParseCloudFunction('toggleOnlineStatus');
    final response = await cloud.execute(parameters: {
      'isOnline': isOnline,
    });
    if (!response.success || response.result == null) return false;
    final result = response.result as Map<dynamic, dynamic>;
    return result['success'] == true && result['isOnline'] == isOnline;
  }

  // Le statut serveur est la source de vérité au démarrage de l'application.
  static Future<Map<String, dynamic>?> getSettings(int livreurID) async {
    try {
      final cloud = ParseCloudFunction('getLivreurSettings');
      final response = await cloud.execute();
      if (response.success && response.result is Map) {
        return Map<String, dynamic>.from(response.result as Map);
      }
    } catch (_) {}
    return null;
  }

  // Mettre à jour la position GPS du livreur
  static Future<bool> updatePosition(int livreurID, double lat, double lng,
      {int? commandeID}) async {
    final cloud = ParseCloudFunction('updateLivreurPosition');
    final parameters = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
    };
    if (commandeID != null && commandeID > 0) {
      parameters['commandeID'] = commandeID;
    }
    final response = await cloud.execute(parameters: parameters);
    if (!response.success || response.result == null) return false;
    return (response.result as Map<dynamic, dynamic>)['success'] == true;
  }

  // Mettre à jour le statut de livraison d'une commande
  static Future<bool> updateDeliveryStatus(int commandeID, String status) async {
    final cloud = ParseCloudFunction('updateDeliveryStatus');
    final response = await cloud.execute(parameters: {
      'commandeID': commandeID,
      'deliveryStatus': status,
    });
    if (!response.success || response.result == null) return false;
    return (response.result as Map<dynamic, dynamic>)['success'] == true;
  }

  // Assigner un livreur à une commande
  static Future<bool> assignLivreur(int commandeID, int livreurID) async {
    final cloud = ParseCloudFunction('assignLivreur');
    final response = await cloud.execute(parameters: {
      'commandeID': commandeID,
      'livreurID': livreurID,
    });
    if (response.success && response.result != null) {
      final result = response.result as Map<String, dynamic>;
      return result['success'] == true;
    }
    return false;
  }

  // Abandonner une livraison
  static Future<bool> dropDelivery(int commandeID, int livreurID) async {
    final cloud = ParseCloudFunction('dropDelivery');
    final response = await cloud.execute(parameters: {
      'commandeID': commandeID,
    });
    if (response.success && response.result != null) {
      final result = response.result as Map<String, dynamic>;
      return result['success'] == true;
    }
    return false;
  }

  // Récupérer la distance max de livraison
  static Future<double> getMaxDeliveryDistance(int livreurID) async {
    try {
      final cloud = ParseCloudFunction('getLivreurSettings');
      final response = await cloud.execute();
      if (response.success && response.result != null) {
        return ((response.result as Map<dynamic, dynamic>)['maxDeliveryDistance'] as num?)?.toDouble() ?? 10;
      }
    } catch (_) {}
    return 10;
  }

  // Mettre à jour la distance max de livraison
  static Future<bool> updateMaxDeliveryDistance(int livreurID, double distance) async {
    final cloud = ParseCloudFunction('update1User');
    final response = await cloud.execute(parameters: {
      'userID': livreurID,
      'maxDeliveryDistance': distance,
    });
    if (response.success && response.result != null) {
      final result = response.result as Map<String, dynamic>;
      return result['success'] == true;
    }
    return false;
  }
}
