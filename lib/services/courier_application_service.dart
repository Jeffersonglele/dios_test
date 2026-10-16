import 'node_auth_service.dart';
import 'session_service.dart';

/// Dossier livreur envoyé au backend Node : photo du visage (qui devient la
/// photo de profil), pièce d'identité et permis (sauf à vélo).
class CourierApplicationService {
  const CourierApplicationService._();

  /// Véhicules acceptés par le serveur.
  static const vehicleTypes = ['moto', 'velo', 'voiture'];

  static bool needsLicense(String vehicleType) => vehicleType != 'velo';

  static Future<String> _upload(String path, String token) async {
    final response = await NodeAuthService.uploadFile(
      '/uploads/document',
      token: token,
      filePath: path,
      fieldName: 'file',
      scope: 'courier-documents',
    );
    final data = response['data'];
    final url = data is Map ? data['url']?.toString() : null;
    if (url == null || url.isEmpty) {
      throw const NodeAuthException('Le fichier n’a pas pu être envoyé.');
    }
    return url;
  }

  /// Envoie les fichiers puis crée le dossier. Lève [NodeAuthException]
  /// avec un message lisible en cas d'échec.
  static Future<void> submit({
    required String photoPath,
    required String identityPath,
    String? licensePath,
    required String vehicleType,
    String? vehiclePlate,
  }) async {
    final token = await SessionService.readNodeToken();
    if (token == null) {
      throw const NodeAuthException(
          'Session expirée, reconnectez-vous pour envoyer votre dossier.');
    }
    final photoUrl = await _upload(photoPath, token);
    final identityUrl = await _upload(identityPath, token);
    final licenseUrl = licensePath != null && needsLicense(vehicleType)
        ? await _upload(licensePath, token)
        : null;
    await NodeAuthService.postJson(
      '/verification/courier-application',
      token: token,
      body: {
        'photoUrl': photoUrl,
        'identityFileUrl': identityUrl,
        if (licenseUrl != null) 'licenseUrl': licenseUrl,
        'vehicleType': vehicleType,
        if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
          'vehiclePlate': vehiclePlate.trim().toUpperCase(),
      },
    );
  }

  /// Dossier validé par l'administration (anciennes valeurs comprises).
  static bool isVerified(String identity) {
    final v = identity.trim().toLowerCase();
    return v == 'verified' || v == 'vérifiée' || v == 'verifiee' ||
        v == 'approved' || v == 'validated';
  }

  static bool isPending(String identity) {
    final v = identity.trim().toLowerCase();
    return v == 'en attente' || v == 'pending';
  }
}
