import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../config/app_config.dart';
import 'session_service.dart';

class UploadService {
  /// Upload une image vers le backend Node.js (R2)
  /// Retourne l'URL publique de l'image uploadée
  static Future<String?> uploadImage(File imageFile, {String scope = 'restaurants'}) async {
    try {
      // Récupérer le token d'authentification Node.js
      final token = await SessionService.readNodeToken();
      if (token == null) {
        print('Upload error: No authentication token');
        return null;
      }

      // Construire l'URL complète avec /api/v1 (comme NodeAuthService)
      final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/uploads/image');
      print('Upload URL: $uri');
      
      final request = http.MultipartRequest('POST', uri);

      // Ajouter le header d'authentification
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Ajouter le fichier
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: p.basename(imageFile.path),
      );
      request.files.add(multipartFile);

      // Ajouter le scope (restaurants, dishes, etc.)
      request.fields['scope'] = scope;
      
      // Envoyer la requête
      final response = await request.send();

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody');
        final jsonData = jsonDecode(responseBody);
        
        if (jsonData['data'] != null && jsonData['data']['url'] != null) {
          return jsonData['data']['url'] as String;
        }
      } else {
        print('Upload failed with status: ${response.statusCode}');
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Upload error: $e');
    }
    return null;
  }
}
