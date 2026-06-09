import 'dart:convert';

import 'package:crypto/crypto.dart';

enum PasswordResetValidationResult {
  emptyPassword,
  passwordsDoNotMatch,
  sameAsCurrentPassword,
  valid,
}

class PasswordResetValidation {
  /// Validates a password reset request.
  ///
  /// [currentPasswordHash] is the (already hashed) current password hash.
  ///
  /// Rules used by unit tests:
  /// - if [newPassword] or [confirmPassword] is empty -> [emptyPassword]
  /// - if they don't match -> [passwordsDoNotMatch]
  /// - if SHA-256(newPassword) equals [currentPasswordHash] -> [sameAsCurrentPassword]
  /// - otherwise -> [valid]
  static Future<PasswordResetValidationResult> validate({
    required String newPassword,
    required String confirmPassword,
    required String currentPasswordHash,
  }) async {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      return PasswordResetValidationResult.emptyPassword;
    }

    if (newPassword != confirmPassword) {
      return PasswordResetValidationResult.passwordsDoNotMatch;
    }

    final newPasswordHash = _sha256Hex(newPassword);
    if (newPasswordHash.toLowerCase() == currentPasswordHash.toLowerCase()) {
      return PasswordResetValidationResult.sameAsCurrentPassword;
    }

    return PasswordResetValidationResult.valid;
  }

  static String _sha256Hex(String input) {
    final bytes = input.codeUnits;
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
