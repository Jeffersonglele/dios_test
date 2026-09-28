# Paiements Dios Délices avec Nyole

Le backend utilise Nyole comme page de paiement hébergée pour les paiements
en ligne. Les secrets Nyole restent exclusivement côté backend. Le paiement à
la remise (`CASH`) reste indépendant de Nyole.

## Configuration

```env
NYOLE_MODE=test
NYOLE_API_BASE_URL=https://app.nyole.com/api
NYOLE_TEST_SECRET_KEY=af_test_sec_...
NYOLE_LIVE_SECRET_KEY=af_live_sec_...
NYOLE_SUCCESS_URL=https://dios-delices.onrender.com/api/v1/payments/nyole/return?status=success
NYOLE_CANCEL_URL=https://dios-delices.onrender.com/api/v1/payments/nyole/return?status=cancelled
```

`test` est le mode recommandé pendant l’intégration. Les clés `af_test_*`
isolent les paiements et permettent de simuler leur résultat. Le mode `live`
nécessite une clé `af_live_sec_*` et ne doit être activé qu’après validation.

## Parcours d’une commande

1. L’application crée une commande avec `paymentMethod: "NYOLE"`.
2. Dios Délices crée une transaction locale `nyole` et appelle
   `POST /v1/checkout/sessions` avec une clé secrète.
3. L’API retourne `paymentUrl`; l’application ouvre cette URL.
4. Nyole envoie un webhook signé vers
   `POST /api/v1/payments/nyole/webhook`.
5. Le backend vérifie la signature, interroge
   `GET /v1/checkout/sessions/{id}/status`, contrôle le montant et la devise,
   puis marque la transaction et la commande comme payées.

La redirection `success_url` n’est jamais une preuve de paiement. Seul le
statut vérifié côté serveur ou le webhook validé peut confirmer la commande.

## Routes Dios Délices

- `POST /api/v1/payments/nyole/initialize` : créer une session pour une commande ;
- `GET /api/v1/payments/nyole/:transactionId` : consulter une transaction ;
- `POST /api/v1/payments/nyole/webhook` : recevoir les événements Nyole ;
- `GET /api/v1/payments/nyole/return` : page de retour utilisateur ;
- `POST /api/v1/payments/nyole/test/:transactionId/confirm` : simuler un résultat
  en mode test uniquement ;
- `POST /api/v1/payments/nyole/tips/initialize` : créer un pourboire après
  livraison.

## Signature des webhooks

Nyole envoie :

- `X-Afriflow-Timestamp` ;
- `X-Afriflow-Signature: t=<timestamp>,v1=<hmac>` ;
- `X-Afriflow-Delivery` pour l’idempotence.

La signature est calculée sur `timestamp + "." + corps_brut` avec la clé
secrète correspondant à `livemode`. Le backend conserve chaque événement dans
`payment_webhook_events`, refuse les signatures âgées de plus de cinq minutes
et traite plusieurs livraisons du même événement de manière idempotente.

## Espèces et portefeuille

Une commande `CASH` crée une transaction locale et reste confirmée par le
livreur selon le parcours de livraison. Le portefeuille Dios reste désactivé :
aucun solde ne doit être crédité sans décision réglementaire et implémentation
dédiée.
