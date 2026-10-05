import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../config/app_config.dart';
import '../models/chat_message.dart';
import 'session_service.dart';

class ChatApiService {
  /// Récupère l'historique des messages d'une commande
  static Future<List<ChatMessage>> getMessages(dynamic orderId) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) {
        print('[ChatApiService] Pas de token auth');
        return [];
      }

      final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/chat/orders/$orderId/messages');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawList = decoded['data'] as List<dynamic>? ?? [];
        return rawList
            .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else {
        print('[ChatApiService] Erreur getMessages: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[ChatApiService] Exception getMessages: $e');
    }
    return [];
  }

  /// Téléverse un fichier média pour le chat (Image ou Note Vocale Audio)
  /// Retourne un Map avec { 'url': String, 'mimeType': String, 'size': int }
  static Future<Map<String, dynamic>?> uploadChatMedia(File file, {String scope = 'chat_media'}) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) {
        print('[ChatApiService] Pas de token auth');
        return null;
      }

      final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/uploads/chat-media');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: p.basename(file.path),
      );
      request.files.add(multipartFile);
      request.fields['scope'] = scope;

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = jsonDecode(responseBody);
        return {
          'url': jsonData['url'] as String?,
          'mimeType': jsonData['mimeType'] as String?,
          'size': jsonData['size'] as int?,
        };
      } else {
        print('[ChatApiService] Upload failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('[ChatApiService] Exception uploadChatMedia: $e');
    }
    return null;
  }
}
