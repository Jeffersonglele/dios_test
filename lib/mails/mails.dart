import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart';

String generateVerificationCode() {
  Random random = Random();
  int code = random.nextInt(900000) + 100000;
  return code.toString();
}

Future<String?> sendVerificationEmail(
    BuildContext context, String email) async {
  return _sendCodeViaCloud(
    context: context,
    email: email,
    functionName: 'sendVerificationCode',
  );
}

Future<String?> sendPasswordResetEmail(
    BuildContext context, String email) async {
  return _sendCodeViaCloud(
    context: context,
    email: email,
    functionName: 'sendPasswordResetCode',
  );
}

Future<String?> _sendCodeViaCloud({
  required BuildContext context,
  required String email,
  required String functionName,
}) async {
  try {
    final cloudFunction = ParseCloudFunction(functionName);
    final response = await cloudFunction.execute(parameters: {
      'email': email,
    });

    if (response.success && response.result != null) {
      final result = response.result as Map<String, dynamic>;
      if (result['success'] == true) {
        return result['code'] as String?;
      }
    }
    return null;
  } catch (e) {
    print("Échec envoi email via cloud: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erreur lors de l'envoi du mail")),
    );
    return null;
  }
}

bool isCodeValid(
    String generatedCode, String enteredCode, DateTime generationTime) {
  if (generatedCode == enteredCode &&
      DateTime.now().difference(generationTime).inMinutes < 15) {
    return true;
  }
  return false;
}
