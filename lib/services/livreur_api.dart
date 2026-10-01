import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';

class LivreurApi {
  // Récupérer les livraisons assignées à un livreur
  static Future<List<Map<String, dynamic>>> getLivreurDeliveries(int livreurID) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return [];
    
    try {
      final response = await NodeAuthService.getJson('/couriers/me/deliveries', token: token);
      final data = response['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Ignorer l'erreur pour retourner une liste vide
    }
    return [];
  }

  // Calculer les gains d'un livreur
  static Future<Map<String, dynamic>> getLivreurEarnings(int livreurID, {String period = 'week'}) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return {'success': false, 'totalLivraisons': 0, 'totalGains': 0};

    try {
      final response = await NodeAuthService.getJson(
        '/couriers/me/earnings', 
        token: token,
        queryParameters: {'period': period},
      );
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
    } catch (e) {
      // Ignorer et retourner les valeurs par défaut
    }
    return {'success': false, 'totalLivraisons': 0, 'totalGains': 0};
  }

  // Activer/désactiver le statut en ligne
  static Future<bool> toggleOnlineStatus(int livreurID, bool isOnline) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      final response = await NodeAuthService.patchJson(
        '/couriers/me/availability',
        token: token,
        body: {'status': isOnline ? 'AVAILABLE' : 'OFFLINE'},
      );
      return response['data'] != null;
    } catch (e) {
      return false;
    }
  }

  // Le statut serveur est la source de vérité au démarrage de l'application.
  static Future<Map<String, dynamic>?> getSettings(int livreurID) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return null;

    try {
      final response = await NodeAuthService.getJson('/users/me', token: token);
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  // Mettre à jour la position GPS du livreur
  static Future<bool> updatePosition(int livreurID, double lat, double lng, {int? commandeID}) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      final body = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        'accuracyM': 10,
      };
      if (commandeID != null && commandeID > 0) {
        body['commandeID'] = commandeID;
      }
      
      await NodeAuthService.postJson(
        '/couriers/me/location',
        token: token,
        body: body,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mettre à jour le statut de livraison d'une commande
  static Future<bool> updateDeliveryStatus(int commandeID, String status) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      await NodeAuthService.patchJson(
        '/deliveries/$commandeID/status',
        token: token,
        body: {'status': status},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Assigner un livreur à une commande
  static Future<bool> assignLivreur(int commandeID, int livreurID) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      await NodeAuthService.postJson(
        '/deliveries/$commandeID/assign',
        token: token,
        body: {'livreurID': livreurID},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Abandonner une livraison
  static Future<bool> dropDelivery(int commandeID, int livreurID) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      await NodeAuthService.postJson(
        '/deliveries/$commandeID/drop',
        token: token,
        body: {'livreurID': livreurID},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Récupérer la distance max de livraison
  static Future<double> getMaxDeliveryDistance(int livreurID) async {
    final settings = await getSettings(livreurID);
    if (settings != null) {
      return (settings['maxDeliveryDistance'] as num?)?.toDouble() ?? 10.0;
    }
    return 10.0;
  }

  // Mettre à jour la distance max de livraison
  static Future<bool> updateMaxDeliveryDistance(int livreurID, double distance) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      await NodeAuthService.patchJson(
        '/users/me',
        token: token,
        body: {'maxDeliveryDistance': distance},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
