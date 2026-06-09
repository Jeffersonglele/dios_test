import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class LegalPageFR extends StatelessWidget {
  const LegalPageFR({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.legal_notice_title)),
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('Éditeur', 'Dios Délices\n\nForme juridique : à compléter (EI, SARL, SAS, etc.)\nSIRET / SIREN : à compléter\nRCS : à compléter\nN° TVA intracommunautaire : à compléter\nCapital social : à compléter\n\nAdresse du siège social :\nà compléter\n\nTéléphone : à compléter\nEmail : contact@diosdelices.com'),
          _Section('Directeur de la publication', 'À compléter (nom du représentant légal)'),
          _Section('Hébergeur', 'Back4App\nAdresse : 440 N Wolfe Rd, Sunnyvale, CA 94085, USA\n\nServeurs situés aux États-Unis et au Canada.\nUn contrat de sous-traitance (DPA) est en place conformément au RGPD.\n\nVercel Inc.\nAdresse : 340 S Lemon Ave #4133, Walnut, CA 91789, USA\n\nUtilisé pour l\'hébergement des fonctions serverless (API Fedapay).'),
          _Section('Protection des données', 'Conformément au Règlement Général sur la Protection des Données (RGPD - UE 2016/679), à la Loi n°2013-450 de Côte d\'Ivoire et à la Loi n°2017-20 du Bénin, vous disposez de droits sur vos données personnelles.\n\nDélégué à la Protection des Données (DPO) : à nommer\nEmail : dpo@diosdelices.com\n\nRegistre des traitements disponible sur demande.\n\nUne analyse d\'impact (DPIA) a été réalisée pour les traitements à risque.\nTransfert hors UE : des clauses contractuelles types (SCC) sont en place avec nos sous-traitants.'),
          _Section('Propriété intellectuelle', 'L\'ensemble du contenu de l\'application (logos, textes, code source, design) est protégé par le droit d\'auteur et reste la propriété exclusive de Dios Délices. Toute reproduction est interdite sans autorisation.'),
          _Section('Médiation', 'Conformément au Code de la consommation, en cas de litige non résolu, vous pouvez recourir gratuitement au médiateur de la consommation compétent.\n\nFrance : www.mediation-conso.fr\nPlateforme européenne de règlement des litiges : ec.europa.eu/consumers/odr\n\nCôte d\'Ivoire : ARTCI (www.artci.ci)\nBénin : APDP (www.apdp.bj)'),
          _Section('Autorités de contrôle', 'France : CNIL — 3 Place de Fontenoy, 75007 Paris (www.cnil.fr)\nCôte d\'Ivoire : ARTCI — Marcory Zone 4, Abidjan (www.artci.ci)\nBénin : APDP — Cotonou (www.apdp.bj)'),
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
      Text(title, style: AppTypography.labelMedium(color: AppColors.brand).copyWith(fontSize: 16)),
      const SizedBox(height: 6),
      Text(content, style: AppTypography.bodyMedium().copyWith(fontSize: 14, height: 1.5)),
    ]),
  );
}
