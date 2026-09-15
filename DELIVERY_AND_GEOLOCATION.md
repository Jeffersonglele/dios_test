# Livraison et géolocalisation — décisions produit

Ce document fixe les principes métier de Dios Delices avant l'implémentation
PostgreSQL/PostGIS, des services de géolocalisation et du dispatch des livreurs.

## Vision de lancement

Dios Delices permet aux petits vendeurs de repas — restaurants, cuisines à
domicile ou points de vente — de vendre partout en République démocratique du
Congo (RDC), au fur et à mesure de l'ouverture des villes par la plateforme.

Une ville est active uniquement lorsque Dios Delices y opère réellement, avec
des vendeurs et des livreurs disponibles. L'application n'autorise jamais une
livraison entre deux villes distinctes.

Exemple : un vendeur situé à Lubumbashi ne peut pas livrer un client situé à
Kinshasa. Le client peut éventuellement voir le vendeur, mais l'interface doit
indiquer **« Marchand hors de votre zone de livraison »** et empêcher la
commande en livraison.

## Les trois types de localisation

| Acteur | Donnée enregistrée | Moment de mise à jour |
|---|---|---|
| Vendeur | Point GPS fixe de son restaurant, domicile ou point de vente | À la création ou après modification confirmée du point de vente |
| Client | Position actuelle temporaire ou adresse enregistrée | À l'ouverture, au changement d'adresse, au panier et juste avant paiement |
| Livreur | Position GPS récente | Uniquement lorsqu'il est actif ou en livraison |

### Vendeur

Le vendeur confirme le repère de son activité sur une carte. Cette coordonnée
est la référence de collecte du repas ; elle ne doit pas être redemandée à
chaque commande.

### Client

La position actuelle est proposée automatiquement, avec l'autorisation du
client. Le client garde toujours la possibilité de choisir une adresse
enregistrée : `Domicile`, `Travail` ou `Autre`.

La position actuelle ne remplace pas automatiquement une adresse sauvegardée.
Les coordonnées réellement utilisées sont copiées dans la commande afin que
l'historique reste exact, même si le client modifie ensuite son adresse.

Le suivi permanent du client est exclu : il est inutile hors commande et
dégrade la confidentialité, la batterie et les données mobiles.

### Livreur

Un livreur ne partage sa position que lorsqu'il est `ACTIF` ou qu'il effectue
une course. Sa dernière position doit être suffisamment récente pour recevoir
une nouvelle proposition de livraison.

## Règle d'éligibilité d'une livraison

La décision est prise côté serveur. Les valeurs fournies par le téléphone ne
sont jamais considérées comme fiables sans vérification géographique.

```text
Position client
  → ville couverte détectée
  → comparaison avec la ville du point de vente
  → calcul de la distance vendeur → client

Même ville, distance dans le rayon de la ville,
vendeur ouvert et livraison active ?
  Oui → livraison potentiellement disponible
  Non → « Marchand hors de votre zone de livraison »
```

La ville doit être déterminée avec les frontières géographiques stockées dans
PostGIS, et non avec le seul nom retourné par un fournisseur de géocodage.
Nominatim sert à enrichir et afficher l'adresse humaine ; PostGIS fait foi pour
la règle métier.

La règle de lancement est un rayon maximal de `10 km` de distance routière
estimée entre le vendeur et le client. Il s'ajoute à la règle « même ville » :
un client à Kinshasa ne peut donc pas commander chez un vendeur de Lubumbashi,
mais il ne peut pas non plus commander chez un vendeur situé à plus de 10 km
dans Kinshasa. Chaque ville activée pourra recevoir son propre rayon après
validation terrain.

Le contrôle doit être fait au minimum :

1. quand le client définit son point de livraison ;
2. quand les restaurants sont affichés ;
3. au panier ;
4. juste avant le paiement et la création de commande.

## Panier et commande

