import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Politique de confidentialité'), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Section('1. RESPONSABLE DU TRAITEMENT', "Dios Délices\nEmail : contact@diosdelices.com\n\nLe responsable de traitement s'engage à respecter les réglementations suivantes :\n• Règlement Général sur la Protection des Données (RGPD - UE 2016/679)\n• Loi n°2013-450 relative à la protection des données personnelles (Côte d'Ivoire)\n• Loi n°2017-20 portant code du numérique (Bénin)"),
          _Section('2. DONNÉES COLLECTÉES', "Nous collectons les données strictement nécessaires au fonctionnement du service :\n\n• Identité : nom, prénom, username\n• Contact : email, numéro de téléphone\n• Adresse de livraison\n• Données de commande : historique, plats commandés, montants\n• Données de connexion : date, heure, adresse IP\n• Données de paiement : référence de transaction (pas de données bancaires stockées)\n• Géolocalisation : position du livreur pendant la livraison uniquement\n\nÂge minimum : 16 ans. Aucune donnée de mineur de moins de 16 ans n'est collectée."),
          _Section('3. FINALITÉS DU TRAITEMENT', "Vos données sont traitées pour :\n\n• Créer et gérer votre compte utilisateur\n• Traiter vos commandes et assurer la livraison\n• Communiquer avec vous (notifications, service client)\n• Améliorer nos services (statistiques anonymisées)\n• Respecter nos obligations légales (facturation, archivage)\n• Assurer la sécurité de la Plateforme"),
          _Section('4. BASE LÉGALE', "Les traitements sont fondés sur :\n\n• L'exécution du contrat (commande, livraison)\n• Le consentement explicite (donné lors de l'inscription)\n• L'intérêt légitime (sécurité, amélioration du service)\n• L'obligation légale (conservation des factures)"),
          _Section('5. DESTINATAIRES DES DONNÉES', "Vos données sont accessibles aux destinataires suivants :\n\n• Les Restaurateurs (pour traiter votre commande)\n• Les Livreurs (pour assurer la livraison)\n• Back4App (hébergement cloud — serveurs aux États-Unis/Canada)\n\nNous ne vendons ni ne louons vos données à des tiers. Aucun transfert de données hors UE/Afrique n'est effectué sans garanties appropriées."),
          _Section("6. DURÉE DE CONSERVATION", "• Données de compte : durée d'utilisation + 3 ans après la dernière activité\n• Données de commande : 10 ans (obligation légale de conservation des factures)\n• Données de connexion : 1 an\n• Données de géolocalisation : supprimées après la livraison\n• En cas de suppression de compte : les données sont anonymisées ou supprimées sous 30 jours, sauf obligation légale de conservation."),
          _Section("7. VOS DROITS", "Conformément aux réglementations applicables, vous disposez des droits suivants :\n\n• Droit d'accès : obtenir une copie de vos données\n• Droit de rectification : corriger vos données inexactes\n• Droit à l'effacement (droit à l'oubli) : demander la suppression de vos données\n• Droit à la portabilité : recevoir vos données dans un format structuré\n• Droit d'opposition : vous opposer au traitement de vos données\n• Droit de retrait du consentement : à tout moment\n\nPour exercer ces droits, utilisez la fonction « Exporter mes données » dans l'application ou contactez-nous à contact@diosdelices.com. Réponse sous 30 jours maximum."),
          _Section("8. SÉCURITÉ", "Nous mettons en œuvre des mesures techniques et organisationnelles appropriées pour protéger vos données :\n\n• Chiffrement des communications (HTTPS)\n• Authentification sécurisée\n• Accès restreint aux données personnelles\n• Audit des accès\n• Pseudonymisation des données lorsque possible"),
          _Section('9. COOKIES ET TRACEURS', "L'application utilise des cookies techniques strictement nécessaires à son fonctionnement. Aucun cookie publicitaire ou de tracking tiers n'est utilisé sans consentement préalable. Vous pouvez désactiver les cookies dans les paramètres de votre appareil."),
          _Section('10. NOTIFICATION DE VIOLATION', "En cas de violation de données personnelles, nous notifierons les autorités compétentes (CNIL en France, ARTCI en Côte d'Ivoire, APDP au Bénin) dans les 72 heures, et les personnes concernées si la violation présente un risque élevé pour leurs droits et libertés."),
          _Section("11. DÉLÉGUÉ À LA PROTECTION DES DONNÉES", "Pour toute question relative à la protection des données, contactez le DPO :\nEmail : dpo@diosdelices.com\nAdresse postale : à communiquer sur demande."),
          _Section('12. RÉCLAMATIONS', "Si vous estimez que vos droits ne sont pas respectés, vous pouvez introduire une réclamation auprès de l'autorité de contrôle compétente :\n• France : CNIL (www.cnil.fr)\n• Côte d'Ivoire : ARTCI (www.artci.ci)\n• Bénin : APDP (www.apdp.bj)"),
          _Section('13. MODIFICATIONS', "Cette politique peut être modifiée. Les utilisateurs seront informés des changements majeurs. Dernière mise à jour : juin 2026."),
          SizedBox(height: 32),
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
      ]),
    );
  }
}
