# Plan d'implémentation — Tâches Lead Dev restantes DiosDelices

## Contexte & État des lieux

Audit complet du codebase :
- **Backend** : [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js) — **4139 lignes**, ~80+ Cloud Functions
- **Schéma** : [schema.json](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/schema/schema.json) — **24 classes Back4App**
- **APIs Vercel** : [api/](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api) — 12 serverless functions
- **App Flutter** : 22 modules d'écrans, 11 modèles Hive, 11 services

### Architecture
```
Flutter App ──→ Back4App (Parse Server / MongoDB) ← logique métier principale
             ──→ Vercel Serverless ← CinetPay, factures PDF
             ──→ Supabase (PostgreSQL) ← zones, villes uniquement
             ──→ Firebase Cloud Messaging ← push notifications
             ──→ Cloudinary ← images + PDFs
             ──→ Gmail SMTP / SendGrid ← emails
```

**Projet à ~85-90% complet.** Ce plan couvre les ~10-15% restants.

---

## Décisions confirmées ✅

| Question | Décision                                                                                               |
|----------|--------------------------------------------------------------------------------------------------------|
| Provider SMS | **Africa's Talking** (couverture RDC, ~0.02$/SMS, connexions directes Vodacom/Orange/Airtel/Africell)  |
| Paiement à la livraison | **SUPPRIMÉ** — CinetPay exclusivement, jamais de paiement sans confirmation                            |
| Fichiers Fedapay | **À SUPPRIMER** — CinetPay est le choix exclusif                                                       |
| Timeout paiement 5 min | **OUI** — annulation auto si paiement non confirmé                                                     |
| Numérotation factures | **OUI** — séquentielle `DD-YYYYMM-XXXX` (obligation comptable)                                         |
| CinetPay Transfer API | **Accès demandé, pas encore reçu** — on fait quand meme la Phase 3 il ne ma,quera qu'à mettre les clés |

---

## Proposed Changes

### Phase 1 — SMS OTP & Compte simplifié (3-4 jours)

*Le schéma est prêt (`otpPhone`, `accountType`, `ageConfirmed` existent). Il manque l'envoi SMS et le flux Flutter.*

---

#### Backend — Cloud Code

##### [MODIFY] [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js)

**Nouvelle fonction `sendSmsVerificationCode`** :
- Réutiliser la logique existante de `sendVerificationCode` (qui fait ça par email)
- Envoyer via Africa's Talking API (SDK Node.js `africastalking`)
- Stocker dans la classe `VerificationCode` existante (champs `phone`, `purpose`, `attempts`, `blockedUntil` sont déjà là)
- Rate limit : 3 envois max par 10 min (logique `blockedUntil` existe déjà)

**Nouvelle fonction `verifySmsCode`** :
- Même logique que `verifyCode` existant, mais cherche par `phone` au lieu de `email`

**Nouvelle fonction `loginByPhone`** :
- Login par phone + OTP (alternative au `loginUser` par email/password)
- Si premier login → créer le user en mode simplifié (`accountType: 'simplified'`)
- Retourne un session token Parse

**Nouvelle fonction `upgradeSimplifiedAccount`** :
- Ajouter email + mot de passe à un compte simplifié existant
- Même user, historique conservé

**Modifier `beforeSave _User`** :
- Rendre `email` et `password` optionnels pour les comptes simplifiés
- Vérifier `ageConfirmed = true` à l'inscription

##### [NEW] [api/send-sms.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/send-sms.js)
- Endpoint utilitaire d'envoi SMS via Africa's Talking
- Appelé par le Cloud Code via HTTP fetch
- Config : `AFRICASTALKING_API_KEY`, `AFRICASTALKING_USERNAME`, `AFRICASTALKING_SENDER_ID`

##### [MODIFY] [.env.example](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/.env.example)
- Ajouter : `AFRICASTALKING_API_KEY`, `AFRICASTALKING_USERNAME`, `AFRICASTALKING_SENDER_ID`

##### [MODIFY] [package.json](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/package.json)
- Ajouter dépendance : `africastalking`

---

#### Flutter App

