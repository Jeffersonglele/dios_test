# Dios Délices — Dossier Technique

> **Date :** Juin 2026  
> **Repo Flutter :** `github.com/Adigbonon/dios_delices`  
> **Repo Backend :** `github.com/Adigbonon/dios-delices-backend`  
> **Back4App :** `parseapi.back4app.com`  
> **Vercel :** `dios-delices-backend.vercel.app`  

---

## 1. Architecture Générale

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Mobile)                    │
│  State: Riverpod  |  DB: Hive (cache local)  |  GPS: Geo   │
└─────────────────┬───────────────────────────┬───────────────┘
                  │ Parse SDK                  │ REST/HTTP
                  ▼                            ▼
┌─────────────────────────────┐  ┌─────────────────────────────┐
│    Back4App (Parse Cloud)   │  │   Vercel (Serverless)       │
│  cloud/main.js ~2700 lignes │  │  api/fedapay-initiate.js    │
│  Auth, CRUD, Push, Email    │  │  api/fedapay-webhook.js     │
│  Classes: Users, Commande,  │  │  api/generate-invoice.js    │
│  Restaurant, Dish, Adress,  │  │                             │
│  LigneCommande, Comment,    │  │                             │
│  Message, AuditLog, ...     │  │                             │
└─────────────────────────────┘  └─────────────────────────────┘
                  │                            │
                  ▼                            ▼
