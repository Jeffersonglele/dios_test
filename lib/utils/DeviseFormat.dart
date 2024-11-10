import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CFAFormat extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Supprime tout sauf les chiffres
    String numericOnly = newValue.text.replaceAll(RegExp('[^0-9]'), '');

    // Limite la saisie à 5 chiffres maximum
    if (numericOnly.length > 5) {
      numericOnly = numericOnly.substring(0, 5);
    }

    // Applique un espace tous les trois chiffres pour CFA
    String newText = numericOnly.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class FrenchFormat extends TextInputFormatter {
  final int decimalRange;

  FrenchFormat({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    // Gère les cas où le texte est vide ou contient uniquement un séparateur
    if (text.isEmpty || text == ',' || text == '.') {
      return newValue;
    }

    // Remplace tout sauf les chiffres et la virgule
    String numericOnly = text.replaceAll(RegExp(r'[^0-9,]'), '');
    List<String> parts = numericOnly.split(',');

    // Limite la partie entière à 2 chiffres maximum
    String integerPart = parts[0].length > 2 ? parts[0].substring(0, 2) : parts[0];

    // Format la partie entière sans ajouter de séparateur de milliers
    String formattedIntegerPart = integerPart;

    // Construit le texte final en ajoutant la partie décimale, si elle existe
    String formattedText = formattedIntegerPart;
    if (parts.length > 1) {
      // Limite la partie décimale au nombre de chiffres spécifié (2 par défaut)
      String decimalPart = parts[1].substring(
          0, decimalRange > parts[1].length ? parts[1].length : decimalRange);
      formattedText += ',$decimalPart';
    }

    // Retourne la valeur formatée avec la position du curseur mise à jour
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}



