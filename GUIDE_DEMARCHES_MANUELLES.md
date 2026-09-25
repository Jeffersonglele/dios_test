# Guide Complet des Démarches Manuelles — Dios Délices

Ce document liste **TOUTES** les actions qui nécessitent une intervention humaine **hors code** (création de comptes, configuration, démarches admin, etc.). Rien n'est laissé de côté.

---

## 1. COMPTES & CLÉS API — FOURNISSEURS EXTERNES

### 1.1 CinetPay (Paiement + Virements Mobile Money) — **CRITIQUE Phase 1 & 3**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Créer compte marchand CinetPay** | S'inscrire sur `cinetpay.com` → espace marchand → RDC | 🔴 Phase 1 |
| **Obtenir API Key + Site ID** | Dashboard → Paramètres API → `API_KEY` + `SITE_ID` | 🔴 Phase 1 |
| **Configurer Webhook URL** | Dashboard → Webhooks → `https://dios-delices-backend.vercel.app/api/cinetpay-webhook` | 🔴 Phase 1 |
| **Activer CinetPay Transfer API** | Contacter support CinetPay pour activer les virements Mobile Money (MTN/Airtel) vers restaurateurs/livreurs | 🔴 Phase 3 |
| **Obtenir clés Transfer API** | `TRANSFER_API_KEY`, `TRANSFER_SITE_ID` (souvent distincts des clés paiement) | 🔴 Phase 3 |
| **Configurer webhook Transfer** | Dashboard → Transfer Webhooks → `https://dios-delices-backend.vercel.app/api/cinetpay-transfer-webhook` (à créer) | 🔴 Phase 3 |
| **Passer en mode Production** | Soumettre documents KYC (RCCM, ID dirigeant, statuts) → validation CinetPay (2-5 jours) | 🔴 Phase 3 |
| **Configurer sandbox** | Tester avec comptes sandbox CinetPay avant prod | 🟠 Phase 1 |

> **Note** : CinetPay est le **seul** prestataire paiement retenu. Supprimer Fedapay (fichiers `fedapay-*.js` dans `api/`).

---

### 1.2 Africa's Talking (SMS OTP + Notifications) — **CRITIQUE Phase 1**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Créer compte Africa's Talking** | `africastalking.com` → choix pays **RDC** (+243) | 🔴 Phase 1 |
| **Obtenir API Key + Username** | Dashboard → Settings → API Key (sandbox puis production) | 🔴 Phase 1 |
| **Acheter crédit SMS** | Recharger compte (minimum ~$10 pour tests) | 🔴 Phase 1 |
| **Configurer Sender ID** | Demander "DiosDelices" comme Sender ID (validation 1-2 jours) | 🔴 Phase 1 |
| **Tester en sandbox** | Numéros sandbox fournis par AT → valider envoi OTP 4 chiffres | 🔴 Phase 1 |
| **Passer en production** | Valider KYC entreprise (RCCM, ID dirigeant) | 🔴 Phase 1 |

> **Alternative** : Twilio (plus cher, couverture RDC moindre). Décision déjà prise : **Africa's Talking**.

---

### 1.3 Back4App (Parse Server + MongoDB) — **DÉJÀ CONFIGURÉ MAIS À VÉRIFIER**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Vérifier App ID / REST API Key / Master Key** | Dashboard → App Settings → Security & Keys | 🟠 Phase 1 |
| **Configurer Variables d'Environnement Cloud Code** | Settings → Cloud Code → Environment Variables :<br>`GMAIL_USER` (ex: `noreply@diosdelices.com`)<br>`GMAIL_PASS` (mot de passe application Gmail) | 🟠 Phase 1 |
| **Créer classes Back4App manquantes** | Via Dashboard > Core > Classes : `OTPCode`, `Dispute`, `UserDisputeScore`, `Payout`, `PlatformConfig`, `ExchangeRate`, `DriverRating` (voir Phase 1-4) | 🟠 Phase 1-4 |
| **Configurer Push Notifications (Parse Push)** | Settings > Push > iOS (certificat .p8) + Android (FCM Server Key) | 🟠 Phase 1 |
| **Activer LiveQuery** | Settings > LiveQuery → Enable + choisir classes à surveiller (`Commande`, `Dispute`, etc.) | 🟡 Phase 2 |

---

