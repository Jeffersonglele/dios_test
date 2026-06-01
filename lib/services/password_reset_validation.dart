import '../modeles/users.dart';

enum PasswordResetValidationResult {
  valid,
  emptyPassword,
  passwordsDoNotMatch,
  sameAsCurrentPassword,
}

class PasswordResetValidation {
  const PasswordResetValidation._();

  static Future<PasswordResetValidationResult> validate({
    required String newPassword,
    required String confirmPassword,
    required String currentPasswordHash,
  }) async {
    if (newPassword.isEmpty) {
      return PasswordResetValidationResult.emptyPassword;
    }

    if (newPassword != confirmPassword) {
      return PasswordResetValidationResult.passwordsDoNotMatch;
    }

    final newPasswordHash = await Users.encryptPassword(newPassword);
    if (newPasswordHash == currentPasswordHash) {
      return PasswordResetValidationResult.sameAsCurrentPassword;
    }

    return PasswordResetValidationResult.valid;
  }
}
