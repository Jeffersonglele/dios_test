import 'package:flutter/material.dart';
import 'PrivacyPolicyPage.fr.dart';
import 'PrivacyPolicyPage.en.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'en') {
      return const PrivacyPolicyPageEN();
    }
    return const PrivacyPolicyPageFR();
  }
}