┌─────────────────────────────┐  ┌─────────────────────────────┐
│  Parse Database (MongoDB)   │  │  Fedapay / Stripe           │
│  US/Canada                  │  │  Paiement en ligne          │
└─────────────────────────────┘  └─────────────────────────────┘
```

---

## 2. Stack Technique

| Couche | Technologie | Détail |
|---|---|---|
| **Frontend** | Flutter 3.x (Dart) | `flutter_map` (OSM), `geolocator`, `shared_preferences` |
| **State** | Riverpod 2.x | `StateNotifierProvider`, `ConsumerStatefulWidget` |
| **Cache local** | Hive | Modèles `@HiveType` avec adapters générés |
| **Cloud** | Back4App (Parse Server) | Cloud Code JS, LiveQuery, Push Notifications |
| **Auth** | Parse Session + PBKDF2 | `request.user` + fallback `userID` param |
| **Paiement** | Fedapay (Afrique) | Webhook Vercel → update Back4App |
| **Factures** | Vercel + PDFKit | `GET /api/generate-invoice?commandeID=X` |
| **Cartes** | OpenStreetMap (gratuit) | `flutter_map` + `latlong2`, routing OSRM |
| **Email** | Nodemailer (Gmail SMTP) | `sendEmail` cloud function |
| **CI/CD** | GitHub Actions | Analyze + Test + JS Check |

---

## 3. Modèle de Données (Classes Parse)

### Classes principales

| Classe | Rôle | Champs clés |
|---|---|---|
| **Users** | Tous les utilisateurs | `userID`, `roleID`(1-5), `email`, `username`, `password`(hashé PBKDF2), `telephone`, `country`, `status`, `identity`, `permisType`, `isOnline`, `consentRGPD`, `consentDate` |
| **Restaurant** | Micro-restaurants | `restaurantID`, `userID`, `name`, `description`, `categories`, `location`(ex-adress), `note`, `nb_orders`, `isOpen`, `isPaused`, `openingDays`, `openingHours`, `openingHoursByDay`, `deliveryFee`, `deliveryRadius`, `minOrderAmount`, `closedDates`, `currency`, `valid` |
| **Dish** | Plats | `dishID`, `userID`, `restauID`, `name`, `price`, `categories`, `note`, `stock`, `isDailySpecial`, `status`, `currency` |
| **Commande** | Commandes | `commandeID`, `userID`, `restauID`, `restaurateurID`, `livreurID`, `deliveryStatus`, `status`, `totalAmount`, `subtotalAmount`, `fraisLivraison`, `serviceFee`, `tva`, `tvaRate`, `reduction`, `promo_code`, `currency`, `dateCommande`, `moyenPaiementID`, `addressID`, `livreurLat`, `livreurLng` |
| **LigneCommande** | Lignes | `ligneID`, `commandeID`, `platID`, `quantite`, `prixUnitaire`, `reduction` |
| **Comment** | Avis/Notes | `userID`, `targetType`(1=resto,2=plat,3=livreur), `targetID`, `note`, `commentaire` |
| **Message** | Messagerie | `fromUserID`, `toUserID`, `text`, `commandeID`, `read` |
| **Adress** | Adresses livraison | `addressID`, `object`(User/Restaurant), `objectID`, `fullAddress`, `city`, `state`, `lat`, `long`, `phone` |
| **Identity** | Pièces identité | `identityID`, `userID`, `type`, `numero`, `image` |
| **MoyenPaiement** | Moyens de paiement | `userID`, `type`(fedapay/cash), `brand`, `last4` |

### Classes techniques

| Classe | Rôle |
|---|---|
| **AuditLog** | Traces de toutes les mutations critiques |
| **UserLogin** | Logs de connexion (userID, IP, date) |
| **VerificationCode** | Codes email temporaires (vérifiés côté serveur) |
| **RateLimit** | Anti force-brute (clé + timestamp) |
| **PromoCode** | Codes promo dynamiques (code, type, valeur, maxUses, expiresAt) |
| **Report** | Signalements de contenu |
| **Dispute** | Litiges/SAV (userID, commandeID, reason, status, resolution, refund) |
| **Banner** | Bannières marketing (title, body, image, actionUrl, expiresAt) |
| **Sequence** | Compteurs atomiques pour IDs (`Users_userID`, `Commande_commandeID`, etc.) |

---

## 4. Rôles Utilisateurs

| ID | Rôle | Description |
|---|---|---|
| 1 | **Admin** | Gestion complète : dashboard multi-pays, promos, litiges, commissions, utilisateurs |
| 2 | **Client** | Commander, noter, messagerie, suivre livraison |
| 3 | **Micro-Restaurant** | Gérer plats/stock, voir commandes, recevoir notifs, dashboard stats |
| 4 | **Super Admin** | Comme Admin + gestion des admins |
| 5 | **Livreur** | Accepter courses, GPS tracking, gains, online/offline |

---

## 5. Fonctionnalités Implémentées (CE QUI EST FAIT ✅)

### 5.1 Authentification & Sécurité

- [x] Inscription avec choix du rôle (Client / Livreur)
- [x] Connexion cloud function `loginUser` + session Parse native
- [x] Mot de passe hashé PBKDF2-SHA512 (sel 16 bytes, 10k itérations)
- [x] Rate limiting : 5 tentatives login / 15 min, 3 emails / heure
- [x] Codes vérification stockés côté serveur (`VerificationCode`), jamais renvoyés au client
- [x] `authGetUser(request)` priorise `request.user` (session Parse), fallback `userID` param
- [x] `requireAdmin(request)` pour opérations sensibles
- [x] Consentement RGPD horodaté (`consentDate`) + case 16 ans obligatoire
- [x] Aucune clé secrète dans le client (`parseRestApiKey`, `stripePublishableKey`, `GMAIL_*` retirées)
- [x] Stripe entièrement supprimé du codebase

### 5.2 Client (roleID=2)

- [x] **Catalogue** : liste restaurants + plats avec filtres (prix, note, catégorie)
- [x] **Détail restaurant / plat** : infos, options, notation
- [x] **Panier** : ajout/suppression, persistant SharedPreferences (survit au crash)
- [x] **Commande** : `createOrder` cloud function atomique (saveAll Commande+Lignes)
  - Validation serveur des prix (recalcul via DB)
  - Vérification restaurant ouvert (closedDates, isOpen, isPaused)
  - Promo validée serveur, TVA automatique (10% EUR / 18% XOF)
  - Frais de service 5%, frais livraison depuis DB resto
- [x] **Paiement** : Fedapay webview + paiement à la livraison
- [x] **Historique commandes** : filtres par statut, noms resto/plat, détails enrichis
- [x] **Notation** : noter resto + plats après commande confirmée
- [x] **Suivi livraison** : barre de progression + mini-map OpenStreetMap + vue plein écran
- [x] **Messagerie** : chat client ↔ restaurateur
- [x] **Litiges** : `createDispute` pour ouvrir un litige sur commande
- [x] **Export données** : `exportUserData` (RGPD - portabilité)
- [x] **Suppression compte** : `suppr1User` cascade soft-delete

### 5.3 Restaurant (roleID=3)

- [x] **Dashboard analytics** : CA jour, total commandes, plats populaires, stock
- [x] **Gestion plats** : créer, modifier, supprimer
- [x] **Stock / épuisé** : `setDishStock`, désactiver plat (status=0)
- [x] **Plat du jour** : flag `isDailySpecial`
- [x] **Pause restaurant** : `pauseRestaurant` → isOpen=0, isPaused=true
- [x] **Horaires** : `openingDays` (Lun,Mar,...), `openingHours` (créneaux), `openingHoursByDay` (JSON)
- [x] **Commandes entrantes** : vue + confirmer/annuler + assigner livreur
- [x] **Notifications push** : abonnement automatique aux canaux restaurateurs
- [x] **Messagerie** : répondre aux clients

### 5.4 Livreur (roleID=5)

- [x] **Inscription** : choix "Livreur" au signup + type véhicule (moto/vélo/voiture)
- [x] **Dashboard** : gains totaux, livraisons en cours, toggle online/offline
- [x] **GPS tracking** : position envoyée toutes les 30s en mode "En route"
- [x] **Navigation** : carte OpenStreetMap + itinéraire OSRM
- [x] **Statuts** : Assigné → Récupéré → En route → Livré
- [x] **Notifications push** : alerte nouvelle course assignée
- [x] **Notation** : `rateLivreur` pour les clients
- [x] **Gains** : `getLivreurEarnings` (total, historique)
- [x] **Online/Offline** : toggle dans l'app bar

### 5.5 Admin / Super Admin (roleID=1, 4)

- [x] **Dashboard** : CA total, users/pays, revenus/devise, top plats, nouvelles inscriptions
- [x] **Commissions** : 10% sur CA (`getCommissionStats`)
- [x] **Promos** : gestion dynamique (`managePromoCode`, `getAllPromoCodes`) — expiration, limite usage
- [x] **Bannières** : gestion contenu éditorial (`manageBanner`, `getBanner`)
- [x] **Push marketing** : `sendMarketingPush` (tous les canaux)
- [x] **Litiges** : `getDisputes` + `resolveDispute` (remboursement marqué)
- [x] **Gestion admins** : créer admin depuis le dashboard
- [x] **Export CSV** : `exportCsv` (users, commandes)
- [x] **Audit log** : toutes les mutations critiques tracées
- [x] **Logs connexion** : `UserLogin` avec IP, date

### 5.6 Conformité Légale

- [x] **RGPD (France)** : consentement horodaté, droit oubli, portabilité, mentions légales
- [x] **Loi 2013-450 (Côte d'Ivoire)** : déclaration ARTCI (à déposer), droit accès/rectification
- [x] **Loi 2017-20 (Bénin)** : APDP (à déclarer), représentant local (à désigner)
- [x] **CGV** : 14 articles, accessibles depuis inscription
- [x] **Privacy Policy** : 13 articles, DPO nommé
- [x] **Mentions légales** : éditeur, hébergeur, médiation
- [x] **TVA** : 10% France, 18% UEMOA
- [x] **Factures** : PDF généré par Vercel

### 5.7 Architecture & Qualité

- [x] Zéro erreur Dart (`dart analyze lib/`)
- [x] Zéro erreur JS (`node --check cloud/main.js`)
- [x] 7 tests unitaires (AppRole, CommandeStatus, widget smoke test)
- [x] CI/CD GitHub Actions (analyze + test + js-check)
- [x] `adress` → `location` renommé dans tout le code
- [x] Code mort supprimé (`CurvedNavigation.dart`, `SimpleUIController.dart`, `translations.dart`)
- [x] GetX + Provider retirés → Riverpod uniquement
- [x] Soft delete (`deletedAt`) sur toutes les classes
- [x] IDs atomiques via `getNextSequence()`
- [x] Pagination `findAll` (skip/limit)
- [x] `createOrder` atomique (saveAll)

---

## 6. À FAIRE (Backend)

### 6.1 Déploiement

1. **Back4App Cloud Code** : uploader `dios-delices-backend/cloud/main.js`
2. **Back4App Env Vars** : `GMAIL_USER`, `GMAIL_PASS`
3. **Back4App Classes** : créer `Message`, `AuditLog`, `UserLogin`, `PromoCode`, `Report`, `Dispute`, `Banner`, `RateLimit`, `VerificationCode`, `Sequence`
4. **Back4App CLPs** : lancer `node scripts/fix_clps.mjs`
5. **Back4App Seed** : lancer `node scripts/reset_complet.mjs` (4 comptes: admin/admin123, awa.cuisine/awa123, lea.gourmande/lea123, pierre.livreur/pierre123)
6. **Vercel** : `cd dios-delices-backend && npm i pdfkit && vercel deploy --prod`
7. **Vercel Env Vars** : `BACK4APP_APP_ID`, `BACK4APP_REST_KEY`, `BACK4APP_SERVER`, `FEDAPAY_API_KEY`, `FEDAPAY_ENV`

### 6.2 Paiement

1. **Fedapay** : créer compte marchand → configurer clé API dans Vercel
2. **Webhook** : URL `https://dios-delices-backend.vercel.app/api/fedapay-webhook` dans dashboard Fedapay
3. **Test** : mode sandbox Fedapay avant production

