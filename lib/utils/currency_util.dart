class CurrencyUtil {
  static const _france = 'France';

  static String symbol(String country) =>
      country == _france ? '€' : 'FCFA';

  static String code(String country) =>
      country == _france ? 'eur' : 'xof';

  static String formatPrice(double amount, String country) {
    final sym = symbol(country);
    if (sym == '€') {
      return '${amount.toStringAsFixed(2)} €';
    }
    return '${amount.toStringAsFixed(0)} FCFA';
  }
}
