-- Execute after the initial Prisma schema has created the legacy tables.
-- This migration is intentionally additive so legacy Parse data remains intact.
CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE "cities"
  ADD COLUMN IF NOT EXISTS "country_code" TEXT NOT NULL DEFAULT 'CD',
  ADD COLUMN IF NOT EXISTS "boundary" geometry(MultiPolygon, 4326),
  ADD COLUMN IF NOT EXISTS "delivery_enabled" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "addresses"
  ADD COLUMN IF NOT EXISTS "city_id" INTEGER,
  ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS "location_source" TEXT,
  ADD COLUMN IF NOT EXISTS "location_updated_at" TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "nominatim_place_id" TEXT;

ALTER TABLE "restaurants"
  ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS "location_updated_at" TIMESTAMPTZ;

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "courier_status" TEXT,
  ADD COLUMN IF NOT EXISTS "location" geography(Point, 4326),
  ADD COLUMN IF NOT EXISTS "location_updated_at" TIMESTAMPTZ;

ALTER TABLE "delivery_zones"
  ADD COLUMN IF NOT EXISTS "boundary" geometry(MultiPolygon, 4326);

ALTER TABLE "delivery_configs"
  ADD COLUMN IF NOT EXISTS "city_id" INTEGER,
  ADD COLUMN IF NOT EXISTS "included_distance_km" DECIMAL(10, 3),
  ADD COLUMN IF NOT EXISTS "max_distance_km" DECIMAL(10, 3),
  ADD COLUMN IF NOT EXISTS "fuel_price_per_litre" DECIMAL(14, 2),
  ADD COLUMN IF NOT EXISTS "fuel_surcharge" DECIMAL(14, 2),
  ADD COLUMN IF NOT EXISTS "demand_multiplier" DECIMAL(6, 3) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS "weather_multiplier" DECIMAL(6, 3) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS "rounding_increment" DECIMAL(14, 2) NOT NULL DEFAULT 50;

ALTER TABLE "orders"
  ADD COLUMN IF NOT EXISTS "delivery_distance_km" DECIMAL(10, 3),
  ADD COLUMN IF NOT EXISTS "delivery_quote_snapshot" JSONB,
  ADD COLUMN IF NOT EXISTS "delivery_address_snapshot" JSONB,
  ADD COLUMN IF NOT EXISTS "pickup_snapshot" JSONB;

CREATE TABLE IF NOT EXISTS "deliveries" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "delivery_id" UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  "commande_id" INTEGER NOT NULL UNIQUE,
  "city_id" INTEGER NOT NULL,
  "restaurant_id" INTEGER,
  "livreur_id" INTEGER,
  "status" TEXT NOT NULL DEFAULT 'SEARCHING',
  "dispatch_attempt" INTEGER NOT NULL DEFAULT 0,
  "pickup_latitude" DOUBLE PRECISION,
  "pickup_longitude" DOUBLE PRECISION,
  "delivery_latitude" DOUBLE PRECISION,
  "delivery_longitude" DOUBLE PRECISION,
  "quoted_distance_km" DECIMAL(10, 3),
  "accepted_at" TIMESTAMPTZ,
  "picked_up_at" TIMESTAMPTZ,
  "delivered_at" TIMESTAMPTZ,
  "cancelled_at" TIMESTAMPTZ,
  "cancellation_reason" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "delivery_offers" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "delivery_id" UUID NOT NULL,
  "livreur_id" INTEGER NOT NULL,
  "rank" INTEGER NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "expires_at" TIMESTAMPTZ,
  "responded_at" TIMESTAMPTZ,
  "distance_to_pickup_km" DECIMAL(10, 3),
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("delivery_id", "livreur_id")
);

CREATE TABLE IF NOT EXISTS "courier_locations" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "livreur_id" INTEGER NOT NULL,
  "city_id" INTEGER,
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "location" geography(Point, 4326),
  "accuracy_m" DOUBLE PRECISION,
  "recorded_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "mobile_money_accounts" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" INTEGER NOT NULL,
  "operator" TEXT NOT NULL,
  "phone_e164" TEXT NOT NULL,
  "label" TEXT,
  "verified" BOOLEAN NOT NULL DEFAULT false,
  "is_default" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("user_id", "operator", "phone_e164")
);

CREATE TABLE IF NOT EXISTS "wallet_accounts" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" INTEGER NOT NULL UNIQUE,
  "currency" TEXT NOT NULL DEFAULT 'CDF',
  "status" TEXT NOT NULL DEFAULT 'DISABLED',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "wallet_ledger_entries" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "wallet_account_id" UUID NOT NULL,
  "direction" TEXT NOT NULL,
  "amount" DECIMAL(14, 2) NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'CDF',
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "reference_type" TEXT NOT NULL,
  "reference_id" TEXT NOT NULL,
  "description" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "posted_at" TIMESTAMPTZ,
  UNIQUE ("wallet_account_id", "reference_type", "reference_id", "direction")
);

CREATE TABLE IF NOT EXISTS "tips" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "commande_id" INTEGER NOT NULL,
  "delivery_id" UUID,
  "customer_id" INTEGER NOT NULL,
  "livreur_id" INTEGER NOT NULL,
  "amount" DECIMAL(14, 2) NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'CDF',
  "payment_method" TEXT,
  "transaction_id" TEXT UNIQUE,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  "paid_at" TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS "payment_webhook_events" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "provider" TEXT NOT NULL,
  "external_event_id" TEXT,
  "transaction_id" TEXT,
  "payload" JSONB NOT NULL,
  "signature_valid" BOOLEAN NOT NULL,
  "processed_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("provider", "external_event_id")
);

CREATE INDEX IF NOT EXISTS "cities_boundary_gix" ON "cities" USING GIST ("boundary");
CREATE INDEX IF NOT EXISTS "addresses_location_gix" ON "addresses" USING GIST ("location");
CREATE INDEX IF NOT EXISTS "restaurants_location_gix" ON "restaurants" USING GIST ("location");
CREATE INDEX IF NOT EXISTS "users_location_gix" ON "users" USING GIST ("location");
CREATE INDEX IF NOT EXISTS "delivery_zones_boundary_gix" ON "delivery_zones" USING GIST ("boundary");
CREATE INDEX IF NOT EXISTS "courier_locations_location_gix" ON "courier_locations" USING GIST ("location");
CREATE INDEX IF NOT EXISTS "delivery_status_city_idx" ON "deliveries" ("city_id", "status");
CREATE INDEX IF NOT EXISTS "delivery_offer_deliverer_idx" ON "delivery_offers" ("livreur_id", "status");
CREATE INDEX IF NOT EXISTS "courier_location_recent_idx" ON "courier_locations" ("city_id", "recorded_at" DESC);
CREATE INDEX IF NOT EXISTS "payment_webhook_transaction_idx" ON "payment_webhook_events" ("transaction_id");
