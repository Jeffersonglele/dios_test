# Fiche technique — Dios Délices (application Flutter)

Ce document décrit **l'arborescence du projet** : à quoi sert chaque dossier,
ce qu'il contient, et où chercher quand on veut modifier quelque chose.

- **Application** : livraison de repas (client, restaurateur, livreur, admin, superadmin).
- **Pays** : RDC (CDF/USD) et Bénin (XOF, pays de test).
- **Framework** : Flutter (Dart ≥ 3), état géré avec **Riverpod**, cache local **Hive**.
- **Backend** : API **Node.js** (`dios_newback`, hébergée sur Render), appelée en JWT.
  L'ancien backend **Parse / Back4App** est encore présent dans le code mais en cours
  de retrait : toute nouvelle fonctionnalité passe par Node.

---

## 1. Vue d'ensemble (racine du projet)

```
dios_delices/
├── android/            → projet natif Android (config, permissions, icônes)
├── ios/                → projet natif iOS (config Xcode, permissions, code Swift)
├── web/  windows/  linux/  macos/   → autres plateformes générées par Flutter (non utilisées en prod)
├── lib/                → ★ le cœur de l'application (tout le code Dart)
├── assets/             → images embarquées dans l'app (logos, onboarding, plats d'exemple)
├── test/               → tests automatisés
├── docs/               → documentation fonctionnelle et technique
├── third_party/        → paquets tiers copiés et corrigés localement
├── .github/workflows/  → intégration continue (GitHub Actions)
├── pubspec.yaml        → dépendances, assets, icône de l'app
├── l10n.yaml           → configuration des traductions (fr / en)
├── analysis_options.yaml → règles du linter (dart analyze)
├── dart_defines.example.json → modèle des clés passées au lancement
├── run.bat             → lance l'app avec les clés (Windows)
├── .env                → clés locales (non versionné)
└── README.md, GUIDE_DEMARCHES_MANUELLES.md, implementation_plan.md
```

Dossiers **générés** (ne jamais modifier à la main, peuvent être supprimés) :
`build/`, `.dart_tool/`, `.flutter-plugins-dependencies`, `ios/build/`, `ios/Flutter/ephemeral/`.

---

## 2. `android/` — configuration Android

| Élément | Rôle |
|---|---|
| `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties` | Configuration Gradle du projet (plugins, versions). |
| `gradle/`, `gradlew`, `gradlew.bat` | Gradle wrapper (version de Gradle figée pour tous). |
| `local.properties` | Chemins locaux (SDK Android, Flutter). Propre à chaque machine. |
| `app/build.gradle.kts` | Config de l'application : `applicationId` (`com.example.dios_delices`), SDK min/cible, signature. |
| `app/google-services.json` | Configuration Firebase (notifications push). |
| `app/src/main/AndroidManifest.xml` | Déclaration de l'app et des **permissions** : localisation (GPS), notifications, stockage. |
| `app/src/main/kotlin/.../MainActivity.kt` | Point d'entrée natif Android (lance Flutter). |
| `app/src/main/res/` | Ressources natives : icônes (`mipmap-*`), écran de lancement (`drawable*`), thèmes clair/sombre (`values`, `values-night`). |

> À faire avant publication sur le Play Store : remplacer `com.example.dios_delices`
> par un identifiant définitif et configurer la signature release.

---

## 3. `ios/` — configuration iOS

| Élément | Rôle |
|---|---|
| `Runner/Info.plist` | Réglages de l'app et **textes de permission** : localisation, caméra, photothèque. |
| `Runner/AppDelegate.swift`, `SceneDelegate.swift` | Points d'entrée natifs iOS. |
| `Runner/GoogleService-Info.plist` | Configuration Firebase iOS. |
| `Runner/LiquidGlassNavBar.swift`, `NavBarFactory.swift`, `NavBarPlatformView.swift` | Barre de navigation native « Liquid Glass » (iOS 17+), affichée dans Flutter via une *platform view*. |
| `Runner/Assets.xcassets` | Icônes et image de lancement iOS. |
| `Runner/Base.lproj` | Storyboards (écran de lancement). |
| `Runner.xcodeproj`, `Runner.xcworkspace` | Projet Xcode (bundle id `com.example.diosDelices`). Ouvrir **le .xcworkspace**. |
| `Podfile`, `Podfile.lock` | Dépendances natives CocoaPods. |
| `Flutter/` | Fichiers de liaison Flutter ↔ Xcode (`Debug/Release.xcconfig`). |
| `RunnerTests/` | Tests natifs iOS (vides). |

