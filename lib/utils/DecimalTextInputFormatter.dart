import 'package:flutter/services.dart';

class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;

  DecimalTextInputFormatter({this.decimalRange = 2}) : assert(decimalRange >= 0);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String newText = newValue.text;

    // Autorise uniquement les valeurs numériques et le point décimal
    if (newText.isNotEmpty && double.tryParse(newText) == null) {
      return oldValue;
    }

    // Limite le nombre de décimales
    if (newText.contains(".") &&
        newText.substring(newText.indexOf(".") + 1).length > decimalRange) {
      return oldValue;
    }

    return newValue;
  }
}
