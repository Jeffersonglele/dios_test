import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CGVPageFR extends StatelessWidget {
  const CGVPageFR({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conditions générales de vente')),
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('1. DÉFINITIONS', "• « Plateforme » : l'application mobile Dios Délices.\n• « Restaurateur » : personne physique ou morale proposant des plats via la Plateforme.\n• « Client » : personne commandant des plats via la Plateforme.\n• « Livreur » : personne assurant la livraison des commandes.\n• « Commande » : achat de plats effectué par un Client auprès d'un Restaurateur."),
          _Section('2. OBJET', "Les présentes CGV régissent l'utilisation de la Plateforme Dios Délices et les relations entre les Utilisateurs. L'utilisation de la Plateforme emporte acceptation pleine et entière des CGV."),
          _Section('3. INSCRIPTION', "L'inscription est gratuite. Le Client doit être âgé d'au moins 16 ans. Les informations fournies lors de l'inscription doivent être exactes. Le Client est responsable de la confidentialité de ses identifiants."),
          _Section('4. COMMANDES', "Le Client sélectionne les plats, valide son panier et confirme sa commande. La commande est transmise au Restaurateur qui peut l'accepter ou la refuser. Le Client reçoit une confirmation. En cas d'indisponibilité, le Restaurateur en informe le Client."),
          _Section('5. PRIX ET PAIEMENT', "Les prix sont affichés en Euros (EUR) pour la France et en Francs CFA (XOF) pour la Côte d'Ivoire et le Bénin. Deux modes de paiement sont proposés :\n\n• Paiement à la livraison : espèces ou Mobile Money à la réception de la commande.\n• Paiement en ligne : via Fedapay, prestataire de paiement agréé, par Mobile Money ou carte bancaire.\n\nLes frais de livraison sont indiqués avant validation de la commande. Le paiement en ligne est traité par Fedapay ; Dios Délices ne stocke aucune donnée bancaire."),
          _Section('6. LIVRAISON', "La livraison est effectuée par un Livreur indépendant. Les délais sont indicatifs. Le Client doit vérifier l'état des plats à réception. Toute réclamation doit être formulée dans les 24h suivant la livraison."),
          _Section('7. DROIT DE RÉTRACTATION', "Conformément à l'article L.221-28 du Code de la consommation (France), le droit de rétractation ne s'applique pas aux denrées périssables. Aucun remboursement n'est dû sauf erreur imputable au Restaurateur ou défaut de conformité."),
          _Section('8. RESPONSABILITÉ DU RESTAURATEUR', "Le Restaurateur est seul responsable de la qualité, de l'hygiène et de la conformité des plats proposés. Il garantit respecter les normes sanitaires en vigueur dans son pays d'exercice. Il doit détenir les autorisations nécessaires à l'exercice de son activité."),
          _Section('9. RESPONSABILITÉ DE LA PLATEFORME', "Dios Délices agit en tant qu'intermédiaire. La Plateforme ne saurait être tenue responsable des litiges entre Client et Restaurateur, ni des accidents survenus lors de la livraison. La Plateforme met en relation les parties sans intervenir dans la transaction commerciale."),
          _Section('10. PROTECTION DES DONNÉES', "Les données personnelles sont traitées conformément au RGPD (UE), à la Loi n°2013-450 (Côte d'Ivoire) et à la Loi n°2017-20 (Bénin). Voir notre Politique de Confidentialité. Le Client dispose d'un droit d'accès, de rectification, d'opposition, d'effacement et de portabilité de ses données."),
          _Section('11. PROPRIÉTÉ INTELLECTUELLE', "Tous les éléments de la Plateforme (logo, design, code source) sont la propriété exclusive de Dios Délices. Toute reproduction est interdite sans autorisation."),
          _Section('12. LOI APPLICABLE', "Pour les utilisateurs en France : droit français, tribunaux de Paris. Pour la Côte d'Ivoire : loi ivoirienne, tribunaux d'Abidjan. Pour le Bénin : loi béninoise, tribunaux de Cotonou. Pour tout autre pays : droit français."),
          _Section('13. MÉDIATION', "En cas de litige non résolu, le Client peut recourir gratuitement au Médiateur de la consommation compétent. En France : www.mediation-conso.fr. Le Client peut également utiliser la plateforme européenne de règlement des litiges : ec.europa.eu/consumers/odr."),
          _Section('14. MODIFICATION DES CGV', "Dios Délices se réserve le droit de modifier les présentes CGV à tout moment. Les Utilisateurs seront informés des modifications. L'utilisation continue de la Plateforme vaut acceptation des nouvelles CGV."),
          const SizedBox(height: 16),
          Text('Dernière mise à jour : juin 2026',
              style: AppTypography.bodyMedium(color: AppColors.inkSubtle).copyWith(fontSize: 12)),
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
