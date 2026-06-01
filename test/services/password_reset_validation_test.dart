import 'package:dios_delices/services/password_reset_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordResetValidation', () {
    test('rejects an empty password', () async {
      final result = await PasswordResetValidation.validate(
        newPassword: '',
        confirmPassword: '',
        currentPasswordHash: 'hash',
      );

      expect(result, PasswordResetValidationResult.emptyPassword);
    });

    test('rejects mismatched confirmation', () async {
      final result = await PasswordResetValidation.validate(
        newPassword: 'Test2026@',
        confirmPassword: 'Other2026@',
        currentPasswordHash: 'hash',
      );

      expect(result, PasswordResetValidationResult.passwordsDoNotMatch);
    });

    test('rejects reusing the current password', () async {
      final result = await PasswordResetValidation.validate(
        newPassword: 'Test2026@',
        confirmPassword: 'Test2026@',
        currentPasswordHash:
            'd4a84712e7cacee07c8af222b4cfcdbaeaa73c21a57794e107437aed75f0b6c0',
      );

      expect(result, PasswordResetValidationResult.sameAsCurrentPassword);
    });

    test('accepts a new confirmed password', () async {
      final result = await PasswordResetValidation.validate(
        newPassword: 'New2026@',
        confirmPassword: 'New2026@',
        currentPasswordHash:
            'd4a84712e7cacee07c8af222b4cfcdbaeaa73c21a57794e107437aed75f0b6c0',
      );

      expect(result, PasswordResetValidationResult.valid);
    });
  });
}
