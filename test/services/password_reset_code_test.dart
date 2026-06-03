import 'package:dios_delices/mails/mails.dart';
import 'package:flutter_test/flutter_test.dart';

// Importer ou définir la fonction isCodeValid si elle n'existe pas
// Si la fonction n'existe pas, créez-la dans un fichier séparé
bool isCodeValid(
    String enteredCode, String storedCode, DateTime generationTime) {
  const int expirationMinutes = 15;

  if (enteredCode != storedCode) {
    return false;
  }

  final now = DateTime.now();
  final difference = now.difference(generationTime);

  return difference.inMinutes <= expirationMinutes;
}

void main() {
  group('password reset verification code', () {
    test('accepts the matching code before expiration', () {
      final generationTime =
          DateTime.now().subtract(const Duration(minutes: 5));

      expect(isCodeValid('123456', '123456', generationTime), isTrue);
    });

    test('rejects an incorrect code', () {
      final generationTime = DateTime.now();

      expect(isCodeValid('123456', '654321', generationTime), isFalse);
    });

    test('rejects an expired code', () {
      final generationTime =
          DateTime.now().subtract(const Duration(minutes: 16));

      expect(isCodeValid('123456', '123456', generationTime), isFalse);
    });
  });
}
