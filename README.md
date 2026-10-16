# Dios Délices — backend

API Node.js de Dios Délices, plateforme de livraison de repas (restaurants et
vendeurs particuliers) en RDC. Le Bénin sert de pays de test.

- **Stack** : Node.js / Express, Prisma 6, PostgreSQL + PostGIS (Aiven),
  Socket.io pour le temps réel, Nyole pour le Mobile Money.
- **Préfixe des routes** : `/api/v1`. Documentation Swagger servie par l'API.
- **Déploiement** : Render, via `docker-start.sh`, qui applique les migrations
  (`npx prisma migrate deploy`) puis démarre le serveur.

Documents détaillés :

| Document | Contenu |
|---|---|
| [LOCAL_SETUP.md](LOCAL_SETUP.md) | Démarrage local (Docker, `.env`, première ville) |
| [DELIVERY_AND_GEOLOCATION.md](DELIVERY_AND_GEOLOCATION.md) | Décisions produit sur les zones, le dispatch et le cycle de livraison |
| [PAYMENT_ARCHITECTURE.md](PAYMENT_ARCHITECTURE.md) | Intégration Nyole, webhooks, espèces et portefeuille |

Ce README résume les règles **telles qu'elles sont codées aujourd'hui**. En cas
d'écart avec un autre document, c'est lui qui fait foi.

---

## 1. Frais de livraison

Le serveur calcule toujours les frais. L'app affiche un devis
(`POST /delivery/quote`), mais à la création de la commande le serveur
**recalcule** les frais : ceux envoyés par l'app ne sont jamais utilisés.
Le code est dans `src/services/delivery-pricing.service.js`.

### Formule

```text
distance estimée = distance à vol d'oiseau (restaurant → adresse du client)
                   × ROUTE_DISTANCE_FACTOR (1,25 par défaut)

si distance estimée > distance maximale (10 km)  → livraison indisponible

frais bruts = (prise en charge + prix au km × distance facturée + surcharge carburant)
              × multiplicateur d'affluence × multiplicateur météo
frais       = max(minimum, arrondi au multiple de 50 supérieur des frais bruts)
```

La distance facturée commence **au premier mètre** (aucune distance incluse) :
un livreur doit toujours rejoindre le restaurant, d'où le minimum.

### Grilles par défaut

| Pays | Devise | Prise en charge | Prix au km | Minimum | Distance max. | Arrondi |
|---|---|---:|---:|---:|---:|---:|
| Bénin | XOF (FCFA) | 250 | 150 | 400 | 10 km | 50 |
| RDC *(provisoire)* | CDF | 1 200 | 700 | 2 000 | 10 km | 50 |

La grille Bénin est calée sur le prix d'une course de moto-taxi locale. La
grille RDC est une conversion de la grille Bénin, **à valider sur place**.

Exemples (distance estimée) :

| Distance | 0,5 km | 1 km | 3 km | 5 km | 8 km | 10 km |
|---|---:|---:|---:|---:|---:|---:|
| Bénin (FCFA) | 400 | 400 | 700 | 1 000 | 1 450 | 1 750 |
| RDC (CDF) | 2 000 | 2 000 | 3 300 | 4 700 | 6 800 | 8 200 |

> **Kinshasa a sa propre grille en base** (`delivery_configs`, ville n° 1),
> qui prime sur la grille RDC ci-dessus : 1 000 CDF incluant les 2 premiers
> km, puis 500 CDF/km, minimum 1 000 CDF, livraison jusqu'à 25 km. Cotonou
> utilise la grille par défaut du Bénin.

### Quelle grille s'applique ?

1. **Frais fixes du restaurant.** Si `restaurants.deliveryFee` est renseigné,
   ce montant s'applique quelle que soit la distance (la distance maximale
   reste vérifiée).
2. **Configuration de la ville en base** (`delivery_configs`, ligne `active`
   de la ville du client), sinon la configuration globale (`cityId` vide).
   Elle n'est retenue que si sa devise correspond au pays ; une ligne en CDF
   n'est jamais appliquée à un restaurant béninois.
