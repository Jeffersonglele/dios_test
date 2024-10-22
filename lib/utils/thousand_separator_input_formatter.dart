import 'package:flutter/services.dart';

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String numericOnly = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    String newText = numericOnly.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
    return TextEditingValue(
      text: newText,
      selection: newValue.selection.copyWith(
        baseOffset: newText.length,
        extentOffset: newText.length,
      ),
    );
  }
}
