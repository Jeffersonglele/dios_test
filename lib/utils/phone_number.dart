import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

String phoneDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

const _countryDialCodes = <String, String>{
  'France': '33',
  'Bénin': '229',
  "Côte d'Ivoire": '225',
};

const _countryLengths = <String, int>{
  'France': 10,
  'Bénin': 10,
  "Côte d'Ivoire": 10,
};

const _mobilePrefixes = <String, List<String>>{
  // Depuis le 30 novembre 2024, le Bénin emploie 01 + l'ancien numéro à 8 chiffres.
  'Bénin': ['01'],
  // Plans mobiles ivoiriens : 01 (Moov), 05 (MTN) et 07 (Orange).
  "Côte d'Ivoire": ['01', '05', '07'],
  // Pour ce formulaire de compte/paiement, on accepte les mobiles français.
  'France': ['06', '07'],
};

String _canonicalCountry(String country) => country.trim();

String localPhoneDigitsForCountry({
  required Object phone,
  required String country,
}) {
  final canonicalCountry = _canonicalCountry(country);
  var digits = phoneDigits(phone.toString());
  final dialCode = _countryDialCodes[canonicalCountry];

  if (dialCode != null && digits.startsWith('00$dialCode')) {
    digits = digits.substring(dialCode.length + 2);
  } else if (dialCode != null && digits.startsWith(dialCode)) {
    digits = digits.substring(dialCode.length);
  }

  // Les numéros français saisis au format international n'ont pas le 0 local.
  if (canonicalCountry == 'France' &&
      digits.length == 9 &&
      !digits.startsWith('0')) {
    digits = '0$digits';
  }

  final expectedLength = _countryLengths[canonicalCountry];
  if (expectedLength != null && digits.length > expectedLength) {
    digits = digits.substring(0, expectedLength);
  }
  return digits;
}

bool isValidLocalPhoneForCountry({
  required String phone,
  required String country,
}) {
  final canonicalCountry = _canonicalCountry(country);
  final digits = localPhoneDigitsForCountry(phone: phone, country: country);
  if (digits.length != _countryLengths[canonicalCountry]) return false;

  final prefixes = _mobilePrefixes[canonicalCountry];
  return prefixes == null || prefixes.any(digits.startsWith);
}

String phoneExampleForCountry(String country) {
  switch (_canonicalCountry(country)) {
    case 'Bénin':
      return '01 XX XX XX XX';
    case 'France':
      return '06 XX XX XX XX';
    case "Côte d'Ivoire":
      return '07 XX XX XX XX';
    default:
      return 'XX XX XX XX XX';
  }
}

String formatLocalPhoneForCountry({
  required Object phone,
  required String country,
}) {
  final digits = localPhoneDigitsForCountry(phone: phone, country: country);
  final groups = <String>[];
  for (var index = 0; index < digits.length; index += 2) {
    final end = (index + 2).clamp(0, digits.length);
    groups.add(digits.substring(index, end));
  }
  return groups.join(' ');
}

/// Format national lisible conservé en base : « 01 XX XX XX XX » au Bénin.
String phoneStorageFormatForCountry({
  required Object phone,
  required String country,
}) =>
    formatLocalPhoneForCountry(phone: phone, country: country);

/// Format international normalisé pour les passerelles de paiement, SMS et
/// déduplication : +229012345678 au Bénin, par exemple.
String phoneE164ForCountry({
  required Object phone,
  required String country,
}) {
  final dialCode = _countryDialCodes[_canonicalCountry(country)];
  final local = localPhoneDigitsForCountry(phone: phone, country: country);
  return dialCode == null || local.isEmpty ? '' : '+$dialCode$local';
}

String beninLocalDigits(Object phone) =>
    localPhoneDigitsForCountry(phone: phone, country: 'Bénin');

bool isValidBeninLocalPhone(String value) =>
    isValidLocalPhoneForCountry(phone: value, country: 'Bénin');

String formatBeninLocalPhone(Object phone) =>
    formatLocalPhoneForCountry(phone: phone, country: 'Bénin');

String formatPhoneForCountry({
  required Object phone,
  required String country,
  String? indicatif,
  bool compact = false,
}) {
  final code = indicatif ?? _countryCode(country);
  final local = formatLocalPhoneForCountry(phone: phone, country: country);
  final display = code.isEmpty ? local : '$code $local';
  return compact ? display.replaceAll(' ', '') : display;
}

List<String> whatsappPhoneCandidatesForCountry({
  required Object phone,
  required String country,
  String? indicatif,
}) {
  final code = indicatif ?? _countryCode(country);
  final local = localPhoneDigitsForCountry(phone: phone, country: country);
  final primary = '${code.replaceAll('+', '')}$local';
  return [primary, phoneDigits(phone.toString())].toSet().toList();
}

String _countryCode(String country) {
  final code = _countryDialCodes[_canonicalCountry(country)];
  return code == null ? '' : '+$code';
}

class CountryPhoneInputFormatter extends TextInputFormatter {
  const CountryPhoneInputFormatter(this.country);

  final String country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatLocalPhoneForCountry(
      phone: newValue.text,
      country: country,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class BeninPhoneInputFormatter extends CountryPhoneInputFormatter {
  const BeninPhoneInputFormatter() : super('Bénin');
}