Un panier de livraison ne contient les produits que d'un seul vendeur. Deux
vendeurs impliqueraient deux collectes, deux livreurs, deux frais et deux
suivis ; ils devront donc produire deux commandes distinctes.

La commande conserve un instantané de :

- l'adresse et des coordonnées de livraison ;
- la position de collecte du vendeur ;
- la ville ;
- les frais de livraison ;
- le prix du carburant et les paramètres tarifaires appliqués ;
- le livreur finalement assigné.

## Dispatch automatique des livreurs

Les livraisons sont réalisées par les livreurs Dios Delices, pas par les
vendeurs. L'administrateur ne distribue pas manuellement les courses.

### Éligibilité d'un livreur

Un livreur peut recevoir une course s'il est :

- vérifié et autorisé à livrer ;
- `ACTIF` ;
- libre, donc non déjà assigné à une autre livraison ;
- rattaché à la même ville que la commande ;
- doté d'une position GPS récente.

### Attribution

```text
Commande prête chez le vendeur
  → rechercher les livreurs éligibles de la même ville
  → classer par proximité / temps estimé jusqu'au vendeur
  → proposer en priorité aux livreurs les mieux classés
  → le premier qui accepte obtient la course
  → sans acceptation après un délai, élargir progressivement la proposition
```

Cette approche évite qu'un livreur très éloigné prenne une course avant les
livreurs proches, tout en donnant une chance à tous les livreurs actifs si les
premiers ne répondent pas.

La proximité est calculée d'abord vers le vendeur, car le livreur doit récupérer
le repas avant de se rendre chez le client.

## Cycle de vie d'une commande avec livraison

| État commande | État livraison |
|---|---|
| `PAYEE` | — |
| `EN_PREPARATION` | — |
| `PRETE` | `RECHERCHE_LIVREUR` |
| — | `LIVREUR_ASSIGNE` |
| — | `CHEZ_LE_MARCHAND` |
| — | `RECUPEREE` |
| — | `EN_COURS_DE_LIVRAISON` |
| `LIVREE` | `LIVREE` |
| `ANNULEE` / `ECHEC` | `ANNULEE` / `ECHEC` |

## Pourboire après la livraison

Le pourboire est strictement facultatif. Il n'est ni demandé ni inclus lorsque
le client valide ou paie sa commande. Une fois la livraison marquée `LIVREE`,
la page de facture/récapitulatif peut proposer deux choix équivalents :

- `Donner un pourboire` ;
- `Terminer sans pourboire`.

Le client choisit un montant prédéfini ou saisit un montant libre en CDF. Les
montants proposés et le plafond anti-erreur seront configurés côté serveur ;
ils ne sont pas codés en dur dans l'interface. Le pourboire est toujours lié à
la commande et au livreur qui l'a effectivement livrée.

Pour une commande réglée en ligne, un pourboire est une **nouvelle transaction
de paiement**, distincte du paiement de la commande. Il ne modifie ni le total
initial, ni le montant du vendeur, ni les frais de livraison déjà attribués.
Pour une commande en espèces, le client peut remettre un pourboire en espèces
directement au livreur ; il peut aussi choisir de ne rien donner.

Le système enregistrera les pourboires avec : commande, livraison, livreur,
client, montant CDF, méthode de paiement, statut (`EN_ATTENTE`, `PAYE`,
`ECHOUE`, `ANNULE`) et horodatages. Un pourboire payé dans l'application est
crédité intégralement au livreur : aucun pourcentage ne lui est retiré.

## Politique tarifaire

Chaque ville possède un rayon maximal et une grille tarifaire. La première
configuration est volontairement simple et transparente ; elle pourra évoluer
avec les données réelles de courses.

### Règle financière de lancement

Le prix de livraison facturé au client constitue le gain de la course du
livreur. Le pourboire renseigné dans l'application est versé à **100 %** au
livreur, sans commission Dios Delices. Le vendeur reçoit le montant de ses
repas vendus. Aucun honoraire ou frais de plateforme distinct ne sera ajouté
au total visible du client.