3. **Grille par défaut** du pays (tableau ci-dessus).

Le **pays** vient d'abord du restaurant (`country`, puis `currency`), puis de
la ville. Un restaurant béninois rattaché par erreur à une ville de RDC garde
donc le tarif béninois.

### Cas particuliers

- **Position GPS manquante** (restaurant ou client) : forfait égal à la
  prise en charge de la grille, sans jamais descendre sous le minimum
  (400 FCFA au Bénin, 2 000 CDF en RDC). La réponse indique `noGpsFallback`.
- **Deux villes couvertes différentes** (restaurant à Kinshasa, client
  ailleurs) : livraison indisponible (`DIFFERENT_CITY`).
- **Ville sans zone cartographiée** (ex. Cotonou) : les deux positions sont
  connues, donc la livraison est quand même facturée à la distance
  (`ESTIMATED_ROAD_DISTANCE_UNMAPPED_CITY`).

### Modifier un tarif sans redéployer

Depuis l'app : **Admin → Configuration de livraison**. Chaque ville affiche
le tarif réellement appliqué, avec des exemples à 1, 3, 5 et 10 km, et la
grille se modifie ville par ville. Côté API, c'est une ligne
`delivery_configs` active pour la ville (`baseFee`, `perKmRate`,
`includedDistanceKm`, `minFee`, `maxDistanceKm`, `roundingIncrement`,
`currency`). Elle prend le pas sur la grille par défaut dès la requête
suivante. `GET /delivery-configs/active?cityId=…` renvoie le tarif
appliqué et sa source (`CITY_CONFIGURATION` ou `DEFAULT_CONFIGURATION`).

---

## 2. Commandes et paiements

Trois moyens de paiement (`paymentMethod`) :

| Mode | Statut initial | Déroulement |
|---|---|---|
| `CASH` (à la livraison) | `CONFIRMED_CASH` | Le livreur encaisse le total. Il est ajouté à son `cashOnHand` à la remise. Plafond d'espèces : 50 000 par livreur. |
| `NYOLE` (Mobile Money) | `AWAITING_PAYMENT` | Le client paie sur la page Nyole. Le webhook (ou la vérification) passe la commande à `PAID`. |
| `WALLET` (portefeuille) | `PAID` | Le solde est débité dans la même transaction que la création de la commande. |

**Répartition** : le restaurant reçoit le prix des plats moins la réduction
promo (`restaurantShare`) ; le livreur reçoit les frais de livraison
(`deliveryFeeShare`). Aucun frais de plateforme n'est ajouté au client. Le
pourboire est un paiement séparé, versé à 100 % au livreur.

**Statuts** : `CONFIRMED_CASH` / `AWAITING_PAYMENT` / `PAID` → `EN_PREPARATION`
→ `READY` → `DELIVERED`, ou `REFUSED` / `CANCELLED`.

- Le client peut annuler tant que la préparation n'a pas commencé.
- Le restaurant ne peut préparer qu'une commande payée ou en espèces, et peut
  refuser jusqu'à ce qu'elle soit prête.
- Une commande payée en ligne puis annulée ou refusée est **remboursée sur le
  portefeuille** (Nyole n'a pas d'API de remboursement).

**Recharge du portefeuille** : `POST /wallet/top-ups` ouvre une session Nyole.
Le portefeuille est crédité une seule fois, au paiement confirmé. Montants
par devise : CDF de 1 000 à 2 000 000, USD de 1 à 1 000, XOF de 500 à 500 000.
On peut les changer avec `WALLET_TOPUP_MIN_<DEVISE>` / `WALLET_TOPUP_MAX_<DEVISE>`.
La devise du portefeuille suit le pays du compte.

---

## 3. Codes promo

Le code est dans `src/services/promo.service.js`.