### 6.3 Monitoring

1. **Firebase Crashlytics** : `flutterfire configure` → `flutter pub add firebase_crashlytics` → init dans `main.dart`
2. **Logs** : activer `enableParseDebugLogs` dans `app_config.dart` pour le debug

### 6.4 Juridique (hors code)

| Document | Statut | Action |
|---|---|---|
| SIRET / RCS | ❌ | Remplir `LegalPage.dart` |
| DPA Back4App | ❌ | Signer https://www.back4app.com/dpa.pdf |
| SCC (transfert hors UE) | ❌ | Document à joindre au DPA |
| DPIA | ❌ | Analyse d'impact traitements (géoloc, paiement) |
| Déclaration ARTCI (CI) | ❌ | Formulaire www.artci.ci |
| Autorisation APDP (Bénin) | ❌ | Demande www.apdp.bj |
| Représentant local CI | ❌ | Désigner personne physique |
| Représentant légal Bénin | ❌ | Désigner personne physique |
| DPO nommé | ❌ | Remplacer `dpo@diosdelices.com` par nom réel |
| CGV / Privacy finale | ❌ | Faire relire par un juriste |

---

## 7. À FAIRE (Frontend)

### 7.1 Accessibilité

- [ ] Tester TalkBack Android (Paramètres → Accessibilité)
- [ ] Tester VoiceOver iOS (Réglages → Accessibilité)
- [ ] Ajouter `tooltip` aux 20+ `IconButton` restants
- [ ] Vérifier contrastes couleurs : ratio minimum 4.5:1 (https://webaim.org/resources/contrastchecker/)
- [ ] Tester navigation au clavier (switch access)

### 7.2 Design

- [ ] **Espace Restaurateur** : améliorer UI (actuellement HomeMicroRestau.dart basique)
- [ ] **Espace Livreur** : améliorer DeliveryDashboard (déjà refait, 350+ lignes)
- [ ] **Onboarding** : animations Lottie à peaufiner
- [ ] **Mode sombre** : non implémenté
- [ ] **Page loading skeletons** : remplacer les `CircularProgressIndicator` par des shimmers

---

## 8. À FAIRE (Design System)

- [ ] **Composants** : créer `lib/widgets/` avec boutons, cartes, chips réutilisables
- [ ] **Couleurs** : palette centralisée dans `app_theme.dart` (actuellement `Colors.deepOrange` + `Colors.teal` en dur)
- [ ] **Typographie** : `google_fonts` déjà importé, standardiser les styles
- [ ] **Iconographie** : `font_awesome_flutter` déjà importé
- [ ] **Responsive** : `size.width > 600` utilisé pour desktop, tester tablettes
- [ ] **l10n** : Français + Anglais 

---

## 9. Fichiers Clés

```
lib/
├── main.dart                          # Entry point, MaterialApp, providers
├── config/app_config.dart             # Parse keys, Vercel URL
├── core/
│   ├── app_role.dart                  # Enum AppRole (1-5)
│   └── commande_status.dart           # Statuts commandes
├── modeles/
│   ├── users.dart                     # Modèle Users (Hive + Parse)
│   ├── restaurant.dart                # Modèle Restaurant
│   ├── dish.dart                      # Modèle Dish
│   ├── commande.dart                  # Modèle Commande
│   ├── address.dart                   # Modèle Address
│   ├── ligne_commande.dart            # Modèle LigneCommande
│   └── ...
├── providers/
│   ├── cart_provider.dart             # Riverpod StateNotifier panier
│   ├── ui_provider.dart               # ObscureText provider
│   └── ...
├── services/
│   ├── notification_service.dart      # Push notifications
│   ├── session_service.dart           # Session stockée SharedPreferences
│   ├── launch_flow_service.dart       # Splash → onboarding/signup/home
│   └── ...
├── Screen/
│   ├── authentification/              # Login, Signup
│   ├── admin/                         # AdminDashboard
│   ├── restaurants/                   # RestaurantDetails, RestaurantFormPage
│   ├── livreur/                       # DeliveryDashboard
│   ├── micro_restau/                  # HomeMicroRestau
│   ├── curved_navigation/             # Nav bars (Admin, Restau, UserFR, UserAfr)
│   ├── legal/                         # CGVPage, PrivacyPolicyPage, LegalPage
│   ├── verif_confirm/                 # VerificationPage, IdentityVerification
│   ├── password/                      # PasswordReset
│   └── ...
├── mails/mails.dart                   # sendVerificationEmail, verifyEmailCode
├── utils/
│   ├── strings.dart                   # Remplace GetX .tr
│   └── toast.dart                     # Toast notifications
└── db/database_helper.dart            # Hive CRUD

dios-delices-backend/
├── cloud/main.js                      # Parse Cloud Code (~2700 lignes)
├── api/
│   ├── fedapay-initiate.js            # POST : initie paiement Fedapay
│   ├── fedapay-webhook.js             # POST : callback Fedapay
│   └── generate-invoice.js            # GET  : génère PDF facture
├── scripts/
│   ├── reset_complet.mjs              # Reset + seed tout-en-un
│   ├── fix_clps.mjs                   # Corrige les CLPs
│   └── ...
├── seed_initial.json                  # 4 users + 1 resto + 2 plats + 4 adresses
├── schema_corrected.json              # Schema Back4App
├── package.json                       # Vercel + nodemailer
└── vercel.json                        # Config Vercel
```

---

## 10. Commandes Utiles

```bash
# Flutter
cd dios_delices
flutter pub get
dart analyze lib/               # Vérification (0 erreur)
flutter test test/core_test.dart # Tests unitaires

# Backend
cd dios-delices-backend
node --check cloud/main.js      # Vérification JS (0 erreur)
node scripts/reset_complet.mjs  # Reset + seed Back4App
node scripts/fix_clps.mjs       # Réparer les CLPs
npm i pdfkit                    # Pour factures PDF
vercel deploy --prod            # Déployer sur Vercel
```

---

## 11. Comptes de Test (seed_initial.json)

| Username | Password | Rôle | RoleID |
|---|---|---|---|
| `admin` | `admin123` | Super Admin | 4 |
| `awa.cuisine` | `awa123` | Micro-Restaurant | 3 |
| `lea.gourmande` | `lea123` | Client | 2 |
| `pierre.livreur` | `pierre123` | Livreur | 5 |

---

## 12. Contacts

- **Lead Dev** : Rodica Adigbonon
- **Email DPO** : dpo@diosdelices.com (à remplacer par nom réel)
- **Email Support** : contact@diosdelices.com
- **Hébergeur** : Back4App (440 N Wolfe Rd, Sunnyvale, CA 94085, USA) + Vercel Inc. (Walnut, CA, USA)
