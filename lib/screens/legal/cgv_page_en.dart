import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class CGVPageEN extends StatelessWidget {
  const CGVPageEN({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cgv_title)),
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('1. DEFINITIONS',
              "• \"Platform\": the Dios Délices mobile application.\n• \"Restaurateur\": any individual or legal entity offering dishes via the Platform.\n• \"Customer\": any person ordering dishes via the Platform.\n• \"Delivery Driver\": the person delivering orders.\n• \"Order\": a purchase of dishes made by a Customer from a Restaurateur."),
          _Section('2. PURPOSE',
              "These Terms and Conditions govern the use of the Dios Délices Platform and the relationships between Users. Use of the Platform implies full and unconditional acceptance of these Terms."),
          _Section('3. REGISTRATION',
              "Registration is free. The Customer must be at least 16 years old. Information provided during registration must be accurate. The Customer is responsible for keeping their login credentials confidential."),
          _Section('4. ORDERS',
              "The Customer selects dishes, validates their cart, and confirms their order. The order is transmitted to the Restaurateur, who may accept or refuse it. The Customer receives a confirmation. In case of unavailability, the Restaurateur informs the Customer."),
          _Section('5. PRICES AND PAYMENT',
              "Prices are displayed in Euros (EUR) for France and in CFA Francs (XOF) for Côte d'Ivoire and Benin. Two payment methods are available:\n\n• Cash on delivery: cash or Mobile Money upon receipt of the order.\n• Online payment: via CinetPay, an accredited payment provider, by Mobile Money (Orange Money, Airtel Money, M-Pesa, Africell).\n\nDelivery fees are indicated before order confirmation. Online payment is processed by CinetPay; Dios Délices does not store any banking data."),
          _Section('6. DELIVERY',
              "Delivery is carried out by an independent Driver. Timeframes are indicative. The Customer must check the condition of the dishes upon receipt. Any complaint must be made within 24 hours of delivery."),
          _Section('7. RIGHT OF WITHDRAWAL',
              "In accordance with Article L.221-28 of the French Consumer Code, the right of withdrawal does not apply to perishable goods. No refund is due except for errors attributable to the Restaurateur or lack of conformity."),
          _Section('8. RESTAURATEUR RESPONSIBILITY',
              "The Restaurateur is solely responsible for the quality, hygiene, and conformity of the dishes offered. They guarantee compliance with health standards in force in their country of operation. They must hold the necessary authorizations to operate their business."),
          _Section('9. PLATFORM RESPONSIBILITY',
              "Dios Délices acts as an intermediary. The Platform cannot be held responsible for disputes between Customer and Restaurateur, nor for accidents occurring during delivery. The Platform connects parties without intervening in the commercial transaction."),
          _Section('10. DATA PROTECTION',
              "Personal data is processed in accordance with the GDPR (EU), Law No. 2013-450 (Côte d'Ivoire), and Law No. 2017-20 (Benin). See our Privacy Policy. The Customer has the right to access, rectify, object, erase, and port their data."),
          _Section('11. INTELLECTUAL PROPERTY',
              "All elements of the Platform (logo, design, source code) are the exclusive property of Dios Délices. Any reproduction is prohibited without authorization."),
          _Section('12. APPLICABLE LAW',
              "For users in France: French law, Paris courts. For Côte d'Ivoire: Ivorian law, Abidjan courts. For Benin: Beninese law, Cotonou courts. For any other country: French law."),
          _Section('13. MEDIATION',
              "In the event of an unresolved dispute, the Customer may have free recourse to the competent consumer mediator. In France: www.mediation-conso.fr. The Customer may also use the European online dispute resolution platform: ec.europa.eu/consumers/odr."),
          _Section('14. CHANGES TO TERMS',
              "Dios Délices reserves the right to modify these Terms at any time. Users will be informed of changes. Continued use of the Platform constitutes acceptance of the new Terms."),
          const SizedBox(height: 16),
          Text(l10n.cgv_last_update,
              style: AppTypography.bodyMedium(
                      color: AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle))
                  .copyWith(fontSize: 12)),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppTypography.labelMedium(
                    color:
                        AppColors.resolve(AppColors.brand, AppDarkColors.brand))
                .copyWith(fontSize: 16)),
        const SizedBox(height: 6),
        Text(content,
            style: AppTypography.bodyMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))
                .copyWith(fontSize: 14, height: 1.5)),
      ]),
    );
  }
}