### 1.4 Vercel (Serverless Functions) — **DÉJÀ DÉPLOYÉ MAIS À CONFIGURER**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Lier repo GitHub** | `dios-delices-backend` → Vercel Project | 🟠 Phase 1 |
| **Configurer Environment Variables** | Dashboard → Settings → Environment Variables :<br>`CINETPAY_API_KEY`, `CINETPAY_SITE_ID`<br>`CINETPAY_TRANSFER_API_KEY`, `CINETPAY_TRANSFER_SITE_ID`<br>`AFRICASTALKING_USERNAME`, `AFRICASTALKING_API_KEY`<br>`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`<br>`GMAIL_USER`, `GMAIL_PASS` (pour PDF invoices)<br>`BACK4APP_APP_ID`, `BACK4APP_REST_KEY`, `BACK4APP_MASTER_KEY` | 🔴 Phase 1 |
| **Configurer domaines personnalisés** | `api.diosdelices.com` → Vercel (optionnel) | 🟢 Phase 5 |
| **Vérifier Cron Jobs (vercel.json)** | CRON pour : `checkPaymentTimeout` (1min), `processWeeklyPayouts` (lundi 6h), `checkVerificationExpiry` (quotidien), `anonymizeDeletedAccounts` (quotidien), `healthCheckCinetPay` (5min) | 🔴 Phase 3-5 |

---

### 1.5 Cloudinary (Images + PDFs) — **DÉJÀ CONFIGURÉ**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Vérifier credentials** | Dashboard → Settings → API Keys | 🟠 Phase 1 |
| **Configurer unsigned upload preset** | Settings → Upload → Upload presets → `unsigned_preset` pour upload direct Flutter | 🟠 Phase 1 |
| **Dossiers organisés** | Créer dossiers : `restaurants/`, `dishes/`, `identity_docs/`, `delivery_proofs/`, `invoices/` | 🟡 Phase 4 |

---

### 1.6 Firebase Cloud Messaging (Push) — **DÉJÀ CONFIGURÉ**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Vérifier google-services.json / GoogleService-Info.plist** | Dans `android/app/` et `ios/Runner/` | 🟠 Phase 1 |
| **Server Key FCM dans Back4App** | Back4App Settings > Push > Android > FCM Server Key | 🟠 Phase 1 |
| **APNs Key pour iOS** | Back4App Settings > Push > iOS > .p8 key + Key ID + Team ID | 🟠 Phase 1 |

---

### 1.7 Supabase (PostgreSQL — Zones/Villes uniquement) — **DÉJÀ CONFIGURÉ**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Vérifier URL + Anon Key** | Dashboard → Settings → API | 🟢 Phase 1 |
| **Tables existantes** | `zones`, `cities` — déjà peuplées pour Lubumbashi | 🟢 Phase 1 |

---

### 1.8 OSRM (Calcul distance backend) — **PHASE 5 (Basse)**

| Action | Détail | Priorité |
|--------|--------|----------|
| **Héberger OSRM** | Option A : Docker sur VPS (recommandé RDC - latence)<br>Option B : OSRM public (demo) — non fiable prod | 🟢 Phase 5 |
| **Configurer URL dans PlatformConfig** | Back4App > PlatformConfig > `osrm_base_url` | 🟢 Phase 5 |

---

### 1.9 Gmail / SMTP (Emails transactionnels + Factures PDF)

| Action | Détail | Priorité |
|--------|--------|----------|
| **Créer compte Gmail dédié** | `noreply@diosdelices.com` (Google Workspace recommandé) | 🟠 Phase 1 |
| **Activer "Mot de passe d'application"** | Sécurité Google → Mots de passe d'applications → "Back4App Cloud Code" | 🟠 Phase 1 |
| **Configurer dans Back4App Env Vars** | `GMAIL_USER`, `GMAIL_PASS` | 🟠 Phase 1 |

---

## 2. CONFIGURATION BACK4APP — CLASSES & INDEX (PHASES 1-4)

> Ces classes doivent être créées **manuellement** dans Back4App Dashboard > Core > Classes avant d'écrire le Cloud Code.

### 2.1 Phase 1 — OTP & Compte Simplifié

| Classe | Champs clés | Index suggérés |
|--------|-------------|----------------|
| **OTPCode** | `phone` (String), `code` (String), `expiresAt` (Date), `attempts` (Number), `createdAt` | `phone` + `expiresAt` (TTL), `phone` unique partiel |
| **_User** (existant — modifier) | Ajouter : `phone` (String, unique), `isPhoneVerified` (Boolean), `isSimplified` (Boolean), `isAgeConfirmed` (Boolean), `lastVerificationDate` (Date) | `phone` unique, `email` unique (partiel) |

