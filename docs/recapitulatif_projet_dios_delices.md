# Récapitulatif du projet Dios Délices

## 1. Vue d'ensemble

Dios Délices est une application Flutter de commande de repas et de gestion de micro-restaurants. Elle combine une expérience client, un espace restaurateur et un espace administrateur.

L'application permet principalement de :

- créer un compte utilisateur ;
- vérifier le compte par email ;
- choisir un pays et un statut utilisateur ;
- enregistrer une adresse et une identité ;
- afficher les restaurants et plats disponibles ;
- rechercher des plats et restaurants proches ;
- ajouter des plats au panier ;
- passer une commande avec paiement Stripe ;
- suivre l'état des commandes ;
- gérer un restaurant, ses plats et ses ventes ;
- administrer les utilisateurs, restaurants et validations.

## 2. Technologies principales

Le projet est une application Flutter/Dart.

Technologies et bibliothèques importantes :

- Flutter pour l'interface mobile ;
- Riverpod pour certains états applicatifs ;
- GetX pour la navigation, les traductions et certains contrôleurs UI ;
- Hive pour le cache local ;
- SharedPreferences pour la session et les préférences ;
- Parse Server / Back4App comme backend principal ;
- Stripe pour le paiement ;
- Mailer/Gmail SMTP pour l'envoi de codes email ;
- Flutter Local Notifications et Back4App Push pour les notifications ;
- Geolocator/Geocoding pour les adresses et la proximité ;
- Image Picker/File Picker pour les images et documents ;
- Curved Navigation Bar pour la navigation principale.

Fichier d'entrée : `lib/main.dart`.

## 3. Initialisation de l'application

Au démarrage, `main.dart` :

- initialise Flutter ;
- active le mode edge-to-edge ;
- initialise Parse Server via `AppConfig` ;
- initialise Hive et enregistre les adaptateurs des modèles ;
- configure Stripe ;
- initialise les notifications ;
- lance `MyApp`.

L'écran de départ est `AnimatedSplashScreen`.

Le splash :

- vérifie la connexion internet ;
- synchronise les données principales depuis Back4App vers Hive ;
- décide la destination via `LaunchFlowService` ;
- affiche l'onboarding au premier lancement ;
- redirige vers l'inscription si aucune session n'existe ;
- redirige vers l'accueil si une session valide existe.

## 4. Architecture des dossiers

Structure principale dans `lib/` :

- `Screen/` : tous les écrans utilisateur, restaurateur, admin et authentification ;
- `modeles/` : modèles métier et appels Back4App/Hive ;
- `services/` : services applicatifs transverses ;
- `providers/` : états Riverpod ;
- `db/` : helper Hive local ;
- `core/` : enums et constantes métier ;
- `config/` : configuration Parse/Stripe/logs ;
- `mails/` : envoi des emails de vérification et réinitialisation ;
- `utils/` : formatage, toast, téléphone, prix, dates ;
- `theme/` : thème visuel global ;
- `widgets/` : composants réutilisables.

## 5. Rôles utilisateur

Les rôles sont définis dans `lib/core/app_role.dart` :

- `admin` : rôle 1 ;
- `individual` / Particulier : rôle 2 ;
- `microRestaurant` / Restaurateur : rôle 3 ;
- `superAdmin` : rôle 4 ;
- `unknown` : rôle 0.

La navigation principale est choisie par `Users.chooseCurvedNavigation(...)` :

- administrateur ou super admin : `CurvedNavigationAdmin` ;
- restaurateur : `CurvedNavigationRestau` ;
- particulier en France : `CurvedNavigationUserFrance` ;
- particulier hors France : `CurvedNavigationUserAfr`.

## 6. Parcours d'authentification

### Inscription

Écran : `lib/Screen/authentification/Signup.dart`

Le parcours d'inscription collecte :

- prénom ;
- nom ;
- nom d'utilisateur ;
- email ;
- téléphone ;
- mot de passe ;
- pays et indicatif ;
- localisation si nécessaire.

Après création du compte, l'utilisateur passe par `VerificationPage`.

### Vérification email

Écran : `lib/Screen/verif_confirm/VerificationPage.dart`

État actuel :