- **Vérification depuis le panier** : `POST /promo-codes/validate` avec
  `{ code, subtotal }`, où le sous-total couvre les plats seulement, hors
  livraison. La réponse donne la réduction (`discountAmount`) ou un message
  clair : expiré, pas encore valable, minimum non atteint, limite atteinte,
  déjà utilisé.
- **À la commande**, le serveur revérifie le code et **recalcule** la
  réduction. Le champ `reduction` envoyé par l'app est ignoré.
- **Calcul de la réduction** :
  - un pourcentage des plats, ou un montant fixe ;
  - arrondie à l'unité ;
  - jamais supérieure au prix des plats ;
  - ne porte jamais sur la livraison.
- **Limite d'utilisations** (`maxUses`) : `usedCount` augmente dans la même
  transaction que la commande, donc deux commandes simultanées ne peuvent pas
  dépasser la limite. Une commande annulée ou refusée rend son utilisation.
- **Un code par client** : un même client ne peut utiliser un code qu'une fois.
- **Création et modification** des codes : admin uniquement (`/promo-codes`).
- **Parrainage** : un seul code `REF-<userId>-…` par compte, créé pour le
  compte connecté.

> À décider : la réduction est aujourd'hui retirée des revenus du restaurant.
> Une réduction fixe n'a pas de devise ; préférer des pourcentages ou des
> codes par pays.

---

## 4. Restaurants et demande vendeur

- **Création et modification** : `POST` / `PATCH /restaurants/legacy[/:id]`.
  - Seul le propriétaire modifie sa fiche.
  - Il ne peut pas fixer lui-même la validation (`valid`), la note, les
    compteurs, le badge Pro, la ville ni la devise. La devise découle du pays
    du compte.
  - Un compte n'a qu'un restaurant : une nouvelle demande reprend la fiche
    existante.
- **Ville** : déduite de la position GPS, sinon c'est l'unique ville active du
  pays (ex. Cotonou).
- **Validation admin** : `PATCH /admin/restaurants/:id` avec `valid` à `1`
  (validé) ou `2` (refusé, avec motif). Le restaurateur est notifié par email.
  - Une demande refusée puis corrigée repasse automatiquement en attente (`0`).
  - L'équipe reçoit un email à chaque nouvelle demande (voir
    `ADMIN_NOTIFICATION_EMAIL`).
- **Annuler une demande** : `DELETE /restaurants/legacy/:id` par le
  propriétaire, possible uniquement si le restaurant n'est pas validé. Le
  compte redevient client et un nouveau jeton est renvoyé.
- **État du compte** pour l'app : `GET /auth/account-state` renvoie le rôle,
  l'état de la demande vendeur, l'état de la demande Pro et le dossier livreur.
- **Données privées** : l'IBAN, le numéro Mobile Money, le RCCM et le motif de
  refus ne sont visibles que par le propriétaire et l'admin. `?showAll=true`
  n'est honoré que pour l'admin, ou pour le propriétaire sur sa propre fiche.
- **Devenir Pro** : `POST /pro-documents`.
  - Réservé au propriétaire d'un restaurant validé, avec une seule demande en
    attente à la fois.
  - Pièces demandées : pièce d'identité et RCCM, en PDF ou en photo.
  - Le badge Pro (`isPro`) est accordé uniquement par la validation admin de
    ces documents, et non plus par la validation du restaurant.
- **Envoi de justificatifs** : `POST /uploads/document` accepte PDF, JPEG, PNG
  et WebP, 5 Mo maximum.

---

## 5. Livreurs

### Dossier obligatoire

Un compte livreur (inscription avec `accountType: livreur` et `vehicleType`)
doit envoyer son dossier avant de travailler :
`POST /courier-application`.

- **Photo du visage**, obligatoire. Elle devient la photo de profil, visible
  par le client et le restaurant.
- **Pièce d'identité**.
- **Permis de conduire et plaque d'immatriculation**, sauf à vélo.