```text
Total payé par le client =
  montant des repas
  + frais de livraison
```

Le pourboire éventuel est payé après réception et constitue un paiement séparé.

```text
Montant vendeur = montant des repas

Gain livreur initial = frais de livraison
Gain livreur final = frais de livraison + pourboire post-livraison (100 %)

Frais de plateforme visible au client = 0 CDF
```

Les coûts de la plateforme (CinetPay, serveurs et opérations) ne sont pas
refacturés comme une ligne supplémentaire au client. Le modèle de revenu de
Dios Delices sera décidé séparément avec les vendeurs (par exemple commission
commerciale, abonnement ou promotion), et ne doit pas modifier le prix final
affiché au client au moment de commander.

### Paramètres fixes initiaux, en francs congolais (CDF)

Ces valeurs sont un point de départ pour la première ville activée. Elles sont
enregistrées côté serveur et pourront être modifiées par ville, sans publier
une nouvelle version de l'application.

| Variable | Valeur de lancement | Rôle |
|---|---:|---|
| Devise | `CDF` | Aucune valeur en FCFA/XOF ne doit être utilisée. |
| Prix de référence de l'essence | `2 650 CDF/L` | Référence carburant du 7 septembre 2026. |
| Consommation moto de référence | `2,5 L / 100 km` | Soit environ `66 CDF/km` de carburant seul. |
| Rayon maximal (`Rmax`) | `10 km` | Au-delà, la livraison est indisponible, même dans la même ville. |
| Distance incluse | `2,5 km` | Rayon inclus dans le forfait de départ. |
| Forfait de livraison | `2 000 CDF` | Prix jusqu'à 2,5 km entre le vendeur et le client. |
| Kilomètre supplémentaire | `500 CDF/km` | Facturé au-delà des 2,5 km inclus. |
| Arrondi | `50 CDF` supérieur | Évite les montants difficiles à payer. |
| Pourboire | `100 % au livreur` | Ajouté au gain du livreur, jamais à la marge plateforme. |
| Multiplicateur d'affluence | `1,00` au lancement | Désactivé tant que les données réelles ne le justifient pas. |
| Multiplicateur météo | `1,00` au lancement | Désactivé ; l'application ne majorera pas sans source météo fiable. |
| Surcharge carburant | `0 CDF` au lancement | Révisable manuellement avec le prix du carburant. |

La distance facturée est la distance vendeur → client. Les kilomètres entamés
après les 2,5 km inclus sont pris en compte. La formule initiale est donc la
suivante :

```text
si distanceRoutiereKm > Rmax : livraison indisponible

tarifDistance = 2 000 CDF
  + max(0, distanceRoutiereKm - 2,5) × 500 CDF

fraisLivraison = arrondi50Superieur(
  tarifDistance × multiplicateurAffluence × multiplicateurMeteo
  + surchargeCarburant
)
arrondi final : multiple supérieur de 50 CDF
```

Avec les multiplicateurs à `1,00` et sans surcharge : 1,8 km = `2 000 CDF` ;
6 km = `3 750 CDF` ; 10 km = `5 750 CDF` ; 14 km = `livraison indisponible`.
Ces montants ne s'appliquent que dans une ville activée et à un vendeur
livrable dans cette ville.

Exemple de répartition pour un panier de `12 000 CDF` et une livraison de
`3 750 CDF` : le client paie initialement `15 750 CDF` ; le vendeur reçoit
`12 000 CDF` et le livreur reçoit `3 750 CDF`. Après réception, si le client
choisit librement un pourboire de `500 CDF`, il effectue un paiement distinct ;
le livreur reçoit alors `4 250 CDF` au total. Aucun frais de plateforme
additionnel n'est affiché au client.