- la vérification se fait uniquement par email ;
- WhatsApp/Twilio est désactivé dans le flux de validation ;
- un code à 6 chiffres est envoyé par email ;
- le code est valable 15 minutes ;
- après validation réussie, le compte passe en statut `Verified` ;
- la session est enregistrée ;
- l'utilisateur est envoyé directement vers la page d'accueil adaptée à son rôle et son pays.

### Connexion

Écran : `lib/Screen/authentification/Login.dart`

Le login :

- recherche l'utilisateur localement ;
- rafraîchit les utilisateurs si nécessaire ;
- vérifie le mot de passe ;
- enregistre la session via `SessionService` ;
- redirige selon le statut du compte, le rôle, l'adresse, l'identité et le restaurant.

### Réinitialisation du mot de passe

Écrans :

- `EmailInputScreen.dart` ;
- `PasswordResetScreen.dart` ;
- `PasswordChangeSuccessScreen.dart`.

Le code email est envoyé via `mails.dart`, puis validé avant mise à jour du mot de passe.

## 7. Parcours après inscription

Après vérification du compte :

1. L'utilisateur choisit son statut dans `StatusSelectionPage`.
2. Il choisit entre `Particulier` et `Restaurateur`.
3. Le pays et le rôle sont sauvegardés.
4. L'utilisateur passe à la vérification d'identité.
5. Selon le rôle, il est ensuite orienté vers l'expérience client ou restaurateur.

Écrans liés :

- `StartAddressSaving.dart` ;
- `StatusSelectionPage.dart` ;
- `StartIdentityVerification.dart` ;
- `IdentityVerifcation.dart` ;
- `WaitIdentityValidation.dart` ;
- `IdentityCreated.dart` ;
- `UserIdentityRejected.dart`.

## 8. Données et stockage

Le backend principal est Back4App/Parse Server.

Hive sert de cache local pour :

- utilisateurs ;
- restaurants ;
- plats ;
- adresses ;
- identités ;
- moyens de paiement ;
- commandes ;
- lignes de commande.

`DatabaseHelper` centralise les opérations Hive.

Les modèles synchronisent généralement :

- création ou mise à jour côté Parse ;
- création ou mise à jour côté Hive ;
- lecture locale depuis Hive pour l'affichage rapide.

## 9. Modèles métier principaux

### Users

Fichier : `lib/modeles/users.dart`

Gère :

- création utilisateur ;
- statut de vérification ;
- identité ;
- dernière connexion ;
- mot de passe ;
- pays et rôle ;
- suppression ;
- synchronisation Back4App vers Hive ;
- vérification login ;
- choix de navigation selon rôle/pays.

### Restaurant

Fichier : `lib/modeles/restaurant.dart`

Gère :

- création et mise à jour de restaurant ;
- upload d'image vers la galerie Parse ;
- validation admin ;
- suppression ;
- synchronisation ;
- recherche du restaurant d'un utilisateur.

### Dish

Fichier : `lib/modeles/dish.dart`

Gère :

- création et mise à jour de plat ;
- image du plat ;
- prix ;
- description ;
- options ;
- catégories ;
- nombre de portions ;
- statut ;
- nombre de commandes ;
- synchronisation.

### Address

Fichier : `lib/modeles/address.dart`

Gère :

- adresse utilisateur ou restaurant ;
- ville, état, numéro, adresse complète ;
- latitude et longitude ;
- suppression ;
- synchronisation.

### Identity

Fichier : `lib/modeles/identity.dart`

Gère :

- document d'identité ;
- type de pièce ;
- upload de fichier ;
- rattachement à un utilisateur ;
- validation admin.

### Commande et LigneCommande

Fichiers :

- `lib/modeles/commande.dart` ;
- `lib/modeles/ligne_commande.dart`.

Gèrent :

- création de commande ;
- statut ;
- date ;
- utilisateur ;
- restaurant ;
- montant ;
- lignes de commande ;
- détails des plats commandés ;
- synchronisation locale.

### MoyenPaiement

Fichier : `lib/modeles/moyen_paiement.dart`

Gère les moyens de paiement associés aux commandes et utilisateurs.

## 10. Expérience client

Écrans principaux :

