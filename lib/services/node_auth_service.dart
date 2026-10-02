import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';

class NodeAuthException implements Exception {
  const NodeAuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NodeAuthSession {
  const NodeAuthSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

/// Client minimal de l'authentification JWT du backend Node.js.
class NodeAuthService {
  const NodeAuthService._();

  static Uri _uri(String path) {
    final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/v1$path');
  }

  static Future<NodeAuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
    });
    return _sessionFromResponse(response);
  }

  static Future<NodeAuthSession> register({
    required String username,
    required String email,
    required String password,
    String? firstname,
    String? lastname,
    String? telephone,
    String? telephoneLocal,
    String? telephoneE164,
    String? country,
    String? accountType,
    bool? ageConfirmed,
  }) async {
    final body = <String, dynamic>{
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      if (firstname?.trim().isNotEmpty == true) 'firstname': firstname!.trim(),
      if (lastname?.trim().isNotEmpty == true) 'lastname': lastname!.trim(),
      if (telephone?.trim().isNotEmpty == true) 'telephone': telephone!.trim(),
      if (telephoneLocal?.trim().isNotEmpty == true)
        'telephoneLocal': telephoneLocal!.trim(),
      if (telephoneE164?.trim().isNotEmpty == true)
        'telephoneE164': telephoneE164!.trim(),
      if (country?.trim().isNotEmpty == true) 'country': country!.trim(),
      if (accountType?.trim().isNotEmpty == true)
        'accountType': accountType!.trim(),
      if (ageConfirmed != null) 'ageConfirmed': ageConfirmed,
    };
    final response = await _post('/auth/register', body);
    return _sessionFromResponse(response);
  }

  static Future<Map<String, dynamic>> me(String token) async {
    final response = await getJson('/auth/me', token: token);
    return response['data'] as Map<String, dynamic>;
  }

  /// Met à jour le profil de l'utilisateur connecté via /auth/me.
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? firstname,
    String? lastname,
    String? email,
    String? telephone,
    String? telephoneLocal,
    String? telephoneE164,
    String? image,
  }) async {
    final body = <String, dynamic>{
      if (firstname != null) 'firstname': firstname.trim(),
      if (lastname != null) 'lastname': lastname.trim(),
      if (email != null) 'email': email.trim(),
      if (telephone != null) 'telephone': telephone.trim(),
      if (telephoneLocal != null) 'telephoneLocal': telephoneLocal.trim(),
      if (telephoneE164 != null) 'telephoneE164': telephoneE164.trim(),
      if (image != null) 'image': image,
    };
    final response = await patchJson('/auth/me', token: token, body: body);
    return response['data'] as Map<String, dynamic>;
  }

  /// Appel GET générique pour les écrans migrés vers l'API Node.js.
  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
    Map<String, String>? queryParameters,
  }) async {
    final uri = _uri(path).replace(queryParameters: queryParameters);
    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token?.trim().isNotEmpty == true)
            'Authorization': 'Bearer ${token!.trim()}',
        },
      ).timeout(const Duration(seconds: 60));
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    required String token,
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    try {
      final response = await http
          .post(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${token.trim()}',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Future<Map<String, dynamic>> patchJson(
    String path, {
    required String token,
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    try {
      final response = await http
          .patch(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${token.trim()}',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path, {
    required String token,
  }) async {
    try {
      final response = await http
          .delete(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${token.trim()}',
            },
          )
          .timeout(const Duration(seconds: 60));
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  /// Upload a file via multipart POST. Returns the decoded JSON response.
  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String token,
    required String filePath,
    String fieldName = 'image',
    String? scope,
  }) async {
    try {
      final uri = _uri(path);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${token.trim()}';

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final fileName = filePath.split('/').last;
      final extension = filePath.toLowerCase().split('.').last;

      MediaType? contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        case 'png':
          contentType = MediaType('image', 'png');
          break;
        case 'webp':
          contentType = MediaType('image', 'webp');
          break;
        case 'gif':
          contentType = MediaType('image', 'gif');
          break;
        case 'pdf':
          contentType = MediaType('application', 'pdf');
          break;
        default:
          final mb = bytes.length >= 12 ? bytes.sublist(0, 12) : bytes;
          if (mb.length >= 3 &&
              mb[0] == 0xFF &&
              mb[1] == 0xD8 &&
              mb[2] == 0xFF) {
            contentType = MediaType('image', 'jpeg');
          } else if (mb.length >= 8 &&
              mb[0] == 0x89 &&
              mb[1] == 0x50 &&
              mb[2] == 0x4E &&
              mb[3] == 0x47) {
            contentType = MediaType('image', 'png');
          } else if (mb.length >= 12 &&
              mb[0] == 0x52 &&
              mb[1] == 0x49 &&
              mb[2] == 0x46 &&
              mb[3] == 0x46 &&
              mb[8] == 0x57 &&
              mb[9] == 0x45 &&
              mb[10] == 0x42 &&
              mb[11] == 0x50) {
            contentType = MediaType('image', 'webp');
          } else {
            contentType = MediaType('application', 'octet-stream');
          }
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
        contentType: contentType,
      ));

      if (scope != null) {
        request.fields['scope'] = scope;
      }
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Future<void> requestEmailVerification(String token) async {
    await _authorizedPost('/auth/email-verification/request', token);
  }

  static Future<void> confirmEmailVerification({
    required String token,
    required String code,
  }) async {
    await _authorizedPost(
      '/auth/email-verification/confirm',
      token,
      body: {'code': code.trim()},
    );
  }

  static Future<void> _authorizedPost(
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http
          .post(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 90));
      _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            _uri(path),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      return _decodeResponse(response);
    } on NodeAuthException {
      rethrow;
    } catch (error) {
      throw NodeAuthException(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet. (${error.runtimeType})',
      );
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload = <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Le message HTTP ci-dessous reste plus utile qu'une erreur JSON.
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message =
          error is Map ? error['message']?.toString() : error?.toString();
      throw NodeAuthException(
        message?.trim().isNotEmpty == true
            ? message!
            : 'La requête a échoué (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return payload;
  }

  static NodeAuthSession _sessionFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const NodeAuthException('Réponse d’authentification invalide.');
    }

    final token = data['token']?.toString() ?? '';
    final user = data['user'];
    if (token.isEmpty || user is! Map) {
      throw const NodeAuthException('Le serveur n’a pas retourné de session.');
    }

    return NodeAuthSession(
      token: token,
      user: Map<String, dynamic>.from(user),
    );
  }
}
