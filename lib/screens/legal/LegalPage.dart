import 'package:flutter/material.dart';
import 'LegalPage.fr.dart';
import 'LegalPage.en.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'en') {
      return const LegalPageEN();
    }
    return const LegalPageFR();
  }
}