---

### 2.2 Phase 2 — Litiges

| Classe | Champs clés | Index suggérés |
|--------|-------------|----------------|
| **Dispute** | `orderId` (Pointer Commande), `openedBy` (Pointer _User), `type` (String: missing_item/not_delivered/bad_quality/other), `description` (String), `photoUrls` (Array<String>), `status` (String: open/resolved_client/resolved_restaurant/resolved_driver/rejected), `resolvedBy` (Pointer _User), `resolutionNotes` (String), `refundAmount` (Number), `createdAt`, `resolvedAt` | `status`, `orderId`, `openedBy`, `createdAt` |
| **UserDisputeScore** | `userId` (Pointer _User), `disputes30d` (Number), `disputes90d` (Number), `lastUpdated` (Date) | `userId` unique, `lastUpdated` |

---

### 2.3 Phase 3 — Finances

| Classe | Champs clés | Index suggérés |
|--------|-------------|----------------|
| **Payout** | `recipientId` (Pointer _User), `recipientType` (String: restaurant/driver), `amount` (Number), `currency` (String: CDF/USD), `payoutMethod` (String: mobile_money), `payoutReference` (String: CinetPay transfer ID), `status` (String: pending/processing/completed/failed), `periodStart` (Date), `periodEnd` (Date), `invoiceUrl` (String: Cloudinary), `createdAt`, `completedAt` | `recipientId` + `periodStart`, `status`, `payoutReference` unique |
| **PlatformConfig** | `key` (String, unique), `value` (Mixed), `updatedBy` (Pointer _User), `updatedAt` (Date) | `key` unique |
| **ExchangeRate** | `fromCurrency` (String), `toCurrency` (String), `rate` (Number), `source` (String: BCC/market), `effectiveDate` (Date), `setBy` (Pointer _User) | `fromCurrency` + `toCurrency` + `effectiveDate` unique |

**Clés PlatformConfig initiales à créer manuellement :**
| Clé | Valeur | Type |
|-----|--------|------|
| `commission_rate` | `0.15` | Number |
| `dispute_threshold_warning` | `3` | Number |
| `dispute_threshold_suspension` | `5` | Number |
| `driver_min_rating` | `3.5` | Number |
| `payment_timeout_minutes` | `5` | Number |
| `delivery_proof_threshold_amount` | `50000` | Number (CDF) |
| `driver_acceptance_warning_threshold` | `70` | Number (% sur 7j) |
| `driver_acceptance_suspension_threshold` | `50` | Number (% sur 7j) |

---

### 2.4 Phase 4 — Livraison Avancée

| Classe | Champs clés | Index suggérés |
|--------|-------------|----------------|
| **DriverRating** | `orderId` (Pointer Commande), `driverId` (Pointer _User), `clientId` (Pointer _User), `score` (Number 1-5), `comment` (String), `createdAt` | `driverId` + `createdAt`, `orderId` unique |
| **Commande** (existant — ajouter) | `deliveryProof` (Object: {photoUrl, latitude, longitude, timestamp, code}), `deliveryCode` (String, 4 chiffres) | — |

---

## 3. DÉPLOIEMENT & CONFIGURATION CODE

### 3.1 Back4App Cloud Code

| Action | Commande / Interface | Priorité |
|--------|---------------------|----------|
| **Uploader `cloud/main.js`** | Dashboard > Cloud Code > "Deploy Cloud Code" ou `b4app deploy cloud` | 🔴 Phase 1 |
| **Vérifier syntaxe JS** | `node --check cloud/main.js` en local avant deploy | 🔴 Phase 1 |
| **Configurer LiveQuery classes** | Dashboard > LiveQuery > Enable + sélectionner `Commande`, `Dispute`, `Payout` | 🟠 Phase 2 |

---

### 3.2 Vercel APIs

| Action | Commande / Interface | Priorité |
|--------|---------------------|----------|
| **Deploy `api/`** | `vercel --prod` depuis `dios-delices-backend/` | 🔴 Phase 1 |
| **Supprimer fichiers Fedapay** | `rm api/fedapay-initiate.js api/fedapay-webhook.js` + redeploy | 🟠 Phase 1 |
| **Créer nouveaux fichiers API** | `api/send-sms.js`, `api/cinetpay-transfer.js`, `api/generate-commission-invoice.js`, `api/health-cinetpay.js` | 🔴 Phases 1,3,5 |
| **Configurer `vercel.json` CRONs** | Voir section 1.4 — CRONs | 🔴 Phases 3,5 |

