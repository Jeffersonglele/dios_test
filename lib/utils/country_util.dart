class CountryUtil {
  static const rdc = 'RDC';
  static const benin = 'Bénin';

  // À passer à false au moment du déploiement RDC pour masquer le pays de test.
  static const allowBeninTestMode = true;

  static List<String> get selectableCountries => [
        rdc,
        if (allowBeninTestMode) benin,
      ];

  static String canonical(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'rdc' ||
        normalized == 'cd' ||
        normalized.contains('république démocratique') ||
        normalized.contains('republique democratique') ||
        normalized.contains('democratic republic')) {
      return rdc;
    }
    if (normalized == 'bénin' || normalized == 'benin' || normalized == 'bj') {
      return benin;
    }
    return '';
  }

  static bool isSupported(String? value) =>
      selectableCountries.contains(canonical(value));

  static bool isRdc(String? value) => canonical(value) == rdc;

  static bool isBenin(String? value) => canonical(value) == benin;
}