- `HomeUser.dart` : accueil client ;
- `FoodCategories.dart` : catégories ;
- `ExploreMeals.dart` : exploration des plats ;
- `MealsOfACategory.dart` : plats par catégorie ;
- `NearMeMeals.dart` : plats proches ;
- `NearMeRestaurants.dart` : restaurants proches ;
- `RestaurantListPage.dart` : liste de restaurants ;
- `RestaurantDetails.dart` : fiche restaurant ;
- `DishDetails.dart` : fiche plat ;
- `Favorites.dart` : favoris ;
- `Cart.dart` : panier et paiement ;
- `UserOrdersPage.dart` : commandes utilisateur ;
- `order_tracking_page.dart` : suivi de commande ;
- `Settings.dart` : réglages.

Fonctionnalités client :

- recherche ;
- favoris plats/restaurants ;
- ajout au panier ;
- choix d'options de plat ;
- limitation à un seul restaurant par panier ;
- adresse de livraison ;
- code promo ;
- paiement Stripe ;
- confirmation de commande ;
- suivi de statut.

## 11. Panier, commande et paiement

Le panier est géré par `CartNotifier` dans `lib/providers/cart_provider.dart`.

Le panier contient :

- plat ;
- quantité ;
- options ;
- prix ;
- utilisateur ;
- restaurant ;
- frais de livraison.

Le paiement est dans `Cart.dart` et utilise Stripe Payment Sheet.

Flux simplifié :

1. L'utilisateur ajoute des plats au panier.
2. Il choisit une adresse de livraison.
3. Il peut appliquer un code promo.
4. Stripe Payment Sheet est affiché.
5. Le moyen de paiement est enregistré.
6. Une commande est créée.
7. Les lignes de commande sont créées.
8. Une confirmation est affichée.
9. Une notification peut être envoyée au restaurateur.

Codes promo actuels dans `PromoService` :

- `BIENVENUE10` : 10% de réduction ;
- `DELICES15` : 15% de réduction ;
- `LIVRAISONOFFERTE` : livraison offerte.

## 12. Expérience restaurateur

Navigation : `CurvedNavigationRestau`.

Écrans principaux :

- `HomeMicroRestau.dart` : accueil restaurateur ;
- `Menu.dart` : liste des plats du restaurant ;
- `DishFormPage.dart` : ajout/modification de plat ;
- `MyStore.dart` : gestion du restaurant ;
- `MyProducts.dart` : produits ;
- `MySales.dart` : ventes ;
- `RestaurantFormPage.dart` : création du restaurant ;
- `RestaurantUpdateFormPage.dart` : correction ou modification restaurant ;
- `WaitRestaurantValidation.dart` : attente de validation.

Fonctionnalités restaurateur :

- création de restaurant ;
- upload d'image ;
- gestion des informations restaurant ;
- création de plats ;
- gestion du menu ;
- suivi des ventes/commandes ;
- attente de validation admin.

## 13. Expérience administrateur

Navigation : `CurvedNavigationAdmin`.

Écrans principaux :

- `AdminDashboard.dart` ;
- `UsersListPage.dart` ;
- `UserDetails.dart` ;
- `RestaurantListPage.dart` ;
- `RestaurantDetails.dart`.

Fonctionnalités admin :

- consulter les utilisateurs ;
- consulter les restaurants ;
- valider ou rejeter des restaurants ;
- valider ou rejeter des identités ;
- accéder aux détails utilisateur/restaurant ;
- gérer les statuts.

## 14. Services applicatifs

### AppBootstrapService

Synchronise les données principales au lancement :

- utilisateurs ;
- restaurants ;
- plats ;
- adresses ;
- identités ;
- moyens de paiement ;
- commandes ;
- lignes de commande.

### LaunchFlowService

Décide où envoyer l'utilisateur au lancement :

- onboarding ;
- inscription ;
- accueil.

### SessionService

Gère la session locale :

- utilisateur connecté ;
- rôle ;
- pays ;
- restaurant courant ;
- déconnexion.

### NearbyService

Calcule les restaurants et plats proches à partir des coordonnées utilisateur/restaurant.

### FavoritesService

Stocke les favoris par utilisateur dans SharedPreferences.

### NotificationService

Gère :

- notifications locales ;
- notifications Back4App push ;
- notification de nouvelle commande au restaurateur ;
- abonnement aux canaux restaurateur/utilisateur.

### CommandeApi

Appelle une API externe Vercel pour mettre à jour le statut d'une commande.

## 15. Internationalisation

Le projet utilise :

- `flutter_localizations` ;
- fichiers ARB dans `lib/l10n/` ;
- GetX translations dans `utils/translations.dart`.