---

### 3.3 Flutter App — Configuration Build

| Action | Fichier / Commande | Priorité |
|--------|-------------------|----------|
| **Configurer `app_config.dart`** | `lib/config/app_config.dart` : URLs Back4App, Vercel, clés publiques | 🔴 Phase 1 |
| **Variables d'environnement Flutter** | `--dart-define=BACK4APP_APP_ID=xxx` etc. ou `.env` + `flutter_dotenv` | 🔴 Phase 1 |
| **google-services.json / GoogleService-Info.plist** | Déjà en place → vérifier | 🟠 Phase 1 |
| **Build Android (AAB)** | `flutter build appbundle --release` | 🟢 Phase 5 |
| **Build iOS (IPA)** | `flutter build ipa --release` (nécessite Mac + Certificats Apple) | 🟢 Phase 5 |
| **Publier Play Store / App Store** | Console Play / App Store Connect | 🟢 Phase 5 |

---

## 4. DÉMARCHES ADMINISTRATIVES & JURIDIQUES — RDC (République Démocratique du Congo)

> **Critique pour lancement légal en RDC**

### 4.1 Constitution Société & Licences

| Démarche | Organisme | Délai estimé | Documents requis |
|----------|-----------|--------------|------------------|
| **Immatriculation RCCM** | Guichet Unique de Création d'Entreprise (GUCE) | 3-7 jours | Statuts, PV AG, pièce identité dirigeants, justificatif siège |
| **Numéro d'Identification Nationale (NINA)** | DGI (Direction Générale des Impôts) | 1-2 jours | RCCM, pièce identité |
| **Registre du Commerce (RC)** | Tribunal de Commerce / GUCE | Inclus dans RCCM | — |
| **Autorisation d'exercer (Commerce général)** | Ministère du Commerce Extérieur | 15-30 jours | RCCM, NINA, local commercial |
| **Licence de paiement mobile / agrément** | Banque Centrale du Congo (BCC) | 3-6 mois | Dossier complet, capital minimum, conformité AML/CFT |
| **Déclaration CNSS** | Caisse Nationale de Sécurité Sociale | 1 mois après 1er salarié | RCCM, liste employés |

> **Note** : Pour opérer en tant que plateforme de paiement (intermédiation), un **agrément BCC** est requis. Vérifier si le modèle "marketplace" (pas de détention fonds) exempte partiellement. Consulter un avocat spécialisé fintech RDC.

---

### 4.2 Fiscalité & Comptabilité

| Obligation | Fréquence | Détail |
|------------|-----------|--------|
| **TVA (18% RDC)** | Mensuelle (déclaration 20 du mois suivant) | Factures clients CDF + factures commission restaurateurs |
| **Impôt sur les Sociétés (30%)** | Annuelle (bilan 30 avril) | Résultat net imposable |
| **Retenue à la source (fournisseurs/prestataires)** | Mensuelle | 10-15% selon nature |
| **Facturation électronique** | Obligatoire depuis 2024 | Numérotation séquentielle `DD-YYYYMM-XXXX` (voir Phase 3.4) |
| **Conservation factures 10 ans** | Continu | PDF + origine numérique (Cloudinary) |

> **Action** : Engager un **expert-comptable agréé RDC** dès Phase 3 (facturation commission).

---

### 4.3 Protection Données & Conformité

| Démarche | Organisme | Note |
|----------|-----------|------|
| **Déclaration traitement données** | ARTCI (Autorité de Régulation des Télécoms) ou autorité équivalente RDC | Vérifier loi 2023 sur protection données RDC |
| **Désignation DPO (Délégué à la Protection des Données)** | Interne ou externe | Déjà prévu dans Privacy Policy |
| **Registre des traitements** | Interne | Documenter : clients, restaurateurs, livreurs, admins |
| **Procédure droit d'accès / effacement** | Interne | Déjà implémenté (soft delete 30j + anonymisation 1 an) |

---

### 4.4 Conditions Générales & Mentions Légales

