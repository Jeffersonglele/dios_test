import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class CurrencyService extends ChangeNotifier {
  CurrencyService._();

  static final CurrencyService instance = CurrencyService._();

  String _detectedCountry = 'BJ';
  String _detectedCurrency = 'XOF';
  String? _userCurrencyPreference;
  Map<String, double> _rates = {
    'USD': 1.0,
    'XOF': 600.0,
    'CDF': 2500.0,
    'EUR': 0.92,
    'NGN': 1500.0,
    'CAD': 1.36,
    'CHF': 0.89,
  };

  final String sourceCurrency = 'XOF';

  String get activeCurrency => _userCurrencyPreference ?? _detectedCurrency;
  bool get isAutoCurrency => _userCurrencyPreference == null;
  String get detectedCurrency => _detectedCurrency;

  List<String> get availableCurrencies {
    const preferred = ['XOF', 'EUR', 'USD', 'CDF', 'NGN', 'CAD', 'CHF'];
    final result = <String>[];
    for (final c in preferred) {
      if (_rates.containsKey(c) && !result.contains(c)) result.add(c);
    }
    for (final c in _rates.keys) {
      if (!result.contains(c)) result.add(c);
    }
    return result;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userCurrencyPreference = prefs.getString('user_currency_pref');

    try {
      final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/config/currency');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final payload = data['data'];
          _detectedCountry = payload['country'] ?? 'BJ';
          _detectedCurrency = payload['currency'] ?? 'XOF';

          if (payload['rates'] != null) {
            final rawRates = payload['rates'] as Map<String, dynamic>;
            _rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          }
        }
      }
    } catch (e) {
      debugPrint('CurrencyService init failed: $e');
    }
    notifyListeners();
  }

  Future<void> setPreferredCurrency(String? currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (currencyCode == null) {
      _userCurrencyPreference = null;
      await prefs.remove('user_currency_pref');
    } else {
      _userCurrencyPreference = currencyCode;
      await prefs.setString('user_currency_pref', currencyCode);
    }
    notifyListeners();
  }

  double convert(double amount, {String? toCurrency}) {
    final target = toCurrency ?? activeCurrency;
    return convertBetween(amount, sourceCurrency, target);
  }

  double convertBetween(double amount, String fromCurrency, String toCurrency) {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) return amount;

    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;

    final amountInBase = amount / fromRate;
    return amountInBase * toRate;
  }
}
