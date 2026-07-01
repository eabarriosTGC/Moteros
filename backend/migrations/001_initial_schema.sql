-- 001_initial_schema.sql
-- Stack: PostgreSQL 15 + PostGIS 3.3

CREATE EXTENSION IF NOT EXISTS postgis;

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('aspirant', 'member', 'admin', 'ally');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE place_category AS ENUM (
        'taller','restaurante','hotel','mirador','moto_posada',
        'grua','reposteria','evento','otro'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE membership_plan AS ENUM ('basic', 'premium');
EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(150),
    profile_image   VARCHAR(550),
    role            user_role DEFAULT 'aspirant',
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       VARCHAR(512) UNIQUE NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS places (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    category    place_category,
    address     VARCHAR(350),
    city        VARCHAR(100),
    department  VARCHAR(100),
    geom        GEOMETRY(Point, 4326),
    qr_token    VARCHAR(255) UNIQUE NOT NULL,
    created_by  INT REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_places_geom ON places USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);
CREATE INDEX IF NOT EXISTS idx_places_qr_token ON places(qr_token);

CREATE TABLE IF NOT EXISTS visits (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id    INT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    verified_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_url VARCHAR(550),
    is_verified BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_user_place_day UNIQUE (user_id, place_id, DATE_TRUNC('day', verified_at))
);

CREATE INDEX IF NOT EXISTS idx_visits_user ON visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_place ON visits(place_id);

CREATE TABLE IF NOT EXISTS memberships (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan        membership_plan DEFAULT 'basic',
    payment_ref VARCHAR(255),
    start_date  TIMESTAMPTZ NOT NULL,
    end_date    TIMESTAMPTZ NOT NULL,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships(user_id);

CREATE OR REPLACE FUNCTION is_within_distance(
    p_geom   GEOMETRY,
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
    SELECT ST_DWithin(
        p_geom::geography,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
        p_meters
    );
$$;
