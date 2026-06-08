import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyPageEN extends StatelessWidget {
  const PrivacyPolicyPageEN({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('1. DATA CONTROLLER', "Dios Délices\nEmail: contact@diosdelices.com\n\nThe data controller undertakes to comply with the following regulations:\n• General Data Protection Regulation (GDPR - EU 2016/679)\n• Law No. 2013-450 on the protection of personal data (Côte d'Ivoire)\n• Law No. 2017-20 on the digital code (Benin)"),
          _Section('2. DATA COLLECTED', "We collect only the data strictly necessary for the operation of the service:\n\n• Identity: last name, first name, username\n• Contact: email, phone number\n• Delivery address\n• Order data: history, ordered dishes, amounts\n• Connection data: date, time, IP address\n• Payment data: transaction reference (no banking data stored)\n• Geolocation: driver position during delivery only\n\nMinimum age: 16 years. No data from minors under 16 is collected."),
          _Section('3. PURPOSES OF PROCESSING', "Your data is processed for:\n\n• Creating and managing your user account\n• Processing your orders and ensuring delivery\n• Communicating with you (notifications, customer service)\n• Improving our services (anonymized statistics)\n• Complying with our legal obligations (invoicing, archiving)\n• Ensuring the security of the Platform"),
          _Section('4. LEGAL BASIS', "Processing is based on:\n\n• Performance of the contract (order, delivery)\n• Explicit consent (given during registration)\n• Legitimate interest (security, service improvement)\n• Legal obligation (retention of invoices)"),
          _Section('5. DATA RECIPIENTS', "Your data is accessible to the following recipients:\n\n• Restaurateurs (to process your order)\n• Delivery Drivers (to ensure delivery)\n• Back4App (cloud hosting — servers in the US/Canada)\n\nWe do not sell or rent your data to third parties. No data transfer outside the EU/Africa is carried out without appropriate safeguards."),
          _Section("6. RETENTION PERIOD", "• Account data: duration of use + 3 years after last activity\n• Order data: 10 years (legal obligation to retain invoices)\n• Connection data: 1 year\n• Geolocation data: deleted after delivery\n• In case of account deletion: data is anonymized or deleted within 30 days, except for legal retention obligations."),
          _Section("7. YOUR RIGHTS", "In accordance with applicable regulations, you have the following rights:\n\n• Right of access: obtain a copy of your data\n• Right to rectification: correct inaccurate data\n• Right to erasure (right to be forgotten): request deletion of your data\n• Right to data portability: receive your data in a structured format\n• Right to object: object to the processing of your data\n• Right to withdraw consent: at any time\n\nTo exercise these rights, use the \"Export my data\" function in the application or contact us at contact@diosdelices.com. Response within 30 days maximum."),
          _Section("8. SECURITY", "We implement appropriate technical and organizational measures to protect your data:\n\n• Encryption of communications (HTTPS)\n• Secure authentication\n• Restricted access to personal data\n• Access auditing\n• Pseudonymization of data where possible"),
          _Section('9. COOKIES AND TRACKERS', "The application uses technical cookies strictly necessary for its operation. No advertising or third-party tracking cookies are used without prior consent. You can disable cookies in your device settings."),
          _Section('10. BREACH NOTIFICATION', "In the event of a personal data breach, we will notify the competent authorities (CNIL in France, ARTCI in Côte d'Ivoire, APDP in Benin) within 72 hours, and affected individuals if the breach poses a high risk to their rights and freedoms."),
          _Section("11. DATA PROTECTION OFFICER", "For any questions regarding data protection, contact the DPO:\nEmail: dpo@diosdelices.com\nPostal address: to be communicated upon request."),
          _Section('12. COMPLAINTS', "If you believe your rights are not being respected, you may lodge a complaint with the competent supervisory authority:\n• France: CNIL (www.cnil.fr)\n• Côte d'Ivoire: ARTCI (www.artci.ci)\n• Benin: APDP (www.apdp.bj)"),
          _Section('13. CHANGES', "This policy may be modified. Users will be informed of major changes. Last updated: June 2026."),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section(this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTypography.labelMedium(color: AppColors.brand).copyWith(fontSize: 16)),
        const SizedBox(height: 6),
        Text(content, style: AppTypography.bodyMedium().copyWith(fontSize: 14, height: 1.5)),
      ]),
    );
  }
}