Le prix de l'essence, le coût réel de la vie, l'état des routes et la mobilité
ne sont pas identiques dans toutes les villes de RDC. La grille ci-dessus doit
donc être testée pendant deux semaines avec les livreurs de la première ville,
puis révisée à partir des courses réellement acceptées, annulées et terminées.
Une nouvelle ville recevra sa propre configuration avant son ouverture.

La première version peut estimer la distance avec PostGIS et un coefficient
routier configurable. Une évolution ultérieure utilisera un moteur routier
OpenStreetMap/OSRM pour calculer l'itinéraire moto, la distance routière et le
temps estimé réel.

## Cible technique PostGIS et OSM

| Donnée | Stockage recommandé |
|---|---|
| Point vendeur | `geography(Point, 4326)` |
| Point adresse client | `geography(Point, 4326)` |
| Position récente livreur | `geography(Point, 4326)` |
| Frontière d'une ville | `geometry(MultiPolygon, 4326)` |
| Zone de livraison future | `geometry(MultiPolygon, 4326)` |

Prisma déclarera les types géographiques avec `Unsupported(...)`. Les
intersections, distances, index GiST et écritures géographiques seront gérés
par une migration SQL et des requêtes PostGIS paramétrées.

Nominatim/OpenStreetMap est utilisé côté backend, avec un cache persistant, une
file globale limitée et un `User-Agent` identifiable. Il enrichit les adresses,
mais ne remplace pas les contrôles PostGIS de couverture.

Les routes authentifiées `GET /api/v1/geocoding/search?q=…` et
`GET /api/v1/geocoding/reverse?latitude=…&longitude=…` restreignent les
résultats à la RDC. Elles sont prévues pour proposer une adresse au client ;
après son choix, `PATCH /api/v1/addresses/:addressId/location` enregistre les
coordonnées et résout la ville couverte avec PostGIS.

## État de l’implémentation locale

Le socle backend est codé et attend sa première base PostgreSQL locale :

- la migration initiale active PostGIS avant de créer les champs géographiques ;
- les coordonnées vendeur, client et livreur sont stockées en points `geography` ;
- une frontière GeoJSON de ville est convertie en `MultiPolygon` PostGIS par
  `PATCH /api/v1/cities/:cityId/boundary` (administrateur) ;
- `POST /api/v1/delivery/quote` refuse les villes différentes et les distances
  supérieures au rayon configuré, puis retourne le prix calculé côté serveur ;
- une commande livraison réévalue le devis côté serveur et mémorise ses
  instantanés de collecte, destination et tarif ;
- lorsqu’un restaurateur passe une commande à `PRETE`, le dispatch propose la
  course aux livreurs actifs, libres, dans la même ville et géolocalisés depuis
  moins de cinq minutes ; le premier livreur qui accepte gagne la course de
  façon atomique.

Les points d’API de démarrage sont :

| Action | Endpoint |
|---|---|
| Position client / adresse | `PATCH /api/v1/addresses/:addressId/location` |
| Position fixe du vendeur | `PATCH /api/v1/restaurants/:restaurantId/location` |
| Devis de livraison | `POST /api/v1/delivery/quote` |
| Position et disponibilité livreur | `POST /api/v1/couriers/me/location`, `PATCH /api/v1/couriers/me/availability` |
| Offres et acceptation livreur | `GET /api/v1/couriers/me/offers`, `POST /api/v1/delivery-offers/:id/accept` |

### Première exécution locale

1. Copier `.env.example` en `.env` et définir une `DATABASE_URL` PostgreSQL
   locale ainsi qu’un `JWT_SECRET` non public.
2. Installer PostgreSQL avec l’extension PostGIS, puis créer la base
   `dios_delices`.
3. Lancer `npm run prisma:migrate:dev`, puis `npm run prisma:generate`.
4. Créer les villes RDC activées, importer leurs frontières GeoJSON et ajouter
   une `DeliveryConfig` par ville avant de rendre la livraison disponible.

Cette étape ne crée aucune donnée fictive : les villes, frontières et tarifs
doivent être validés par l’équipe locale avant ouverture commerciale.