La langue de fallback est le français.

## 16. Thème et identité visuelle

Le thème global est dans `lib/theme/app_theme.dart`.

Éléments visuels :

- rouge Dios Délices ;
- fond clair chaleureux ;
- logo rond ;
- typographie Google Fonts ;
- composants d'authentification centralisés dans `widgets/auth_shell.dart` et `widgets/brand_avatar_logo.dart`.

## 17. Assets

Les assets sont déclarés dans `pubspec.yaml`.

Ils incluent :

- logos ;
- icône d'application ;
- images de repas ;
- fond d'accueil ;
- fichiers JSON de données statiques.

## 18. Points importants de l'état actuel

- La validation WhatsApp/Twilio est désactivée dans le parcours utilisateur actuel.
- La validation de compte se fait par email.
- Après vérification email réussie, l'utilisateur va directement à l'accueil.
- L'écran de sélection du statut contient deux boutons espacés : `Particulier` et `Restaurateur`.
- Le projet contient encore la dépendance `twilio_flutter` dans `pubspec.yaml`, mais l'écran de vérification ne l'utilise plus.
- Plusieurs services externes sont configurés directement dans le code ; à terme, il faudra déplacer les clés sensibles dans une configuration sécurisée.
- Les données sont fortement couplées à Back4App et au cache Hive local.
- Certaines parties du code contiennent encore des commentaires ou anciennes approches ; une passe de nettoyage peut simplifier la maintenance.

## 19. Fichiers à connaître rapidement

- `lib/main.dart` : démarrage de l'application ;
- `lib/Screen/AnimatedSplashScreen.dart` : onboarding, synchro et redirection initiale ;
- `lib/Screen/authentification/Signup.dart` : inscription ;
- `lib/Screen/authentification/Login.dart` : connexion ;
- `lib/Screen/verif_confirm/VerificationPage.dart` : validation email ;
- `lib/Screen/verif_confirm/StatusSelectionPage.dart` : choix Particulier/Restaurateur ;
- `lib/modeles/users.dart` : utilisateurs et navigation par rôle ;
- `lib/modeles/restaurant.dart` : restaurants ;
- `lib/modeles/dish.dart` : plats ;
- `lib/modeles/commande.dart` : commandes ;
- `lib/providers/cart_provider.dart` : panier ;
- `lib/services/session_service.dart` : session locale ;
- `lib/services/app_bootstrap_service.dart` : synchronisation initiale ;
- `lib/services/nearby_service.dart` : proximité ;
- `lib/services/notification_service.dart` : notifications ;
- `lib/mails/mails.dart` : emails de validation ;
- `lib/config/app_config.dart` : configuration Parse/Stripe.

## 20. Améliorations recommandées

Priorités techniques :

- sortir les clés sensibles du code source ;
- supprimer ou isoler définitivement Twilio si la validation WhatsApp n'est plus prévue ;
- harmoniser Riverpod, GetX et SharedPreferences pour éviter les doubles sources de vérité ;
- nettoyer les anciens commentaires et blocs morts ;
- ajouter des tests sur les parcours critiques : inscription, validation email, login, panier, paiement ;
- centraliser la gestion des erreurs réseau ;
- renforcer les validations de formulaire ;
- documenter le schéma Back4App ;
- améliorer la gestion des statuts commande/restaurant/identité ;
- vérifier la cohérence des pays, indicatifs et formats de numéros.

Priorités produit :

- fluidifier l'onboarding ;
- clarifier les étapes après inscription ;
- améliorer les messages d'erreur ;
- afficher des états vides plus utiles ;
- rendre le suivi commande plus explicite ;
- ajouter une page profil/session plus complète.

## 21. Résumé court

Dios Délices est une marketplace Flutter de restauration avec trois espaces : client, restaurateur et admin. L'app s'appuie sur Back4App pour le backend, Hive pour le cache local, Stripe pour les paiements, SMTP pour les codes email et des services locaux pour session, favoris, proximité et notifications.

Le flux actuel met l'accent sur une inscription validée par email, puis une navigation directe vers l'accueil après vérification. Les clients peuvent commander, payer et suivre leurs commandes ; les restaurateurs peuvent gérer leur restaurant et leurs plats ; les administrateurs peuvent valider les comptes, identités et restaurants.
