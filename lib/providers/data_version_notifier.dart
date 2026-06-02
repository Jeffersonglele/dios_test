import 'package:flutter/foundation.dart';

/// Compteur global de version des données.
/// Chaque opération CRUD (create, update, delete) incrémente ce compteur.
/// Les pages qui souhaitent réagir aux changements de données écoutent ce notifier.
final dataVersionNotifier = ValueNotifier<int>(0);

/// Incrémente le compteur de version.
/// À appeler après chaque création, modification ou suppression de données.
void notifyDataChanged() {
  dataVersionNotifier.value = dataVersionNotifier.value + 1;
}