L'admin valide ou refuse le dossier, avec motif, via
`PATCH /admin/delivery-documents/validate` (`VALIDATED` / `REJECTED`). Les
écrans admin utilisent `GET /admin/couriers` et `GET /admin/couriers/:userId`.

Statut d'identité (`users.identity`) : `Verified`, `En attente` ou `Rejected`.

**Tant que le dossier n'est pas validé**, le livreur ne peut ni se mettre en
ligne, ni voir ni accepter de courses (`requireVerifiedCourier`), et le
dispatch ne lui propose rien. Se mettre hors ligne reste toujours possible.

### Attribution d'une course

Quand le restaurant passe la commande à `READY`, une livraison `SEARCHING` est
créée. Le livreur l'obtient de deux façons :

1. **Proposition automatique.** La course est proposée aux
   `DISPATCH_OFFER_LIMIT` livreurs (3 par défaut) qui remplissent ces
   conditions :
   - validés, en ligne et libres ;
   - dans la même ville ;
   - position envoyée depuis moins de `COURIER_LOCATION_MAX_AGE_MINUTES`
     (5 min) ;
   - classés par distance jusqu'au restaurant.

   Une proposition expire au bout de `DISPATCH_OFFER_TTL_SECONDS` (60 s).
   Une tâche (`src/cron/dispatch.cron.js`) relance les courses sans
   proposition valide toutes les `DISPATCH_SWEEP_INTERVAL_SECONDS` (15 s),
   jamais deux fois au même livreur, pendant `DISPATCH_MAX_AGE_MINUTES`
   (180 min).
2. **Liste des courses disponibles** : `GET /deliveries/available` (rayon de
   5 km), puis `POST /deliveries/:orderId/accept`.

Dans les deux cas, l'acceptation **réserve la commande de façon atomique** :
- deux livreurs ne peuvent pas obtenir la même commande, et une commande
  annulée ne peut plus être acceptée ;
- le livreur est enregistré sur la commande (`delivererId`) ;
- ses autres propositions sont closes.

### Suivi et remise

- **Statuts de la course** : `ASSIGNED` → `AT_PICKUP` → `PICKED_UP` →
  `IN_TRANSIT`. Le passage à `DELIVERED` ne se fait **que** par le code du
  client : `POST /orders/:id/verify-retrieval`, avec une photo de preuve.
- **Position en direct** : le livreur émet `courier_location_update` sur le
  socket. Le serveur la relaie (`courier_moved`) au salon
  `order_tracking_<id>`, réservé au client, au restaurant, au livreur et à
  l'admin.
- **`GET /orders/:id/tracking`** renvoie :
  - le point de retrait (restaurant) et le point de livraison (client) ;
  - le livreur : nom, photo, véhicule, plaque, téléphone pour le client et le
    restaurant, et sa dernière position.

---

## 6. Avis clients

`POST /reviews` (cible : 1 = restaurant, 2 = plat, 3 = livreur), avec
`GET /reviews` et `GET /reviews/summary`.

- Il faut une commande livrée, avec un seul avis par commande.
- La note moyenne du restaurant ou du plat est recalculée à chaque avis.
- Le nom affiché est « Prénom N. ».

---

## 7. Comptes et pays

- **Pays ouverts** : RDC (`CDF`) et Bénin (`XOF`), définis dans
  `src/services/country.service.js`. Un autre pays est refusé à l'inscription.
- **Ville** : à l'inscription, c'est l'unique ville active du pays quand il
  n'y en a qu'une ; sinon elle est fixée par l'adresse.
- **Rôles** : 1 et 4 = admin, 2 = client, 3 = restaurateur, 5 = livreur.
  - Une validation admin change le rôle (restaurant validé → restaurateur).
  - L'app le détecte via `/auth/account-state` et demande une reconnexion.

---

## 8. Espace admin et super admin