| Document | Statut | Action |
|----------|--------|--------|
| **CGV (Conditions Générales de Vente)** | ✅ Rédigées (14 articles) | Traduire en lingala/swahili si nécessaire |
| **Politique Confidentialité** | ✅ 13 articles + DPO nommé | Mettre à jour pour OTP SMS + compte simplifié |
| **Mentions Légales** | ✅ Éditeur, hébergeur, médiation | Vérifier adresse physique RDC |
| **CGU Livreurs / Restaurateurs** | À créer | Contrats cadres distincts |

---

## 5. PARTENARIATS OPÉRATIONNELS — LANCEMENT RDC

### 5.1 Restaurateurs (Onboarding)

| Action | Responsable | Délai |
|--------|-------------|-------|
| **Recruter premiers restaurants (Lubumbashi)** | Équipe terrain / BD | Phase 1-2 |
| **Signer contrats cadre** | Juridique | Avant 1ère commande |
| **Collecter pièces KYC (RCCM, ID dirigeant, RIB Mobile Money)** | Admin dashboard | Ongoing |
| **Configurer frais livraison par zone** | Admin dashboard | Phase 1 |

---

### 5.2 Livreurs

| Action | Responsable | Délai |
|--------|-------------|-------|
| **Recruter flotte initiale (motos)** | Équipe terrain | Phase 1-2 |
| **Vérifier permis + assurance moto** | Admin dashboard | Ongoing |
| **Former à l'app (prise photo, code livraison)** | Ops | Phase 4 |
| **Configurer rémunération (base + km + pourboire)** | Admin dashboard > PlatformConfig | Phase 3 |

---

### 5.3 Assurances

| Type | Couverture | Fournisseur suggéré |
|------|------------|---------------------|
| **RC Pro plateforme** | Dommages tiers | Assurances locales (Sonas, etc.) |
| **Assurance marchandises transportées** | Perte/vol pendant livraison | Optionnel au début |
| **Assurance livreurs (accidents)** | Individuelle accident | Négocier groupe |

---

## 6. TESTS & RECETTE (PRÉ-LANCEMENT)

### 6.1 Environnements

| Env | URL Back4App | URL Vercel | Usage |
|-----|--------------|------------|-------|
| **Sandbox/Dev** | `parseapi.back4app.com` (app dev) | `dios-delices-backend-git-dev.vercel.app` | Dev quotidien |
| **Staging** | App Back4App dédiée | `dios-delices-backend-staging.vercel.app` | Recette complète |
| **Production** | App Back4App prod | `dios-delices-backend.vercel.app` | Live |

> **Action** : Créer app Back4App "Staging" distincte de Prod.

---

### 6.2 Scénarios E2E à valider (manuellement)

| # | Scénario | Données test | Critère réussite |
|---|----------|--------------|------------------|
| 1 | Inscription client téléphone seul → OTP → 18+ → commande → paiement CinetPay sandbox → assignation livreur → photo livraison → facture PDF | Numéro +243 sandbox, carte test CinetPay | Commande `livrée`, facture générée, commission split |
| 2 | Annulation client < 5min paiement → remboursement auto | Même commande | Statut `annulée`, remboursement CinetPay déclenché |
| 3 | Litige client (photo) → admin tranche → remboursement | Commande livrée hier | Litige `résolu_client`, remboursement CinetPay |
| 4 | Versement hebdo restaurateur → virement Mobile Money → facture commission PDF | 5 commandes semaine | Payout `completed`, facture commission dispo resto |
| 5 | Livre note < 3.5 → avertissement → < 3.0 suspension | 10 courses notées | Push avertissement puis suspension auto |
| 6 | Compte simplifié (pas app) → notif SMS tracking lien web | Numéro non enregistré | SMS reçu avec lien tracking |
| 7 | CinetPay down → health check → alerte SMS fondateur → app affiche "paiement indisponible" | Simuler API down | Alerte reçue, UI bloquée paiement |

---

### 6.3 Tests de Charge (optionnel pré-lancement)

| Outil | Cible | Métrique |
|-------|-------|----------|
| k6 / Artillery | Vercel APIs (cinetpay-initiate, webhook) | 100 req/s, p95 < 500ms |
| k6 | Back4App Cloud Code (createOrder, updateStatut) | 50 req/s, p95 < 800ms |

---

## 7. CHECKLIST RÉCAPITULATIF PAR PHASE

### ✅ PHASE 1 — OTP SMS & Compte Simplifié (5-6 jours)

