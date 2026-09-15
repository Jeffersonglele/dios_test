# Paiements RDC — stratégie avant implémentation

Ce document définit le parcours de paiement de Dios Delices en République
Démocratique du Congo (RDC). Les montants sont toujours exprimés en francs
congolais (`CDF`).

## État temporaire de l'intégration

Le backend possède une adaptation CinetPay en mode `mock`. Elle permet de
tester le cycle complet de tentative, confirmation simulée, contrôle serveur
et mise à jour de commande, sans clé réelle et sans appel à CinetPay. Les
variables d'exemple sont dans `.env.example`; les vraies clés ne seront
introduites qu'après l'ouverture d'un compte marchand auprès de l'agrégateur
final retenu.

Les endpoints sont :

- `POST /api/v1/payments/cinetpay/initialize` ;
- `GET /api/v1/payments/cinetpay/:transactionId` ;
- `POST /api/v1/payments/cinetpay/webhook` ;
- `POST /api/v1/payments/cinetpay/mock/:transactionId/confirm` (mode mock
  seulement).

Le backend représente également le règlement à la remise : une commande
`CASH` crée un encaissement attendu, que seul le livreur assigné peut confirmer
après l’état `DELIVERED`, sans jamais pouvoir modifier le total. Le pourboire
numérique est une seconde tentative distincte, disponible uniquement après
livraison via `POST /api/v1/payments/cinetpay/tips/initialize`. Il ne modifie
pas le total de la commande et, une fois vérifié, est marqué `PAID` pour le
livreur concerné.

Le nom CinetPay est une façade provisoire : le contrôleur et le grand livre des
transactions doivent rester indépendants de l'agrégateur pour permettre le
remplacement par AvadaPay/UniPesa ou une autre solution sans modifier Flutter.

Le backend expose déjà les contrats UX du portefeuille, mais bloque toute
recharge (`503`) : `GET /api/v1/wallet/me`, son grand livre, et les numéros
Mobile Money `MPESA`, `ORANGE_MONEY`, `AIRTEL_MONEY` au format `+243…`. Aucun
solde ni débit ne peut être créé par ces routes tant que l’activation n’est pas
expressément décidée.

## Décision de lancement

Le client voit un seul total clair :

```text
total de commande = montant des repas + frais de livraison
```

Le pourboire est facultatif et intervient après une livraison réussie, dans une
transaction distincte. Aucun honoraire de plateforme n'est ajouté au panier.

Les trois moyens de paiement visibles sont :

| Moyen | Version de lancement | Parcours |
|---|---|---|
| Espèces | Oui | Le client paie le total au livreur à la remise du repas. |
| Mobile Money | Oui, via CinetPay Collect | Le client choisit son réseau et confirme le paiement dans le parcours CinetPay. |
| Carte bancaire | Oui, via CinetPay Collect si le contrat l'autorise | Le client saisit les données de sa carte uniquement sur la page CinetPay. |
| Portefeuille Dios | Écrans et modèle conçus dès maintenant ; activation conditionnelle | Activé seulement après validation juridique, financière et technique. |

Les canaux actuellement documentés par CinetPay pour la RDC sont Orange Money
CD, M-Pesa CD et Airtel Money CD en CDF. Africell ne doit pas être affiché tant
qu'il n'est pas explicitement activé pour le compte marchand Dios Delices.

## CinetPay Collect : paiement Mobile Money et carte

CinetPay Collect est utilisé comme page de paiement hébergée. L'application
Flutter ne contient jamais les secrets CinetPay, ni le numéro de carte, ni le
CVV du client.

```text
Application → API Dios Delices → créer PaymentAttempt en base
            → API CinetPay Collect → retourner payment_url
Application → ouvrir la page CinetPay
CinetPay → webhook backend Dios Delices → vérifier la transaction CinetPay
Backend → marquer le paiement PAYE et confirmer la commande
```

Règles impératives :

1. Le backend crée une référence de transaction unique avant d'ouvrir la page
   de paiement et enregistre le montant, la devise CDF, la commande et le type
   de paiement.
2. Le retour de navigateur/app n'est jamais une preuve de paiement.
3. Le webhook CinetPay est contrôlé par HMAC, puis le backend appelle l'API de
   vérification CinetPay avec la référence de transaction.
4. Le traitement est idempotent : plusieurs webhooks pour la même transaction
   ne créditent ni la commande ni un pourboire plusieurs fois.
5. Une commande prépayée ne passe à `PAYEE` qu'après vérification réussie côté
   serveur ; sinon elle reste en attente, échoue ou expire.

Une carte bancaire est donc possible sans que Dios Delices « connecte » ou
conserve une carte : CinetPay traite l'étape sensible. La mémorisation d'une
carte ou le paiement en un clic ne sera envisagé que si CinetPay confirme par
écrit une solution de tokenisation adaptée à la RDC. Ne jamais stocker PAN,
CVV, date d'expiration ou copie de carte dans PostgreSQL.

## Paiement en espèces

Le paiement en espèces ne passe pas par CinetPay.

```text
Commande créée avec paiement ESPECES
  → restaurant prépare
  → livreur remet le repas et encaisse le total affiché
  → livreur confirme encaissement / livraison
  → backend marque le paiement ESPECES_ENCAISSE
```

Le backend conserve le montant attendu, le montant encaissé, l'heure et le
livreur concerné. Toute différence ou annulation est un événement traçable ;
le livreur ne doit pas pouvoir modifier librement le montant de la commande.

## Portefeuille Dios : parcours produit inspiré du flux de référence

Le portefeuille peut reprendre le parcours simple observé dans le flux de
référence, avec l'adaptation RDC suivante :

