import 'package:intl/intl.dart';
import '../services/currency_service.dart';
import 'country_util.dart';

class CurrencyUtil {
  static const Map<String, String> _countryCodeToCurrency = {
    'BJ': 'XOF', 'CI': 'XOF', 'SN': 'XOF', 'TG': 'XOF',
    'BF': 'XOF', 'ML': 'XOF', 'NE': 'XOF', 'GW': 'XOF',
    'CD': 'CDF',
    'FR': 'EUR', 'BE': 'EUR',
    'CH': 'CHF',
    'US': 'USD',
    'CA': 'CAD',
    'NG': 'NGN',
  };

  static bool isRdc(String? country) => CountryUtil.isRdc(country);

  static String code(String country) {
    final raw = (country ?? '').trim();
    if (raw.isEmpty) return 'xof';

    if (CountryUtil.isRdc(raw)) return 'cdf';
    if (CountryUtil.isBenin(raw)) return 'xof';

    if (raw.length == 2) {
      final up = raw.toUpperCase();
      if (_countryCodeToCurrency.containsKey(up)) {
        return _countryCodeToCurrency[up]!.toLowerCase();
      }
    }

    final lowered = raw.toLowerCase();
    if (lowered.contains('franc') || lowered.contains('france')) return 'eur';
    if (lowered.contains('belgium') || lowered.contains('belgique')) return 'eur';
    if (lowered.contains('suisse') || lowered.contains('switzerland')) return 'chf';
    if (lowered.contains('dollar') ||
        lowered.contains('état') ||
        lowered.contains('etat') ||
        lowered.contains('united states')) return 'usd';
    if (lowered.contains('canada')) return 'cad';
    if (lowered.contains('nigeria')) return 'ngn';
    if (lowered.contains('cdf') || lowered.contains('congolais')) return 'cdf';
    if (lowered.contains('fcfa') || lowered.contains('xof')) return 'xof';
    if (lowered.contains('euro') || lowered.contains('€')) return 'eur';

    return 'xof';
  }

  static String symbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'CDF': return 'CDF';
      case 'XOF': return 'FCFA';
      case 'EUR': return '€';
      case 'USD': return r'$';
      case 'NGN': return '₦';
      case 'CAD': return r'$CA';
      case 'CHF': return 'CHF';
      default: return currencyCode.toUpperCase();
    }
  }

  static String formatAmount(double amount, String currencyCode) {
    final code = currencyCode.toUpperCase();
    final sym = symbol(code);

    if (code == 'XOF' || code == 'CDF' || code == 'NGN') {
      final formatter = NumberFormat.currency(
        locale: 'fr_FR',
        symbol: sym,
        decimalDigits: 0,
      );
      return formatter.format(amount.roundToDouble());
    }

    final formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: sym,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatConvertedPrice(
    double baseAmount, {
    String? targetCurrency,
    String sourceCurrency = 'XOF',
  }) {
    final currency = targetCurrency ?? CurrencyService.instance.activeCurrency;
    final converted = CurrencyService.instance.convertBetween(
      baseAmount,
      sourceCurrency,
      currency,
    );
    return formatAmount(converted, currency);
  }

  static String formatPrice(double amount, String country) {
    return formatConvertedPrice(amount, sourceCurrency: 'XOF');
  }
}
