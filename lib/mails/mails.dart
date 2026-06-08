import 'dart:math';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

/// Génère un code numérique à 6 chiffres.
String generateCode() {
  final rng = Random();
  return List.generate(6, (_) => rng.nextInt(10)).join();
}

Future<bool> sendVerificationEmail(BuildContext context, String email) async {
  final result = await _sendCodeViaCloud(
      context: context, email: email, functionName: 'sendVerificationCode');
  return result != null;
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
  try {
    final cloudFunction = ParseCloudFunction('verifyCode');
    final response = await cloudFunction.execute(parameters: {
      'email': email,
      'code': code,
    });
    if (response.success && response.result != null) {
      final result = response.result;
      if (result is Map<String, dynamic>) {
        return result['success'] == true;
      }
      if (result is bool) return result;
    }
    return false;
  } catch (e) {
    return false;
  }
}
