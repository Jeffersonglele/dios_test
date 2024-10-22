class FormatPrix {
  static String formatPrix(double prix) {
    // Arrondir à zéro décimal
    String prixString = prix.toStringAsFixed(0);

    // Supprimer le ".0" pour les nombres entiers
    if (prixString.endsWith(".0")) {
      prixString = prixString.substring(0, prixString.length - 2);
    }

    // Ajouter les espaces pour le format "000 000"
    if (prixString.length > 3) {
      int length = prixString.length;
      int numSpaces = (length - 1) ~/ 3;
      for (int i = 1; i <= numSpaces; i++) {
        prixString = prixString.substring(0, length - i * 3) +
            ' ' +
            prixString.substring(length - i * 3);
      }
    }

    return prixString;
  }
}