---

## 4. `lib/` — le cœur du projet

```
lib/
├── main.dart        → point d'entrée de l'application
├── config/          → configuration globale (URLs, clés)
├── constants/       → styles de texte partagés
├── core/            → énumérations métier (rôles, statuts de commande)
├── controllers/     → petits contrôleurs d'interface
├── db/              → accès au cache local Hive
├── l10n/            → traductions français / anglais
├── mails/           → génération de codes envoyés par email
├── models/          → objets métier (commande, plat, restaurant…)
├── providers/       → état partagé Riverpod (panier, thème, utilisateur)
├── services/        → appels au backend et logique métier
├── screens/         → écrans de l'application, rangés par domaine
├── theme/           → design system (couleurs, typos, espacements)
├── utils/           → fonctions utilitaires (devises, téléphone, dates…)
└── widgets/         → composants réutilisables entre les écrans
```

**Règle de lecture** : un écran (`screens/`) affiche ; il appelle un service
(`services/`) qui parle au backend ; les données reviennent sous forme de modèles
(`models/`) ; l'apparence vient de `theme/` et des composants de `widgets/`.

### 4.1 `main.dart`
Démarrage de l'app, dans cet ordre : chargement du `.env`, infos de l'appareil,
devises, barre système, Firebase (notifications), Hive (cache local), Parse
(ancien backend), notifications, session. Il déclare ensuite le `MaterialApp`
(thème clair/sombre, langues, routes) et affiche l'écran de démarrage
`AnimatedSplashScreen`. Toute l'app est enveloppée dans `SessionGuard`.

### 4.2 `config/`
- `app_config.dart` — **URL du backend Node** (`NODE_API_URL`, par défaut
  `https://dios-delices.onrender.com`), **clé CARTO** des fonds de carte
  (`CARTO_API_KEY`, lue depuis `--dart-define` ou le `.env`), et les anciens
  identifiants Parse/Back4App.

### 4.3 `constants/`
- `constant.dart` — styles de texte historiques (`kLoginTitleStyle`, …) qui
  redirigent vers `AppTypography`. Pour du nouveau code, utiliser directement `theme/`.

