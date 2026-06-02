import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

Future<bool> sendVerificationEmail(
    BuildContext context, String email) async {
  return _sendCodeViaCloud(context: context, email: email, functionName: 'sendVerificationCode');
}

Future<bool> sendPasswordResetEmail(
    BuildContext context, String email) async {
  return _sendCodeViaCloud(context: context, email: email, functionName: 'sendPasswordResetCode');
}

Future<bool> _sendCodeViaCloud({
  required BuildContext context,
  required String email,
  required String functionName,
}) async {
  try {
    final cloudFunction = ParseCloudFunction(functionName);
    final response = await cloudFunction.execute(parameters: {'email': email});
    return response.success;
  } catch (e) {
    print('Erreur envoi code: $e');
    return false;
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
      final result = response.result as Map<String, dynamic>;
      return result['success'] == true;
    }
    return false;
  } catch (e) {
    print('Erreur vérification code: $e');
    return false;
  }
}