**MANUEL À FAIRE AVANT DE CODER :**
- [ ] Créer compte **Africa's Talking** RDC + acheter crédit + Sender ID
- [ ] Récupérer `AFRICASTALKING_USERNAME`, `AFRICASTALKING_API_KEY`
- [ ] Configurer variables Vercel + Back4App Env
- [ ] Créer classe `OTPCode` dans Back4App Dashboard
- [ ] Modifier classe `_User` (champs phone, isPhoneVerified, isSimplified, isAgeConfirmed)
- [ ] Créer compte **Gmail** `noreply@diosdelices.com` + mot de passe application
- [ ] Déployer `cloud/main.js` (fonctions sendOTP, verifyOTP, loginByPhone, upgradeSimplifiedAccount)
- [ ] Déployer `api/send-sms.js` sur Vercel
- [ ] Build Flutter + test OTP sandbox

---

### ✅ PHASE 2 — Litiges (4-5 jours)

**MANUEL :**
- [ ] Créer classes `Dispute`, `UserDisputeScore` dans Back4App
- [ ] Déployer Cloud Code (openDispute, resolveDispute, getDisputes, autoSuspendCheck)
- [ ] Configurer seuils dans `PlatformConfig` (dispute_threshold_warning=3, suspension=5)
- [ ] Build Flutter (écrans litiges client + admin)

---

### ✅ PHASE 3 — Finances (5-7 jours) **PLUS CRITIQUE ADMIN**

**MANUEL AVANT CODAGE :**
- [ ] **Activer CinetPay Transfer API** (contacter support, fournir RCCM, KYC dirigeant)
- [ ] Récupérer `CINETPAY_TRANSFER_API_KEY`, `CINETPAY_TRANSFER_SITE_ID`
- [ ] Configurer webhook Transfer CinetPay vers `api/cinetpay-transfer-webhook.js`
- [ ] Créer classes `Payout`, `PlatformConfig`, `ExchangeRate` dans Back4App
- [ ] **Peupler `PlatformConfig`** avec 8 clés initiales (voir §2.3)
- [ ] Engager **expert-comptable RDC** pour validation facturation commission
- [ ] Déployer `api/cinetpay-transfer.js`, `api/generate-commission-invoice.js`
- [ ] Configurer CRON `processWeeklyPayouts` (lundi 6h) + `setDailyExchangeRate` (quotidien 9h)
- [ ] Build Flutter (espace restaurateur factures + double devise CDF/USD)

---

### ✅ PHASE 4 — Livraison Avancée (4-5 jours)

**MANUEL :**
- [ ] Créer classe `DriverRating` dans Back4App
- [ ] Ajouter champs `deliveryProof`, `deliveryCode` sur classe `Commande`
- [ ] Configurer `delivery_proof_threshold_amount` dans PlatformConfig
- [ ] Déployer Cloud Code (submitDeliveryProof, generateDeliveryCode, rateDriver, trackDriverAcceptance)
- [ ] Build Flutter (caméra livreur, notation livreur, taux acceptation)

---

### ✅ PHASE 5 — Infra & CRON (3-4 jours)

**MANUEL :**
- [ ] Configurer tous les CRONs dans `vercel.json` :
  - `checkPaymentTimeout` : `*/1 * * * *` (toutes les minutes)
  - `processWeeklyPayouts` : `0 6 * * 1` (lundi 6h)
  - `processDriverPayouts` : `0 6 * * 1` (lundi 6h)
  - `checkVerificationExpiry` : `0 9 * * *` (quotidien 9h)
  - `anonymizeDeletedAccounts` : `0 2 * * *` (quotidien 2h)
  - `healthCheckCinetPay` : `*/5 * * * *` (toutes les 5 min)
- [ ] Créer `api/health-cinetpay.js` + déployer
- [ ] Configurer alerte SMS fondateur (numéro personnel) via Africa's Talking
- [ ] Supprimer fichiers Fedapay (`rm api/fedapay-*.js` + redeploy)
- [ ] Héberger **OSRM** sur VPS RDC (ou configurer URL publique fiable)
- [ ] Build final + publication stores

---

## 8. CONTACTS CLÉS À PRÉPARER

