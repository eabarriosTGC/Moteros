-- MIGRATION 023: route_cache table for GraphHopper proxy
-- ============================================================
-- Caches route results with a 24-hour TTL to reduce GraphHopper
-- load for identical or nearby route queries.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS route_cache (
    id          BIGSERIAL PRIMARY KEY,
    cache_key   TEXT NOT NULL UNIQUE,
    origin      JSONB NOT NULL,
    destination JSONB NOT NULL,
    profile     TEXT NOT NULL DEFAULT 'motorcycle',
    result      JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_route_cache_key ON route_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_route_cache_created ON route_cache(created_at);

COMMIT;
