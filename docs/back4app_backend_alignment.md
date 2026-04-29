## Alignement Back4App a corriger

Ce document resume les ecarts actuels entre l'app Flutter et le backend Back4App/Parse afin de stabiliser le panier, le paiement et les commandes.

### 1. Champs `Restaurant`

Le frontend utilise maintenant ces champs metier :

- `openingHours`
- `deliveryFee`
- `isOpen`

Le schema actuel `Restaurant` ne les expose pas encore. Il faut :

1. ajouter ces 3 champs dans la classe `Restaurant`
2. les ecrire dans `add1Restaurant`
3. les mettre a jour dans `update1Restaurant`
4. les renvoyer dans `getAllRestaurants`

Exemple attendu :

```js
restaurant.set("openingHours", request.params.openingHours);
restaurant.set("deliveryFee", request.params.deliveryFee);
restaurant.set("isOpen", request.params.isOpen);
```

### 2. Champs `Commande`

Le schema Parse utilise aujourd'hui surtout des noms legacy :

- `id_commande`
- `id_user`
- `id_restau`
- `id_restaurateur`
- `id_moyen_paiement`
- `id_adresse_livraison`
- `frais_livraison`
- `reduction_globale`
- `date_commande`
- `statut`
- `statut_commande`

Pendant ce temps, une partie du frontend et du cloud code historique utilisent aussi des noms camelCase :

- `commandeID`
- `userID`
- `restauID`
- `restaurateurID`
- `moyenPaiementID`
- `addressID`
- `fraisLivraison`
- `reduction`
- `dateCommande`

Il faut choisir **une seule convention** partout. Le plus simple est de suivre la convention deja presente dans la base Vercel/Parse qui cree les commandes, puis d'aligner le cloud code Parse dessus.

### 3. Statut de commande

Le frontend gere maintenant plusieurs etats :

- `En attente`
- `Payee`
- `Confirmee`
- `Annulee`

Il faut que la couche Parse enregistre explicitement ce statut lors de la creation de commande et de sa mise a jour.

Dans `add1Commande`, ajouter par exemple :

```js
commande.set("statut", request.params.statut || "En attente");
commande.set("statut_commande", request.params.statut_commande || "En attente");
```

Dans `updateCommande`, autoriser la mise a jour de ces champs.

### 4. Devise reelle

Le frontend envoie maintenant :

- `currency: "eur"` pour la France
- `currency: "xof"` pour le FCFA

Le backend de creation de commande doit enregistrer cette information dans la commande, par exemple via un champ :

- `currency`

ou

- `devise`

Il faut aussi s'assurer que `totalAmount`, `prixUnitaire`, `frais_livraison` et `reduction_globale` restent dans **la meme devise** sur toute la commande.

### 5. Reductions / promos

Le frontend calcule maintenant une reduction globale et peut transmettre :

- `reduction`
- `promo_code`

Le backend doit :

1. enregistrer la reduction globale au niveau `Commande`
2. conserver le code promo si tu veux l'auditer
3. recalculer ou au moins valider le montant final serveur

Exemple :

```js
commande.set("reduction_globale", request.params.reduction || 0);
commande.set("promo_code", request.params.promo_code || null);
```

### 6. `LigneCommande`

Le cloud code contient actuellement `addLigneCommande` **deux fois**. Il faut supprimer le doublon.

Le schema actuel semble plutot utiliser :

- `id_ligne_commande`
- `id_commande`
- `id_plat`
- `prix_unitaire`

Alors que le vieux cloud code utilise :

- `ligneID`
- `commandeID`
- `platID`
- `prixUnitaire`

Il faut unifier ces noms avant de continuer les evolutions.

### 7. `MoyenPaiement`

Le schema actuel `MoyenPaiement` ressemble davantage a une vraie carte sauvegardee :

- `id_moyen_paiement`
- `userID`
- `stripe_pm_id`
- `brand`
- `last4`
- `exp_month`
- `exp_year`
- `type`
- `is_default`
- `libelle`

Mais le cloud code historique manipule encore seulement :

- `idMoyen`
- `nom`

Il faut remplacer ce vieux contrat Parse par la version reelle du schema si tu veux que tout soit coherent avec Stripe.

### 8. Adresses

Il y a aussi des incoherences de nommage :

- classe `Adress` au lieu de `Address`
- `addressID` parfois
- `adressID` ailleurs

Il vaut mieux ne plus melanger ces noms, sinon les filtres de livraison deviennent fragiles.

### 9. Recommandation pratique

Avant d'ajouter d'autres features backend, fais ce petit chantier d'alignement :

1. figer les noms de champs definitifs
2. corriger le schema Parse
3. corriger le cloud code Parse
4. aligner ensuite les modeles Flutter restants

Sans cette etape, chaque nouvelle fonctionnalite risque de marcher localement mais de casser des flux en production.
