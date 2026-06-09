import 'package:flutter/material.dart';
import 'cgv_page_fr.dart';
import 'cgv_page_en.dart';

class CGVPage extends StatelessWidget {
  const CGVPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'en') {
      return const CGVPageEN();
    }
    return const CGVPageFR();
  }
}