### 4.4 `core/`
Énumérations et règles métier pures, sans interface :
- `app_role.dart` — rôles : 1 admin, 2 client, 3 restaurateur, 4 superadmin, 5 livreur.
- `commande_status.dart` — statuts de commande et de livraison.
- `order_stage.dart` — étapes affichées d'une commande (liste et détail).
- `device_info.dart` — infos de plateforme (pour les variantes natives d'interface).

### 4.5 `controllers/`
- `ui_controller.dart` — contrôleur simple d'état d'interface (ex. afficher/masquer le mot de passe).

### 4.6 `db/`
- `database_helper.dart` — lecture/écriture dans les boîtes **Hive** (utilisateur,
  adresses…) : c'est le cache hors ligne du téléphone.

### 4.7 `l10n/` — traductions
- `app_fr.arb`, `app_en.arb` — **les textes de l'app** (clé → phrase). L'anglais
  est le fichier modèle (voir `l10n.yaml`).
- `app_localizations*.dart` — **générés** par `flutter gen-l10n` : ne pas modifier.

> Pour ajouter un texte : l'écrire dans les deux `.arb`, lancer `flutter gen-l10n`,
> puis l'utiliser avec `AppLocalizations.of(context)!.maCle`.

### 4.8 `mails/`
- `mails.dart`, `password_reset_code.dart` — génération et vérification des codes
  à 6 chiffres (réinitialisation de mot de passe).

### 4.9 `models/` — objets métier
Chaque fichier décrit une donnée de l'app. Les fichiers `*.g.dart` sont
**générés** (adaptateurs Hive, via `build_runner`).

| Fichier | Contenu |
|---|---|
| `users.dart` | Utilisateur (rôle, pays, photo, véhicule du livreur…). |
| `restaurant.dart` | Restaurant (adresse, coordonnées, statut de validation, Pro). |
| `dish.dart` | Plat et ses options ; création/modification via l'API Node. |
| `category.dart` | Catégories de plats. |
| `commande.dart` | Commande (statut, paiement, montants, livraison). |
| `ligne_commande.dart` | Ligne d'une commande (plat, quantité, prix figé). |
| `address.dart` | Adresses de livraison du client. |
| `identity.dart` | Dossier d'identité (pièce, statut de vérification). |
| `pro_document.dart` | Justificatifs de la demande « Devenir Pro » (envoi PDF/photo). |
| `moyen_paiement.dart` | Moyens de paiement. |
| `payout.dart` | Versements aux restaurants et aux livreurs. |
| `dispute.dart` | Réclamations sur une commande. |
| `driver_rating.dart` | Notes données aux livreurs. |
| `exchange_rate.dart` | Taux de change (CDF ↔ USD). |
| `referral.dart` | Parrainage. |
| `chat_message.dart` | Message du chat de commande. |

### 4.10 `providers/` — état partagé (Riverpod)
- `cart_provider.dart` — **le panier** (ajout, quantités, synchronisation).
- `users_provider.dart` — utilisateur connecté.
- `selected_delivery.dart` — adresse/mode de livraison choisi.
- `theme_provider.dart` — préférence clair/sombre (ancienne version, voir aussi `theme/`).
- `data_version_notifier.dart` — signal « les données ont changé, rechargez ».

### 4.11 `services/` — communication avec le backend et logique
C'est la couche qui fait les appels HTTP / WebSocket. Les écrans ne doivent pas
appeler le réseau directement.

**Authentification et session**
- `node_auth_service.dart` — connexion, inscription, jeton JWT Node.
- `session_service.dart` — session locale, état du compte côté serveur
  (rôle, restaurant validé, statut du dossier livreur…).
- `launch_flow_service.dart` — décide quoi afficher au lancement (onboarding,
  connexion ou accueil).
- `app_bootstrap_service.dart` — préchargements au démarrage.
- `password_reset_validation.dart` — règles de réinitialisation du mot de passe.

**Catalogue et accueil**
- `node_catalog_service.dart` — restaurants, menus, plats.
- `node_home_service.dart` — données de l'accueil client.
- `nearby_service.dart` — restaurants et plats proches.
- `favorites_service.dart` — favoris.
- `restaurant_opening_hours_service.dart` — horaires d'ouverture, ouvert/fermé.
- `comment_service.dart` — avis (restaurant, plat, livreur).

**Commande, panier, paiement**
- `node_order_service.dart`, `commande_api.dart` — création et suivi des commandes.
- `cart_sync_service.dart` — synchronisation du panier avec le serveur.
- `promo_service.dart` — vérification des codes promo (réduction calculée par le serveur).
- `wallet_service.dart` — portefeuille (solde, recharges, historique).
- `currency_service.dart` — devises et conversion.
- `order_dispute_service.dart` — réclamations.
- `order_tracking_service.dart` — suivi d'une commande : restaurant, client,
  **profil du livreur** et sa position.

**Livraison et livreurs**
- `delivery_shipping_service.dart` — devis des frais de livraison.
- `delivery_availability_service.dart` — livraison possible ou non à une adresse.
- `delivery_orders_service.dart` — courses disponibles, acceptation, progression.
- `livreur_api.dart` — espace livreur (revenus, statut).
- `courier_application_service.dart` — envoi du **dossier livreur** (photo, pièce, permis, plaque).

**Géolocalisation**
- `geocoding_api_service.dart` — adresse ↔ coordonnées (via le backend).
- `location_cache_service.dart` — dernière position connue de l'utilisateur.

**Temps réel et divers**
- `socket_service.dart` — connexion **Socket.io** (suivi en direct, offres de course).
- `chat_api_service.dart`, `audio_chat_service.dart` — chat de commande (texte et vocal).
- `notification_service.dart` — notifications push (Firebase) et locales.
- `upload_service.dart` — envoi d'images vers le backend (stockage R2).

**Administration**
- `node_admin_service.dart` — tout l'espace admin/superadmin : utilisateurs,
  livreurs, validations, statistiques, journal d'audit, tarifs de livraison.
- `restaurant_revenue_service.dart` — revenus d'un restaurant (graphiques).

### 4.12 `screens/` — les écrans, par domaine

| Dossier | Écrans |
|---|---|
| `splash/` | Écran de démarrage animé. |
| `onboarding/` | Choix du profil, vérification email, **dossier livreur** (`courier_onboarding_page`), attente de validation, identité, première adresse. |
| `auth/` | Connexion (`login.dart`, routage selon le rôle) et inscription (`signup.dart`). |
| `password/` | Mot de passe oublié, réinitialisation, changement obligatoire à la 1ʳᵉ connexion. |
| `navigation/` | **Barres de navigation par rôle** : client, restaurateur, livreur, admin. C'est le « squelette » de chaque espace. |
| `home/` | Accueil client, plats proches. |
| `explore/` | Catégories et plats d'une catégorie. |
| `search/` | Recherche. |
| `restaurants/` | Fiche restaurant, restaurants proches, **formulaire de création/modification**, demande **Devenir Pro**, accueil restaurateur, revenus, attente de validation. |
| `dish/` | Menu, détail d'un plat, formulaire de plat. |
| `store/` | « Ma boutique » : état de la demande de restaurant du restaurateur. |
| `cart/` | Panier et validation de commande (paiement, code promo). |
| `payment/` | Paiement Mobile Money **Nyole** (WebView). |
| `orders/` | Mes commandes, détail d'une commande (avec la carte du livreur), suivi. |
| `delivery/` | Espace livreur : tableau de bord, offres de course, courses disponibles, course en cours, **carte**, preuve de livraison, **revenus**, note du livreur ; côté admin : liste et fiche des livreurs. |
| `wallet/` | Portefeuille. |
| `chat/` | Chat entre client, restaurant et livreur. |
| `disputes/` | Ouvrir une réclamation, mes réclamations. |
| `favorites/` | Favoris. |
| `profile/` | Profil et adresses. |
| `settings/` | Paramètres, choix du pays. |
| `contact/` | Contact / support. |
| `legal/` | CGV, mentions légales, confidentialité (une version FR et EN de chaque). |
| `users/` | Admin : liste des utilisateurs, détail, identité refusée. |
| `admin/` | Tableaux de bord **admin** et **superadmin**, validation des livreurs, demandes Pro, catégories, promotions, parrainage, **tarifs de livraison par ville**, journal d'audit, suppressions planifiées. |

> Des scripts Python (`fix_*.py`) traînent dans `screens/admin`, `screens/restaurants`
> et `screens/users` : ce sont des restes de corrections automatiques, ils ne sont pas
> utilisés par l'app et peuvent être supprimés.

### 4.13 `theme/` — design system
- `app_theme.dart` — **tous les tokens visuels** : `AppColors` / `AppDarkColors`
  (clair/sombre), `AppTypography`, `AppSpacing`, `AppRadius`, `AppShadows`,
  `AppMotion`, et le `ThemeData`. Toute couleur ou taille doit venir d'ici.
- `theme_provider.dart` — bascule clair / sombre / système.

### 4.14 `utils/` — utilitaires
- `currency_util.dart`, `country_util.dart` — formatage des montants, pays.
- `phone_number.dart` — saisie et format des numéros (RDC, Bénin).
- `date_time_util.dart` — affichage des dates.
- `delivery_fee_calculator.dart` — estimation locale des frais (le serveur reste la référence).
- `payment_provider_label.dart` — libellés et badges des moyens de paiement.
- `image_picker_helper.dart` — choix et préparation d'images.
- `rating_tags.dart`, `stars.dart` — étiquettes et étoiles des avis.
- `toast.dart` — messages courts à l'écran.
- `hashtag_text_input_formatter.dart` — saisie de hashtags.

### 4.15 `widgets/` — composants réutilisables
- **Structure** : `auth_shell.dart`, `auth_kit.dart` (écrans d'authentification),
  `dios_nav_bar.dart` (barre du bas), `session_guard.dart` (surveille le compte
  pendant l'utilisation : déconnexion si suspendu, etc.).
- **Carte** : `app_tile_layer.dart` — fond de carte commun à toutes les cartes
  (CARTO Voyager avec clé, sinon OpenStreetMap) et **cache des tuiles** sur le
  téléphone (30 jours, 4 000 tuiles).
- **Livreur** : `courier_card.dart` — carte du livreur (photo, nom, plaque d'immatriculation).
- **Commande / panier** : `cart_widgets.dart`, `cart_conflict.dart`,
  `order_otp_widgets.dart` (code de remise), `order_dispute_sheet.dart`,
  `delivery_unavailable.dart` (zone non desservie, restaurant fermé).
- **Avis** : `rating_dialog.dart`, `rating_tags_display.dart`.
- **Visuel** : `dios_image.dart` (image réseau avec repli), `brand_avatar_logo.dart`,
  `animations.dart`, `micro_interactions.dart`, `swirling_loader.dart`,
  `showConfetti.dart`, `home_widgets.dart`, `search_input.dart`, `logout.dart`.

---

## 5. `assets/`
- `images/` — logos, fonds, icône de l'app (`logo_app.png`).
- `images/onboarding/` — illustrations des écrans d'accueil.
- `images/meals/` — photos de plats d'exemple.

Chaque fichier doit être **déclaré dans `pubspec.yaml`** (section `assets`) pour être embarqué.

---

## 6. `test/`
- `core_test.dart`, `widget_test.dart` — tests généraux.
- `models/` — tests des modèles (ex. `ligne_commande`).
- `services/` — tests du flux de lancement, de la réinitialisation du mot de passe,
  des horaires d'ouverture.
- `widgets/` — tests de la barre de navigation et des micro-interactions.

Lancer : `flutter test`.

---

## 7. Autres dossiers et fichiers

| Élément | Rôle |
|---|---|
| `docs/` | `TOPO_TECHNIQUE.md` (architecture), `recapitulatif_projet_dios_delices.md`, `modernization_roadmap.md`, `back4app_backend_alignment.md` (historique Parse). |
| `third_party/file_picker_fixed/` | Copie locale corrigée du paquet `file_picker`. |
| `.github/workflows/ci.yml` | CI GitHub : `dart analyze`, `flutter test` à chaque push/PR sur `main`. |
| `pubspec.yaml` | Nom, version (`1.0.0+1`), **dépendances**, assets, config de l'icône. |
| `pubspec.lock` | Versions exactes installées (ne pas modifier à la main). |
| `l10n.yaml` | Où trouver les traductions et quel fichier sert de modèle. |
| `analysis_options.yaml` | Règles du linter. |
| `.env` | Clés locales (ex. `CARTO_API_KEY`). **Non versionné.** |
| `dart_defines.json` / `.example.json` | Clés passées au lancement (`CARTO_API_KEY`, `NODE_API_URL`). Le vrai fichier n'est pas versionné. |
| `run.bat` | Raccourci Windows : `flutter run --dart-define-from-file=dart_defines.json`. |
| `README.md` | Installation et lancement. |
| `GUIDE_DEMARCHES_MANUELLES.md` | Démarches à faire hors du code (comptes, stores, services). |
| `implementation_plan.md` | Plan de travail historique. |

> Attention : `.env` est déclaré dans les assets de `pubspec.yaml`, il est donc
> **embarqué dans l'APK/IPA**. N'y mettre que des clés destinées au téléphone
> (comme la clé CARTO), jamais de secret serveur.

---

## 8. Principales dépendances (pubspec.yaml)

| Besoin | Paquets |
|---|---|
| État | `flutter_riverpod` |
| Réseau / temps réel | `http`, `socket_io_client` |
| Cache local | `hive`, `hive_flutter`, `shared_preferences` |
| Cartes | `flutter_map`, `latlong2`, `cached_network_image`, `flutter_cache_manager` |
| Localisation | `geolocator`, `geocoding` |
| Notifications | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| Fichiers / médias | `image_picker`, `file_picker`, `record`, `audioplayers`, `pdf`, `syncfusion_flutter_pdfviewer` |
| Paiement | `flutter_inappwebview` (page Nyole) |
| Graphiques | `fl_chart` |
| Traductions | `flutter_localizations`, `intl` |
| Ancien backend | `parse_server_sdk_flutter` (en cours de retrait) |

---

## 9. Commandes utiles

```bash
flutter pub get                                         # installer les dépendances
flutter run --dart-define-from-file=dart_defines.json   # lancer avec les clés
flutter gen-l10n                                        # régénérer les traductions
dart run build_runner build --delete-conflicting-outputs # régénérer les *.g.dart (Hive)
dart analyze lib                                        # vérifier le code
flutter test                                            # lancer les tests
flutter build apk --release --dart-define-from-file=dart_defines.json
```
