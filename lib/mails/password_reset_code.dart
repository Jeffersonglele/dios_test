// Utility to validate password reset / verification codes.

bool isCodeValid(
  String generatedCode,
  String inputCode,
  DateTime generationTime, {
  Duration expiration = const Duration(minutes: 15),
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final isMatch = generatedCode == inputCode;
  final isNotExpired = effectiveNow.difference(generationTime) <= expiration;
  return isMatch && isNotExpired;
}