##### [MODIFY] [lib/screens/auth/](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/auth/)
- Ajouter onglet "Connexion par téléphone" sur l'écran login
- Écran saisie numéro (+243...) → envoi OTP SMS
- Écran saisie code OTP (6 chiffres, timer 15 min)
- Case à cocher "Je confirme avoir 18 ans ou plus" (`ageConfirmed: true`)

##### [MODIFY] [lib/screens/onboarding/](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/onboarding/)
- Permettre onboarding sans email (téléphone seul)
- Proposer upgrade vers compte complet plus tard

##### [MODIFY] [lib/models/user.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/models/user.dart)
- S'assurer que `phone`, `otpPhone`, `accountType`, `ageConfirmed` sont exposés dans le modèle Hive

---

### Phase 2 — Litiges + Suppressions (2-3 jours)

*Le schéma `Report` existe. Il faut les Cloud Functions + UI Flutter. On supprime aussi le paiement à la livraison et les fichiers Fedapay.*

---

#### Backend — Cloud Code

##### [MODIFY] [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js)

**`createReport`** :
- Reçoit : `orderId` (via `targetID`), `targetType` (restaurant | driver), `reason` (missing_item | not_delivered | bad_quality | other), `details`, `photoUrls[]`
- Validation : commande livrée il y a < 48h
- Photo obligatoire pour `missing_item` / `not_delivered`
- Crée l'enregistrement `Report` (status: `open`)
- Push notification au restaurateur/livreur concerné + admins

**`getReports`** (admin) :
- Liste les litiges avec filtres (status, type, date, restaurant)
- Pagination
- Enrichir avec info commande + client + restaurant

**`getMyReports`** (client) :
- Liste les litiges du client connecté

**`resolveReport`** (admin) :
- Reçoit : `reportId`, `resolution` (favor_client | favor_restaurant | rejected), `notes`, `refundAmount`
- Si remboursement → flag pour remboursement (en attendant CinetPay Transfer Phase 3)
- Met à jour status → `resolved`
- Push notification au client + audit log

**`checkDisputeThresholds`** :
- 3 litiges validés en 30j → avertissement automatique (push)
- 5 litiges validés en 30j → suspension automatique
- Seuils paramétrables

---

#### Suppressions

##### [DELETE] [api/fedapay-initiate.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/fedapay-initiate.js)
##### [DELETE] [api/fedapay-webhook.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/fedapay-webhook.js)

##### [MODIFY] [lib/screens/cart/cart.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/cart/cart.dart)
- **Supprimer l'option "Paiement à la livraison"** — ne garder que CinetPay
- Supprimer toute référence à Fedapay

##### [MODIFY] Nettoyer toute référence Fedapay dans le code Flutter (modèles, services, configs)

---

#### Flutter App

##### [NEW] `lib/screens/disputes/open_dispute.dart`
- Formulaire : type de problème (dropdown), description, upload photo (caméra/galerie)
- Accessible depuis [commande_detail.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/orders/commande_detail.dart) (bouton "Signaler un problème")
- Délai : 24-48h après livraison

##### [NEW] `lib/screens/disputes/my_disputes.dart`
- Liste des litiges du client avec statut et résolution

##### [MODIFY] [admin_dashboard.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/admin/admin_dashboard.dart)
- Ajouter panneau "Litiges" : file d'attente, vue détaillée, boutons résolution

##### [NEW] `lib/models/dispute.dart`
- Modèle mappé sur la classe `Report` existante

---

### Phase 3 — CinetPay Transfer (vrais versements) (2-3 jours)

---

#### Backend

##### [NEW] [api/cinetpay-transfer.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/cinetpay-transfer.js)
- Appel à l'API CinetPay Transfer (disbursement Mobile Money)
- Reçoit : `recipient_phone`, `amount`, `currency`, `reference`
- Gestion erreurs : numéro invalide, solde plateforme insuffisant, opérateur down
- Retourne le statut du transfert

##### [MODIFY] [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js)

**Modifier `processSinglePayout`** :
- Remplacer le placeholder actuel par un appel réel à `api/cinetpay-transfer.js`
- Gérer les cas d'erreur (retry, notification admin si échec)
- Mettre à jour `PaiementRestaurateur.status` selon le résultat réel

