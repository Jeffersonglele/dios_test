# Démarrage local — Dios Delices backend

Le projet n’a encore aucune donnée : ces étapes créent seulement PostgreSQL,
PostGIS et les tables vides nécessaires au développement local.

## 1. Variables locales

Copier `.env.example` en `.env`. Pour la configuration Docker proposée, garder
les valeurs cohérentes suivantes :

```env
POSTGRES_DB=dios_delices
POSTGRES_USER=postgres
POSTGRES_PASSWORD=change-me
POSTGRES_PORT=5432
DATABASE_URL=postgresql://postgres:change-me@localhost:5432/dios_delices?schema=public
```

Remplacer impérativement `JWT_SECRET` par une longue valeur privée. Ne jamais
commiter `.env`.

Pour générer une valeur locale robuste avec Node.js :

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Copier le résultat dans `JWT_SECRET` avant de lancer l’API. En développement,
le serveur démarre avec un avertissement si cette variable manque, mais les
routes d’authentification resteront inutilisables.

Sur Render, `RENDER_EXTERNAL_URL` est détectée automatiquement pour autoriser
Swagger et les appels provenant de l’URL publique de l’API. Les URLs du
frontend doivent quand même être ajoutées à `CORS_ORIGINS`.

Pour activer Nyole sur Render, renseigner dans l’environnement du service :

```env
NYOLE_MODE=test
NYOLE_API_BASE_URL=https://app.nyole.com/api
NYOLE_TEST_SECRET_KEY=af_test_sec_...
NYOLE_SUCCESS_URL=https://dios-delices.onrender.com/api/v1/payments/nyole/return?status=success
NYOLE_CANCEL_URL=https://dios-delices.onrender.com/api/v1/payments/nyole/return?status=cancelled
```

Puis configurer dans Nyole l’adresse webhook suivante :
`https://dios-delices.onrender.com/api/v1/payments/nyole/webhook`.
La clé `NYOLE_LIVE_SECRET_KEY` et `NYOLE_MODE=live` ne sont nécessaires
qu’au passage en production réelle.

## 2. Créer la base et les tables

Avec Docker Desktop démarré :

```powershell
npm run db:up
npm run prisma:migrate:dev
npm run prisma:generate
npm run prisma:status
```

La première migration installe PostGIS avant les colonnes géographiques. La
seconde ajoute les index PostGIS et reste sans danger sur cette base vierge.

## 3. Lancer l’API et vérifier

```powershell
npm run dev
```

Puis ouvrir `http://localhost:3000/api-docs` et tester `/health`.

Les vérifications rapides peuvent être lancées sans base de données :

```powershell
npm test
```

## 4. Activer une ville sans données fictives

Avant de tester une commande livrée, un administrateur doit réellement créer :

1. une ville RDC avec `countryCode: "CD"` et `deliveryEnabled: true` ;
2. sa frontière officielle ou validée au format GeoJSON via
   `PATCH /api/v1/cities/:cityId/boundary` ;
3. une configuration de livraison pour cette ville (`DeliveryConfig`) en CDF.

Sans frontière validée, la position est volontairement refusée : le système ne
doit jamais deviner la ville d’un client à partir d’un simple texte Nominatim.
