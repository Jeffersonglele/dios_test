import 'package:flutter/material.dart';
import 'privacy_policy_page_fr.dart';
import 'privacy_policy_page_en.dart';

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