**Modifier `processDelivererPayout`** :
- Même chose pour les versements livreurs via `LivreurPaiement`

##### [MODIFY] [.env.example](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/.env.example)
- Ajouter : `CINETPAY_TRANSFER_API_KEY` (si différent de la clé de collecte)

---

#### Flutter Admin

##### [MODIFY] [admin_dashboard.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/admin/admin_dashboard.dart)
- Ajouter section "Versements" : liste payouts (restaurateurs + livreurs), statuts, montants
- Bouton "Déclencher versement manuel" en cas d'échec

---

### Phase 4 — Preuve de livraison & notation livreur (2-3 jours)

---

#### Backend — Cloud Code

##### [MODIFY] [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js)

**`submitDeliveryProof`** :
- Reçoit : `orderId`, `photoUrl` (via Cloudinary), `latitude`, `longitude`
- Validation : commande en statut "en livraison", livreur = livreur assigné
- Stocke `deliveryProofUrl`, `deliveryProofLat`, `deliveryProofLng`, `deliveryProofAt` sur la `Commande`
- Passe commande en `livrée` uniquement après upload photo

**`generateDeliveryCode`** :
- Commandes > seuil paramétrable → code 4 chiffres envoyé au client par push
- Le livreur doit saisir le code pour confirmer

**Ajouter champs sur classe `Commande`** :
- `deliveryProofUrl`, `deliveryProofLat`, `deliveryProofLng`, `deliveryProofAt`, `deliveryCode`

---

#### Flutter App

##### [MODIFY] [home_livreur.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/delivery/home_livreur.dart)
- Bouton "Confirmer livraison" → ouvre la **caméra** (pas galerie)
- Photo horodatée et géolocalisée automatiquement
- Si `deliveryCode` existe → champ saisie 4 chiffres avant confirmation

##### [MODIFY] [commande_detail.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/orders/commande_detail.dart)
- Ajouter notation livreur (séparée de la notation restaurant) — `addComment` avec `targetType=3` existe déjà côté backend
- Ajouter option pourboire (montant libre → champ `tipAmount` existe déjà)

##### [MODIFY] [commande_tracking.dart](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/lib/screens/orders/commande_tracking.dart)
- Afficher note moyenne du livreur (backend `recalculateNote` pour `targetType=3` existe déjà)

---

### Phase 5 — Finitions & CRON jobs (2-3 jours)

---

#### 5.1 Timeout paiement 5 minutes

##### [MODIFY] [cloud/main.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/cloud/main.js)

**`checkPaymentTimeout`** (Parse.Cloud.job) :
- Commandes en `en attente de paiement` depuis > 5 min → annulation auto
- Push notification client avec lien pour réessayer
- Jamais de transmission au restaurateur sans paiement

---

#### 5.2 Numérotation séquentielle des factures

##### [MODIFY] [api/generate-invoice.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/generate-invoice.js)
- Remplacer `DD-YYYYMMDD-random5` par `DD-YYYYMM-XXXX` séquentiel
- Compteur atomique en base (Back4App `InvoiceCounter` class) — jamais de trou dans la numérotation

##### [MODIFY] Cloud function `generateOrderInvoice` dans main.js
- Même changement de numérotation

---

#### 5.3 Badge Hygiène

**`toggleHygieneBadge`** (admin) :
- Active/désactive badge sur un restaurateur (`isHygieneCertified`)
- Log dans audit

##### [MODIFY] Flutter — cartes restaurant
- Afficher badge Hygiène 🎓 à côté du badge PRO

---

#### 5.4 Re-vérification périodique

**`checkVerificationExpiry`** (Parse.Cloud.job) :
- `lastVerificationDate` > 6 mois → notification re-vérification
- Nouveaux < 3 mois : re-vérification à 30 jours
- Pas de réponse 7j → suspension préventive

---

#### 5.5 Taux d'acceptation livreur

**`trackDriverAcceptance`** :
- Log chaque accept/reject
- Taux sur 7 jours glissants : < 70% → avertissement, < 50% → suspension

**Modifier `assignLivreur`** :
- Quartier + montant estimé AVANT acceptation
- Adresse complète APRÈS ramassage seulement

---

#### 5.6 Health check CinetPay

