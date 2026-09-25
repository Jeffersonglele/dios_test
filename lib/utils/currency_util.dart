import 'country_util.dart';

class CurrencyUtil {
  static bool isRdc(String country) => CountryUtil.isRdc(country);

  static String symbol(String country) {
    if (isRdc(country)) return 'CDF';
    return 'FCFA';
  }

  static String code(String country) {
    if (isRdc(country)) return 'cdf';
    return 'xof';
  }

  static String formatPrice(double amount, String country) {
    final sym = symbol(country);
    if (sym == '€') {
      return '${amount.toStringAsFixed(2)} €';
    }
    return '${amount.toStringAsFixed(0)} $sym';
  }
}
