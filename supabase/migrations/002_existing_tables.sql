-- MIGRATION 002: TABLAS EXISTENTES (Migradas)
-- ============================================================
-- Tablas mantenidas del schema anterior
-- ============================================================

BEGIN;

-- users (1:1 con auth.users)
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       VARCHAR(150),
    username        VARCHAR(50) UNIQUE,
    profile_image   VARCHAR(550),
    bio             TEXT,
    membership_tier TEXT DEFAULT 'basic'
                    CHECK (membership_tier IN ('basic', 'premium')),
    active_title    TEXT,                                -- título cosmético equipado
    emergency_contact_name  TEXT,
    emergency_contact_phone TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- user_follows (amigos)
CREATE TABLE IF NOT EXISTS user_follows (
    id              BIGSERIAL PRIMARY KEY,
    follower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, followed_id),
    CHECK (follower_id != followed_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed ON user_follows(followed_id);

-- memberships
CREATE TABLE IF NOT EXISTS memberships (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan            TEXT NOT NULL DEFAULT 'basic'
                    CHECK (plan IN ('basic', 'premium')),
    payment_ref     VARCHAR(255),
    start_date      TIMESTAMPTZ NOT NULL,
    end_date        TIMESTAMPTZ NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships(user_id);

-- places
CREATE TABLE IF NOT EXISTS places (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    address         VARCHAR(350),
    city            VARCHAR(100),
    department      VARCHAR(100),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    qr_token        VARCHAR(255) UNIQUE NOT NULL,
    image_url       VARCHAR(550),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_places_location ON places(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);
CREATE INDEX IF NOT EXISTS idx_places_qr_token ON places(qr_token);
CREATE INDEX IF NOT EXISTS idx_places_city_dept ON places(city, department);

-- get_nearby_places: búsqueda por proximidad (sin PostGIS)
CREATE OR REPLACE FUNCTION get_nearby_places(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 5000
) RETURNS TABLE(
    id BIGINT, name VARCHAR, category TEXT, address VARCHAR,
    city VARCHAR, department VARCHAR,
    latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION, image_url VARCHAR, qr_token VARCHAR
)
LANGUAGE sql STABLE
AS $$
    WITH bounding_box AS (
        SELECT
            p_lat - (p_radius_meters / 111320.0) AS min_lat,
            p_lat + (p_radius_meters / 111320.0) AS max_lat,
            p_lng - (p_radius_meters / (111320.0 * COS(RADIANS(p_lat)))) AS min_lng,
            p_lng + (p_radius_meters / (111320.0 * COS(RADIANS(p_lat)))) AS max_lng
    )
    SELECT
        p.id, p.name, p.category, p.address, p.city, p.department,
        p.latitude, p.longitude,
        haversine_distance(p_lat, p_lng, p.latitude, p.longitude) AS distance_meters,
        p.image_url, p.qr_token
    FROM places p, bounding_box b
    WHERE p.latitude BETWEEN b.min_lat AND b.max_lat
      AND p.longitude BETWEEN b.min_lng AND b.max_lng
      AND haversine_distance(p_lat, p_lng, p.latitude, p.longitude) <= p_radius_meters
    ORDER BY distance_meters;
$$;

-- visits
CREATE TABLE IF NOT EXISTS visits (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    verified_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_url    VARCHAR(550),
    is_verified     BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_visits_user ON visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_place ON visits(place_id);
-- Nota: validación de único por día se hace en Edge Function validate_checkpoint

-- allies (refugios — arregla bug de tabla faltante)
CREATE TABLE IF NOT EXISTS allies (
    id              BIGSERIAL PRIMARY KEY,
    business_name   VARCHAR(255) NOT NULL,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    description     TEXT,
    benefit         TEXT,
    address         VARCHAR(350),
    phone           VARCHAR(50),
    website         VARCHAR(255),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    image_url       VARCHAR(550),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_allies_location ON allies(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_allies_category ON allies(category);

-- evidence_photos
CREATE TABLE IF NOT EXISTS evidence_photos (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    accuracy_meters DOUBLE PRECISION,
    verified        BOOLEAN DEFAULT FALSE,
    distance_meters DOUBLE PRECISION,
    points_awarded  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_evidence_photos_user ON evidence_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_evidence_photos_place ON evidence_photos(place_id);

-- saved_routes (unifica /routes y /tracks)
CREATE TABLE IF NOT EXISTS saved_routes (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(255),
    total_distance_m DOUBLE PRECISION DEFAULT 0,
    duration_seconds INT DEFAULT 0,
    avg_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    max_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    points_count    INT DEFAULT 0,
    polyline_json   TEXT,
    start_lat       DOUBLE PRECISION,
    start_lng       DOUBLE PRECISION,
    end_lat         DOUBLE PRECISION,
    end_lng         DOUBLE PRECISION,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_saved_routes_user ON saved_routes(user_id);

-- road_alerts
CREATE TABLE IF NOT EXISTS road_alerts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    type            VARCHAR(50) NOT NULL,
    title           VARCHAR(255),
    description     TEXT,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    severity        VARCHAR(20) DEFAULT 'info'
                    CHECK (severity IN ('info', 'warning', 'danger')),
    active          BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    upvotes         INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_road_alerts_location ON road_alerts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_road_alerts_active ON road_alerts(active);

-- challenges (logros / battle pass legacy)
CREATE TABLE IF NOT EXISTS challenges (
    id              BIGSERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    icon            VARCHAR(50) DEFAULT '🏁',
    ruta            VARCHAR(255),
    sort_order      INT DEFAULT 0
);

-- user_challenges
CREATE TABLE IF NOT EXISTS user_challenges (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id    BIGINT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    completed       BOOLEAN DEFAULT FALSE,
    submitted_at    TIMESTAMPTZ,
    UNIQUE(user_id, challenge_id)
);

-- patches
CREATE TABLE IF NOT EXISTS patches (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    icon            VARCHAR(50) DEFAULT '🏍️',
    place           VARCHAR(255),
    requirement     TEXT
);

-- user_patches
CREATE TABLE IF NOT EXISTS user_patches (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    patch_id        BIGINT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
    earned          BOOLEAN DEFAULT FALSE,
    earned_at       TIMESTAMPTZ,
    UNIQUE(user_id, patch_id)
);

-- chat_messages (1:1 legacy)
CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_chat_conversation ON chat_messages(conversation_id, created_at);

-- conversation_participants
CREATE TABLE IF NOT EXISTS conversation_participants (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(conversation_id, user_id)
);

COMMIT;