##### [NEW] [api/health-cinetpay.js](file:///Users/rodicaadigbonon/AndroidStudioProjects/dios_delices/dios-delices-backend/api/health-cinetpay.js)
- CRON 5 min : ping API CinetPay
- Si down → log + SMS fondateur (via Africa's Talking)
- Flag `paymentAvailable` consultable par l'app

---

#### 5.7 Anonymisation CRON

**Compléter `cleanupDeletedUsers`** :
- Anonymiser (nom → "Utilisateur supprimé", téléphone → null) au lieu de supprimer physiquement
- Photos d'identification > 1 an → supprimer de Cloudinary
- Factures conservées 5 ans

---

#### 5.8 SMS fallback pour notifications critiques

**Modifier les fonctions de notification existantes** :
- Pour chaque notification critique (statut commande, versement, litige) :
  - Push d'abord
  - Si compte simplifié (pas d'app installée) → SMS via Africa's Talking
- Pour le tracking : lien SMS vers page web de suivi

---

## Récapitulatif final

### Fichiers à créer

| Fichier | Phase |
|---------|-------|
| `api/send-sms.js` | Phase 1 |
| `lib/screens/disputes/open_dispute.dart` | Phase 2 |
| `lib/screens/disputes/my_disputes.dart` | Phase 2 |
| `lib/models/dispute.dart` | Phase 2 |
| `api/cinetpay-transfer.js` | Phase 3 ⚠️ |
| `api/health-cinetpay.js` | Phase 5 |

### Fichiers à modifier

| Fichier | Phases |
|---------|--------|
| `cloud/main.js` | 1, 2, 3, 4, 5 |
| `lib/screens/auth/` | 1 |
| `lib/screens/onboarding/` | 1 |
| `lib/models/user.dart` | 1 |
| `lib/screens/cart/cart.dart` | 2 (supprimer paiement livraison) |
| `lib/screens/orders/commande_detail.dart` | 2, 4 |
| `lib/screens/admin/admin_dashboard.dart` | 2, 3 |
| `lib/screens/delivery/home_livreur.dart` | 4 |
| `lib/screens/orders/commande_tracking.dart` | 4 |
| `api/generate-invoice.js` | 5 |
| `.env.example` | 1, 3 |
| `package.json` | 1 |

### Fichiers à supprimer

| Fichier | Phase |
|---------|-------|
| `api/fedapay-initiate.js` | Phase 2 |
| `api/fedapay-webhook.js` | Phase 2 |

---

## Estimation effort

| Phase | Effort | Bloquant ? |
|-------|--------|------------|
| Phase 1 — SMS OTP & Compte simplifié | 3-4 jours | Créer compte Africa's Talking |
| Phase 2 — Litiges + suppressions | 2-3 jours | ✅ Rien de bloquant |
| Phase 3 — CinetPay Transfer | 2-3 jours | |
| Phase 4 — Preuve livraison & notation | 2-3 jours | ✅ Rien de bloquant |
| Phase 5 — Finitions & CRON | 2-3 jours | Phase 1 (Africa's Talking pour SMS fallback) |
| **Total** | **≈ 11-16 jours** | |

---

## Verification Plan

### Automated Tests
- Tests Cloud Functions : `sendSmsVerificationCode`, `createReport`, `resolveReport`, `submitDeliveryProof`, `checkPaymentTimeout`
- Test intégration : flux CinetPay Transfer sandbox (quand disponible)
- Test timeout : commande non payée > 5 min → annulation auto

### Manual Verification (7 scénarios E2E)
1. Commande complète : panier → paiement CinetPay → livreur → livraison (photo preuve) → facture séquentielle
2. Annulation avant acceptation restaurant → remboursement intégral
3. Annulation par restaurateur → remboursement auto + alerte admin
4. Litige avec photo → résolution admin → remboursement
5. Versement hebdomadaire restaurateur (réel via CinetPay Transfer — Phase 3)
6. Onboarding restaurateur → validation admin → activation
7. Onboarding livreur → validation admin → première course
8. **Nouveau** : Inscription par téléphone OTP → commande → suivi par SMS

Tous testés avec données Lubumbashi en sandbox CinetPay + Africa's Talking sandbox.