```text
Portefeuille : solde CDF + historique des mouvements
  → Recharger
  → saisir le montant en CDF
  → choisir / ajouter un numéro Mobile Money
  → choisir Orange Money, M-Pesa ou Airtel Money
  → vérifier le récapitulatif
  → ouvrir le paiement CinetPay
  → reçu de succès ou d'échec
  → créditer le solde uniquement après vérification serveur
```

Les écrans à prévoir dans Flutter sont :

| Écran | Contenu et règle UX |
|---|---|
| `Portefeuille` | Solde disponible en CDF, bouton `Recharger`, historique et filtres par statut/date/type. |
| `Saisir le montant` | Clavier numérique, montant minimum/maximum configurable et bouton désactivé tant que le montant est invalide. |
| `Méthode de recharge` | Orange Money, M-Pesa et Airtel Money uniquement si activés pour le compte CinetPay Dios. |
| `Ajouter un numéro` | Libellé personnel et numéro au format RDC `+243…`; le numéro est affiché masqué ensuite. |
| `Vérifier la recharge` | Réseau, numéro masqué, compte portefeuille destinataire et montant exact avant redirection CinetPay. |
| `Détail de transaction` | Montant, opérateur, référence Dios/CinetPay, date, statut, support et lien vers l'historique. |

Une recharge doit toujours permettre un résultat clair : `EN_ATTENTE`, `PAYEE`,
`ECHOUE`, `ANNULEE` ou `EXPIREE`. Une tentative échouée ou annulée ne crédite
jamais le portefeuille, mais reste visible dans l'historique avec sa référence.

Le portefeuille client initial est limité à : recharger, payer une commande,
recevoir un remboursement lié à une commande et consulter son historique. Il
ne permet ni transfert entre utilisateurs, ni retrait en espèces, ni envoi vers
un numéro Mobile Money au lancement.

## Portefeuille Dios : conditions d'activation

Un portefeuille interne n'est pas un simple champ `balance` sur l'utilisateur.
Si Dios Delices reçoit, conserve puis permet de dépenser l'argent préchargé des
clients, il faut notamment gérer conformité, KYC, plafonds, remboursement,
fraude, réconciliation et règles locales applicables aux services financiers.

Avant toute implémentation, il faut obtenir une confirmation écrite de CinetPay
et un avis local compétent sur le montage autorisé en RDC : compte marchand,
partenaire agréé, monnaie électronique ou autre solution autorisée.

Une fois validé, le portefeuille suit ce modèle :

```text
recharge CinetPay vérifiée → écriture de crédit immuable dans le grand livre
paiement d'une commande → écriture de débit immuable et réservation des fonds
annulation / remboursement → écriture de crédit de compensation
```

Chaque mouvement porte une référence, un solde avant/après, la devise CDF, son
origine et son état. Le solde affiché est calculé depuis ce grand livre ; il ne
doit jamais être modifié directement.

## Pourboire post-livraison

Après l'état `LIVREE`, le client peut terminer sans pourboire ou en donner un.

- Si la commande est en espèces : le client peut remettre l'argent directement
  au livreur.
- Si le client choisit un pourboire numérique : le backend crée un nouveau
  `PaymentAttempt` de type `TIP`, puis lance CinetPay Collect.
- Si un portefeuille est un jour autorisé : le pourboire débite le grand livre
  du portefeuille.

Dans tous les cas, le pourboire reçu dans l'application appartient à 100 % au
livreur. Il ne modifie pas le prix de la commande déjà livrée.

## Reversements aux livreurs et vendeurs

La collecte auprès du client et le reversement aux livreurs/vendeurs sont deux
processus différents. CinetPay Règlements/Mass Payout peut ensuite servir à
verser les gains par Mobile Money, après activation du service, conformité KYC
et approvisionnement du compte marchand.

Chaque reversement doit avoir son propre cycle : `A_PAYER`, `ENVOYE`, `PAYE`,
`ECHOUE`, `ANNULE`, avec vérification serveur du retour prestataire. Les frais
Collect et Payout sont des coûts opérationnels : ils ne doivent pas devenir une
ligne supplémentaire inattendue pour le client.

## Modèles backend à prévoir

| Modèle | Finalité |
|---|---|
| `PaymentAttempt` | Une tentative CinetPay ou espèces liée à une commande ou un pourboire. |
| `PaymentWebhookEvent` | Journal idempotent des notifications reçues. |
| `MobileMoneyAccount` | Numéro Mobile Money RDC enregistré par le client, avec opérateur et libellé. |
| `WalletTopUp` | Recharge demandée, référence CinetPay, montant CDF et statut final. |
| `Tip` | Pourboire post-livraison, lié au client, livreur et à son paiement. |
| `Payout` | Reversement dû puis envoyé à un vendeur ou livreur. |
| `WalletAccount` et `WalletLedgerEntry` | Phase portefeuille uniquement, après validation réglementaire. |

## Éléments à obtenir avant le développement CinetPay

1. Compte marchand CinetPay RDC et KYC approuvé.
2. Contrat / offre écrite confirmant les canaux activés : Orange Money, M-Pesa,
   Airtel Money, Visa/Mastercard, CDF et éventuellement les reversements.
3. Barème réellement appliqué, délais de disponibilité des fonds, plafonds et
   politique de remboursements/chargebacks.
4. `site_id`, `api_key`, `secret_key` et URLs HTTPS publiques de test puis de
   production ; les secrets restent uniquement dans les variables d'environnement
   du backend.
5. Réponse écrite sur la possibilité ou non de proposer un portefeuille client
   Dios avec les fonds collectés.
