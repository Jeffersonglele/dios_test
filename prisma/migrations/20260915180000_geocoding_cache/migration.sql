-- Cache persistent for low-volume OpenStreetMap/Nominatim geocoding in RDC.
-- The cache stores public address responses, never a user's live tracking history.
CREATE TABLE IF NOT EXISTS "geocoding_cache" (
    "id" UUID NOT NULL,
    "cache_key" TEXT NOT NULL,
    "provider" TEXT NOT NULL DEFAULT 'nominatim',
    "query" JSONB NOT NULL,
    "display_name" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "raw" JSONB NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "geocoding_cache_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "geocoding_cache_cache_key_key" ON "geocoding_cache"("cache_key");
CREATE INDEX IF NOT EXISTS "geocoding_cache_expires_at_idx" ON "geocoding_cache"("expires_at");