| Rôle | Contact | Urgence |
|------|---------|---------|
| **Support CinetPay (activation Transfer)** | `support@cinetpay.com` / +225 27 22 48 48 48 | 🔴 Phase 3 |
| **Africa's Talking Support** | `support@africastalking.com` / Dashboard chat | 🔴 Phase 1 |
| **Expert-comptable RDC (agréé)** | À identifier (cabinet local Lubumbashi/Kinshasa) | 🔴 Phase 3 |
| **Avocat fintech / droit numérique RDC** | À identifier (Barreau de Lubumbashi) | 🟠 Phase 1 |
| **Back4App Support** | `support@back4app.com` / Discord | 🟠 Continu |
| **Vercel Support** | Dashboard > Help center / `support@vercel.com` | 🟢 Rare |

---

## 9. BUDGET ESTIMATIF (HORS DÉV)

| Poste | Coût mensuel / ponctuel | Note |
|-------|------------------------|------|
| **CinetPay** | 1.5% + 150 FCFA / txn + frais Transfer ~1% | Sur volume |
| **Africa's Talking SMS** | ~$0.015/SMS RDC | ~$50-100/mois lancement |
| **Back4App** | $25-100/mo (plan Shared → Dedicated) | Selon charge |
| **Vercel** | Gratuit → $20/mo (Pro) | Serverless functions |
| **Cloudinary** | Gratuit (25GB) → $89/mo | Images + PDFs |
| **Firebase** | Gratuit (Spark) → Blaze pay-as-you-go | Push notifications |
| **Supabase** | Gratuit (500MB) → $25/mo | Zones/villes seulement |
| **VPS OSRM (RDC)** | $20-50/mo (2-4 vCPU, 4-8GB RAM) | Phase 5 seulement |
| **Expert-comptable RDC** | $200-500/mo | Obligatoire |
| **Avocat (setup initial)** | $1000-3000 (forfait) | Ponctuel |
| **Assurance RC Pro** | $500-1500/an | Selon couverture |
| **Google Play Console** | $25 (unique) | Publication Android |
| **Apple Developer Program** | $99/an | Publication iOS |

---

## 10. ORDRE D'EXÉCUTION RECOMMANDÉ (CRITICAL PATH)

```
SEMAINE 1-2 (Parallèle) :
├── 1. Créer comptes Africa's Talking + CinetPay (sandbox)
├── 2. Configurer Back4App (classes Phase 1, Env vars, Push)
├── 3. Configurer Vercel (Env vars, deploy api/)
├── 4. Engager expert-comptable RDC + avocat (démarrage dossier)
├── 5. Déployer Cloud Code Phase 1 + api/send-sms.js
└── 6. Build Flutter Phase 1 → Test OTP sandbox

SEMAINE 3-4 :
├── 7. Déployer Phase 2 (Litiges) + test E2E
├── 8. KYC CinetPay Production + Activer Transfer API
├── 9. Démarches RCCM / NINA / Autorisation Commerce (si pas fait)
└── 10. Recruter 5-10 restaurants + 10 livreurs pilotes

SEMAINE 5-7 :
├── 11. Déployer Phase 3 (Finances, Payouts, Double devise)
├── 12. Configurer CRONs Vercel + test payouts sandbox
├── 13. Finaliser facturation commission avec expert-comptable
└── 14. Déployer Phase 4 (Livraison avancée)

SEMAINE 8-9 :
├── 15. Déployer Phase 5 (CRONs, Health check, OSRM, Anonymisation)
├── 16. Tests de charge + Recette complète 7 scénarios
├── 17. Build Release + Publication Stores
└── 18. LANCEMENT PRODUCTION LUBUMBASHI
```

---

## 11. DOCUMENTS À PRÉPARER / ARCHIVER

- [ ] Statuts société (certifié)
- [ ] RCCM + NINA
- [ ] Procuration gérant pour démarches
- [ ] Contrats cadres Restaurateur / Livreur (signés)
- [ ] KYC CinetPay complet (pièces dirigeants, statuts, RCCM, justificatif siège)
- [ ] Attestation assurance RC Pro
- [ ] Registre des traitements données (RGPD/loi RDC)
- [ ] Procédures interne : litiges, remboursements, suppression comptes, incidents paiement
- [ ] Manuel opérateur livreur (PDF pour formation)
- [ ] Guide restaurateur (onboarding, dashboard, factures)

---

**Document généré automatiquement depuis `implementation_plan.md` + `TOPO_TECHNIQUE.md` + `docs/recapitulatif_projet_dios_delices.md`**

**Dernière mise à jour :** Juillet 2026  
**Version :** 1.0 — Prêt pour exécution