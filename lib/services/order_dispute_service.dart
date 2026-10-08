import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session_service.dart';

// ═══════════════════════════════════════════════════════════
// OrderDisputeService — réclamation client
//   POST /api/v1/orders/{orderId}/disputes   { reason, proofPhotoUrl }
// (même base URL / même token que WalletService)
// ═══════════════════════════════════════════════════════════

class DisputeException implements Exception {
  DisputeException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class OrderDisputeService {
  OrderDisputeService._();

  static Uri _uri(String path) {
    final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/v1$path');
  }

  /// Envoie la réclamation. Lève une DisputeException (message lisible).
  static Future<void> submitDispute(
    String orderId, {
    required String reason,
    required String proofPhotoUrl,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null || token.isEmpty) {
        throw DisputeException('Session expirée. Reconnectez-vous.',
            statusCode: 401);
      }

      final res = await http
          .post(
            _uri('/orders/$orderId/disputes'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'reason': reason.trim(),
              'proofPhotoUrl': proofPhotoUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode >= 200 && res.statusCode < 300) return;

      var message = '';
      try {
        final body = jsonDecode(res.body);
        if (body is Map) {
          final m = body['message'] ?? body['error'];
          if (m != null) message = m.toString();
        }
      } catch (_) {}
      throw DisputeException(
        message.trim().isNotEmpty
            ? message.trim()
            : 'La réclamation n\'a pas pu être envoyée. Réessayez.',
        statusCode: res.statusCode,
      );
    } on DisputeException {
      rethrow;
    } on TimeoutException {
      throw DisputeException('Le serveur met trop de temps à répondre.');
    } on SocketException {
      throw DisputeException('Connexion impossible. Vérifiez votre réseau.');
    } on http.ClientException {
      throw DisputeException('Connexion impossible. Vérifiez votre réseau.');
    }
  }
}
