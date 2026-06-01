import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

String phoneDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String beninLocalDigits(Object phone) {
  var digits = phoneDigits(phone.toString());

  if (digits.startsWith('229')) {
    digits = digits.substring(3);
  }

  if (digits.length < 10) {
    digits = digits.padLeft(10, '0');
  }

  return digits.length > 10 ? digits.substring(0, 10) : digits;
}

bool isValidBeninLocalPhone(String value) {
  final digits = phoneDigits(value);
  return digits.length == 10 && digits.startsWith('01');
}

String formatBeninLocalPhone(Object phone) {
  final digits = beninLocalDigits(phone);
  return '${digits.substring(0, 2)} ${digits.substring(2, 4)} '
      '${digits.substring(4, 6)} ${digits.substring(6, 8)} '
      '${digits.substring(8, 10)}';
}

String formatPhoneForCountry({
  required Object phone,
  required String country,
  String? indicatif,
  bool compact = false,
}) {
  final code = indicatif ?? _countryCode(country);

  if (country == 'Bénin' || code == '+229') {
    final local = formatBeninLocalPhone(phone);
    final display = '$code $local';
    return compact ? display.replaceAll(' ', '') : display;
  }

  final digits = phoneDigits(phone.toString());
  final display = code.isEmpty ? digits : '$code $digits';
  return compact ? display.replaceAll(' ', '') : display;
}

List<String> whatsappPhoneCandidatesForCountry({
  required Object phone,
  required String country,
  String? indicatif,
}) {
  final code = indicatif ?? _countryCode(country);
  final primary = formatPhoneForCountry(
    phone: phone,
    country: country,
    indicatif: code,
    compact: true,
  );
  final candidates = <String>[primary];

  if (country == 'Bénin' || code == '+229') {
    final local = beninLocalDigits(phone);
    if (local.length == 10 && local.startsWith('01')) {
      candidates.add('$code${local.substring(2)}');
    }
  }

  return candidates.toSet().toList();
}

String _countryCode(String country) {
  switch (country) {
    case 'France':
      return '+33';
    case 'Bénin':
      return '+229';
    case "Côte d'Ivoire":
      return '+225';
    default:
      return '';
  }
}

class BeninPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = phoneDigits(newValue.text);
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index++) {
      if (index == 2 || index == 4 || index == 6 || index == 8) {
        buffer.write(' ');
      }
      buffer.write(limited[index]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
