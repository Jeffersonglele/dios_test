import 'dart:math';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../services/node_auth_service.dart';
import '../services/session_service.dart';

/// Génère un code numérique à 6 chiffres.
String generateCode() {
  final rng = Random();
  return List.generate(6, (_) => rng.nextInt(10)).join();
}

Future<bool> sendVerificationEmail(BuildContext context, String email) async {
  final nodeToken = await SessionService.readNodeToken();
  if (nodeToken != null) {
    try {
      await NodeAuthService.requestEmailVerification(nodeToken);
      return true;
    } on NodeAuthException catch (error) {
      debugPrint('Node email verification request failed: $error');
      rethrow;
    } catch (e) {
      debugPrint('Node email verification request unknown error: $e');
      rethrow;
    }
  }

  try {
    final params = <String, dynamic>{'email': email};
    final cloudFunction = ParseCloudFunction('sendVerificationCode');
    final response = await cloudFunction.execute(parameters: params);
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Échec envoi code (Parse)');
    }
    return true;
  } catch (e) {
    debugPrint('Parse sendVerificationCode error: $e');
    rethrow;
  }
}

/// Envoie un email de réinitialisation avec [code] (généré côté client).
/// Retourne le code si l'envoi a réussi, `null` en cas d'échec.
Future<String?> sendPasswordResetEmail(
    BuildContext context, String email, String code) async {
  return _sendCodeViaCloud(
    context: context,
    email: email,
    functionName: 'sendPasswordResetCode',
    code: code,
  );
}

Future<String?> _sendCodeViaCloud({
  required BuildContext context,
  required String email,
  required String functionName,
  String? code,
}) async {
  try {
    final params = <String, dynamic>{'email': email};
    if (code != null) params['code'] = code;
    final cloudFunction = ParseCloudFunction(functionName);
    final response = await cloudFunction.execute(parameters: params);
    if (!response.success) return null;
    return code;
  } catch (e) {
    return null;
  }
}

/// Vérifie si un code de réinitialisation est valide.
/// [code] : code saisi par l'utilisateur
/// [expectedCode] : code attendu
/// [generationTime] : moment de génération du code
/// Expire après 15 minutes.
bool isCodeValid(String code, String expectedCode, DateTime generationTime) {
  return code == expectedCode &&
      DateTime.now().difference(generationTime).inMinutes < 15;
}

Future<bool> verifyEmailCode({
  required String email,
  required String code,
}) async {
  final nodeToken = await SessionService.readNodeToken();
  if (nodeToken != null) {
    try {
      await NodeAuthService.confirmEmailVerification(
        token: nodeToken,
        code: code,
      );
      return true;
    } on NodeAuthException catch (error) {
      debugPrint('Node email verification confirmation failed: $error');
      rethrow;
    } catch (e) {
      debugPrint('Node email verification unknown error: $e');
      rethrow;
    }
  }

  try {
    final cloudFunction = ParseCloudFunction('verifyCode');
    final response = await cloudFunction.execute(parameters: {
      'email': email,
      'code': code,
    });

    debugPrint('verifyCode response.success=${response.success}');
    debugPrint('verifyCode response.result=${response.result}');
    debugPrint('verifyCode response.error=${response.error?.message}');

    if (response.success && response.result != null) {
      final result = response.result;
      if (result is Map<String, dynamic>) {
        final ok = result['success'] == true;
        if (!ok) {
          throw Exception(result['error']?.toString() ??
              'Code invalide ou expiré (Parse)');
        }
        return true;
      }
      if (result is bool) {
        if (!result) throw Exception('Code invalide ou expiré (Parse)');
        return true;
      }
    }
    throw Exception(response.error?.message ?? 'Code invalide ou expiré');
  } catch (e) {
    debugPrint('verifyCode exception=$e');
    rethrow;
  }
}
