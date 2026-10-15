-- Dossier livreur : véhicule, plaque et permis de conduire.
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "vehicle_type" TEXT;
ALTER TABLE "identities" ADD COLUMN IF NOT EXISTS "license_url" TEXT;
ALTER TABLE "identities" ADD COLUMN IF NOT EXISTS "vehicle_type" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "vehicle_plate" TEXT;
ALTER TABLE "identities" ADD COLUMN IF NOT EXISTS "vehicle_plate" TEXT;
