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

## 4. Activer une ville sans données fictives

Avant de tester une commande livrée, un administrateur doit réellement créer :

1. une ville RDC avec `countryCode: "CD"` et `deliveryEnabled: true` ;
2. sa frontière officielle ou validée au format GeoJSON via
   `PATCH /api/v1/cities/:cityId/boundary` ;
3. une configuration de livraison pour cette ville (`DeliveryConfig`) en CDF.

Sans frontière validée, la position est volontairement refusée : le système ne
doit jamais deviner la ville d’un client à partir d’un simple texte Nominatim.
