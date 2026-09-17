import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class LegalPageEN extends StatelessWidget {
  const LegalPageEN({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.legal_notice_title)),
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('Publisher',
              'Dios Délices\n\nLegal form: to be completed (EI, SARL, SAS, etc.)\nSIRET / SIREN: to be completed\nRCS: to be completed\nEU VAT ID: to be completed\nShare capital: to be completed\n\nRegistered office:\nto be completed\n\nPhone: to be completed\nEmail: contact@diosdelices.com'),
          _Section('Publication Director',
              'To be completed (name of legal representative)'),
          _Section('Hosting',
              'Back4App\nAddress: 440 N Wolfe Rd, Sunnyvale, CA 94085, USA\n\nServers located in the United States and Canada.\nA Data Processing Agreement (DPA) is in place in accordance with the GDPR.\n\nVercel Inc.\nAddress: 340 S Lemon Ave #4133, Walnut, CA 91789, USA\n\nUsed for hosting serverless functions (CinetPay API).'),
          _Section('Data Protection',
              'In accordance with the General Data Protection Regulation (GDPR - EU 2016/679), Law No. 2013-450 of Côte d\'Ivoire, and Law No. 2017-20 of Benin, you have rights over your personal data.\n\nData Protection Officer (DPO): to be appointed\nEmail: dpo@diosdelices.com\n\nProcessing register available upon request.\n\nA Data Protection Impact Assessment (DPIA) has been carried out for high-risk processing.\nTransfer outside the EU: Standard Contractual Clauses (SCC) are in place with our subcontractors.'),
          _Section('Intellectual Property',
              'All content of the application (logos, texts, source code, design) is protected by copyright and remains the exclusive property of Dios Délices. Any reproduction is prohibited without authorization.'),
          _Section('Mediation',
              'In accordance with the Consumer Code, in the event of an unresolved dispute, you may have free recourse to the competent consumer mediator.\n\nFrance: www.mediation-conso.fr\nEuropean online dispute resolution platform: ec.europa.eu/consumers/odr\n\nCôte d\'Ivoire: ARTCI (www.artci.ci)\nBenin: APDP (www.apdp.bj)'),
          _Section('Supervisory Authorities',
              'France: CNIL — 3 Place de Fontenoy, 75007 Paris (www.cnil.fr)\nCôte d\'Ivoire: ARTCI — Marcory Zone 4, Abidjan (www.artci.ci)\nBenin: APDP — Cotonou (www.apdp.bj)'),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title, content;
  const _Section(this.title, this.content);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: AppTypography.labelMedium(
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand))
                  .copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(content,
              style: AppTypography.bodyMedium()
                  .copyWith(fontSize: 14, height: 1.5)),
        ]),
      );
}