**Rôles** : `1` = admin d'un pays, `4` = super admin (tous les pays). Ces
valeurs se règlent avec `ADMIN_ROLE_IDS` et `SUPER_ADMIN_ROLE_IDS`. Le code est
dans `src/services/admin-scope.service.js`.

- **Un admin ne gère que son pays**, et le serveur l'impose quel que soit
  le filtre envoyé par l'app :
  - les listes (utilisateurs, livreurs, demandes Pro, dossiers livreurs,
    journal d'audit) et les statistiques sont limitées à son pays ;
  - valider ou refuser un restaurant, une demande Pro ou un dossier livreur
    hors de son pays renvoie 403 ;
  - le pays de l'admin est lu en base, jamais dans la requête.
- **Réservé au super admin** :
  - création d'un administrateur (`POST /admin/users`) : un mot de passe
    temporaire est envoyé par email, à changer à la première connexion ;
  - indicateurs globaux (`GET /admin/super-stats`) : paiements, commissions
    de la semaine, litiges ;
  - suppression d'un compte administrateur.
- **Suppression d'un compte** (`DELETE /admin/users/:id/force`) : suppression
  logique du profil et du compte de connexion, qui ne peut plus se connecter.
  On ne peut pas se supprimer soi-même.
- **Journal d'audit** (`GET /audit-logs`) : chaque validation ou refus, chaque
  changement d'identité ou de profil, chaque suppression, création d'admin ou
  email envoyé est enregistré, avec l'auteur et le pays.
- **Envoi d'email** (`POST /admin/send-email`) : l'email part réellement
  (avant, la route répondait « envoyé » sans rien envoyer).
- **Données sensibles** : les mots de passe chiffrés ne sont plus jamais
  renvoyés dans les listes d'utilisateurs.

---

## 9. Variables d'environnement utiles

Les variables de base (`DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS`,
Nyole, SMTP / Brevo, stockage) sont décrites dans
[LOCAL_SETUP.md](LOCAL_SETUP.md). Celles liées aux règles ci-dessus :

| Variable | Défaut | Rôle |
|---|---|---|
| `ADMIN_NOTIFICATION_EMAIL` | *(vide)* | Adresse(s) de l'équipe, séparées par des virgules, prévenues de chaque nouvelle demande vendeur ou dossier livreur. Vide = pas d'email. |
| `ADMIN_ROLE_IDS` | `1,4` | Rôles administrateurs. |
| `SUPER_ADMIN_ROLE_IDS` | `4` | Rôles super administrateurs (tous les pays). |
| `ROUTE_DISTANCE_FACTOR` | `1.25` | Passage de la distance à vol d'oiseau à une distance routière estimée. |
| `DISPATCH_OFFER_LIMIT` | `3` | Livreurs sollicités par vague de propositions. |
| `DISPATCH_OFFER_TTL_SECONDS` | `60` | Durée de validité d'une proposition. |
| `DISPATCH_SWEEP_INTERVAL_SECONDS` | `15` | Fréquence de relance des propositions (`0` = désactivé). |
| `DISPATCH_MAX_AGE_MINUTES` | `180` | Au-delà, une course n'est plus relancée automatiquement. |
| `COURIER_LOCATION_MAX_AGE_MINUTES` | `5` | Âge maximal de la position d'un livreur pour recevoir une proposition. |
| `WALLET_TOPUP_MIN_<DEVISE>` / `WALLET_TOPUP_MAX_<DEVISE>` | voir § 2 | Limites de recharge du portefeuille. |
| `TIP_MAX_CDF` | `50000` | Pourboire maximal. |

---

## 10. Migrations récentes

Les migrations sont appliquées automatiquement au déploiement.

| Migration | Contenu |
|---|---|
| `20261015120000_comment_reviews` | Avis : note, étiquettes, commande et nom affiché sur `comments`, un avis par commande. |
| `20261016120000_courier_onboarding` | Dossier livreur : `vehicle_type` et `vehicle_plate` sur `users` ; `license_url`, `vehicle_type` et `vehicle_plate` sur `identities`. |
