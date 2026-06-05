String sanitizeFilename(String filename) {
  final invalidChars = RegExp(r'[\/:*?"<>|\\\\]');
  String sanitized =
      filename.replaceAll(invalidChars, '_').replaceAll(' ', '_');
  if (sanitized.trim().isEmpty) {
    sanitized = 'file';
  }
  return sanitized;
}
