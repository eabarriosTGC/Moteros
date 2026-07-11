# AsfaltoClub: Battle Ride — Diseño Técnico Detallado

> **Documento:** Implementación completa lista para ejecutar
> **Basado en:** `SUPABASE_RAIDS_SDD.md` + `SUPABASE_RAIDS_SPECS.md`
> **Stack:** Supabase (Auth + Postgres + Realtime + Storage + Edge Functions) + LiveKit + Flutter
> **Fecha:** Julio 2026

---

## Índice

1. [SQL Schema Completo (Ejecutable)](#1-sql-schema-completo)
2. [Triggers y Funciones](#2-triggers-y-funciones)
3. [Seed Data](#3-seed-data)
4. [RLS Policies](#4-rls-policies)
5. [Storage Buckets + Policies](#5-storage-buckets--policies)
6. [Edge Functions TypeScript](#6-edge-functions-typescript)
7. [Realtime Channels](#7-realtime-channels)
8. [LiveKit Integration](#8-livekit-integration)
9. [Flutter Architecture](#9-flutter-architecture)
10. [Offline Cache Strategy](#10-offline-cache-strategy)
11. [Archivos a Crear/Eliminar](#11-archivos-a-creareliminar)

---

# 1. SQL Schema Completo

> **Ejecutar en Supabase SQL Editor en orden.**  
> No usa ENUMs (usa TEXT + CHECK). No usa PostGIS (usa DOUBLE PRECISION + háversine SQL).

## 1.1 Funciones Háversine y Progresión

```sql
-- ============================================================
-- MIGRATION 001: FUNCIONES BASE
-- ============================================================

-- Háversine: distancia en metros entre dos coordenadas
CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT 6371000.0 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
        + COS(RADIANS(lat1)) * COS(RADIANS(lat2))
        * POWER(SIN(RADIANS(lng2 - lng1) / 2), 2)
    ));
$$;

-- Helper: está dentro de N metros?
CREATE OR REPLACE FUNCTION is_within_distance(
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    q_lat    DOUBLE PRECISION,
    q_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT haversine_distance(p_lat, p_lng, q_lat, q_lng) <= p_meters;
$$;

-- Nivel desde XP: level = floor(sqrt(total_xp / 100)) + 1
CREATE OR REPLACE FUNCTION xp_to_level(p_total_xp INT)
RETURNS INT
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT GREATEST(1, FLOOR(SQRT(p_total_xp::DOUBLE PRECISION / 100.0))::INT + 1);
$$;

-- Otorga XP, actualiza nivel, retorna nuevo total + level
CREATE OR REPLACE FUNCTION award_xp(
    p_user_id UUID,
    p_xp INT
) RETURNS TABLE(new_total_xp INT, new_level INT)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_total INT;
    v_new_level INT;
BEGIN
    INSERT INTO user_xp (user_id, total_xp, level, raids_completed, checkpoints_captured, km_traveled, updated_at)
    VALUES (p_user_id, p_xp, xp_to_level(p_xp), 0, 0, 0.0, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        total_xp  = user_xp.total_xp + p_xp,
        level     = xp_to_level(user_xp.total_xp + p_xp),
        updated_at = NOW()
    RETURNING total_xp, level INTO v_current_total, v_new_level;

    RETURN QUERY SELECT v_current_total AS new_total_xp, v_new_level;
END;
$$;

-- Incrementa checkpoints_taken (usado por Edge Function)
CREATE OR REPLACE FUNCTION increment_checkpoints(p_participant_id BIGINT)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new INT;
BEGIN
    UPDATE raid_participants
    SET checkpoints_taken = checkpoints_taken + 1
    WHERE id = p_participant_id
    RETURNING checkpoints_taken INTO v_new;
    RETURN v_new;
END;
$$;

-- Incrementa upvotes en road_alerts
CREATE OR REPLACE FUNCTION increment_alert_upvote(p_alert_id BIGINT)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new INT;
BEGIN
    UPDATE road_alerts
    SET upvotes = upvotes + 1
    WHERE id = p_alert_id
    RETURNING upvotes INTO v_new;
    RETURN v_new;
END;
$$;

-- Obtener lugares cercanos (bounding box + háversine)
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
```

## 1.2 Schema: Tablas Existentes (Migradas)

```sql
-- ============================================================
-- MIGRATION 002: TABLAS EXISTENTES (Mantenidas del schema anterior)
-- ============================================================

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

-- visits
CREATE TABLE IF NOT EXISTS visits (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    verified_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_url    VARCHAR(550),
    is_verified     BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_user_place_day UNIQUE (user_id, place_id, DATE_TRUNC('day', verified_at))
);
CREATE INDEX IF NOT EXISTS idx_visits_user ON visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_place ON visits(place_id);

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
```

## 1.3 Schema: Tablas Nuevas — Core (Raids, Clanes, Progresión)

```sql
-- ============================================================
-- MIGRATION 003: TABLAS NUEVAS — CORE
-- ============================================================

-- user_xp (reemplaza user_points)
CREATE TABLE IF NOT EXISTS user_xp (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_xp            INT DEFAULT 0,
    level               INT DEFAULT 1,
    raids_completed     INT DEFAULT 0,
    checkpoints_captured INT DEFAULT 0,
    km_traveled         DOUBLE PRECISION DEFAULT 0.0,
    current_streak      INT DEFAULT 0,
    longest_streak      INT DEFAULT 0,
    last_raid_date      DATE,
    trust_score         SMALLINT DEFAULT 50 CHECK (trust_score BETWEEN 0 AND 100),
    coins               INT DEFAULT 0 CHECK (coins >= 0),
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_xp_total ON user_xp(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_xp_level ON user_xp(level DESC);

-- achievements
CREATE TABLE IF NOT EXISTS achievements (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    icon            VARCHAR(50) DEFAULT '🏆',
    description     TEXT,
    xp_reward       INT DEFAULT 0,
    criteria        JSONB NOT NULL,
    category        TEXT DEFAULT 'general'
                    CHECK (category IN ('general', 'raids', 'clans', 'checkpoints', 'social', 'membership')),
    sort_order      INT DEFAULT 0
);

-- user_achievements
CREATE TABLE IF NOT EXISTS user_achievements (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id  BIGINT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    earned_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, achievement_id)
);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);

-- leaderboard_snapshots
CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
    id              BIGSERIAL PRIMARY KEY,
    category        TEXT NOT NULL
                    CHECK (category IN ('general', 'weekly', 'monthly', 'clan_weekly', 'clan_monthly')),
    rank            INT NOT NULL,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    clan_id         BIGINT,
    metric_value    INT NOT NULL,
    snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category, rank, snapshot_date)
);
CREATE INDEX IF NOT EXISTS idx_lb_snapshots_cat_date ON leaderboard_snapshots(category, snapshot_date DESC);

-- clans
CREATE TABLE IF NOT EXISTS clans (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    tag             VARCHAR(10) NOT NULL,
    description     TEXT,
    logo_url        VARCHAR(550),
    founder_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    is_public       BOOLEAN DEFAULT TRUE,
    max_members     INT DEFAULT 50,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name),
    UNIQUE(tag)
);
CREATE INDEX IF NOT EXISTS idx_clans_founder ON clans(founder_id);
CREATE INDEX IF NOT EXISTS idx_clans_public ON clans(is_public) WHERE is_public = TRUE;

-- clan_members
CREATE TABLE IF NOT EXISTS clan_members (
    id              BIGSERIAL PRIMARY KEY,
    clan_id         BIGINT NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL DEFAULT 'recruit'
                    CHECK (role IN ('founder', 'captain', 'rider', 'recruit')),
    joined_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(clan_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_clan_members_clan ON clan_members(clan_id);
CREATE INDEX IF NOT EXISTS idx_clan_members_user ON clan_members(user_id);

-- raids
CREATE TABLE IF NOT EXISTS raids (
    id              BIGSERIAL PRIMARY KEY,
    host_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    origin_lat      DOUBLE PRECISION NOT NULL,
    origin_lng      DOUBLE PRECISION NOT NULL,
    dest_lat        DOUBLE PRECISION NOT NULL,
    dest_lng        DOUBLE PRECISION NOT NULL,
    mode            TEXT NOT NULL DEFAULT 'free_ride'
                    CHECK (mode IN ('free_ride', 'rally', 'ruta_gotica', 'convoy', 'sobrevivencia', 'guerra_clanes')),
    scheduled_at    TIMESTAMPTZ NOT NULL,
    is_public       BOOLEAN DEFAULT TRUE,
    status          TEXT NOT NULL DEFAULT 'planned'
                    CHECK (status IN ('planned', 'lobby', 'active', 'completed', 'cancelled')),
    clan_id         BIGINT REFERENCES clans(id) ON DELETE SET NULL,
    max_participants INT DEFAULT 20,
    description     TEXT,
    route_data      JSONB,
    weather_conditions JSONB,
    adjusted_eta    TIMESTAMPTZ,
    weather_checked_at TIMESTAMPTZ,
    is_night_raid   BOOLEAN NOT NULL DEFAULT FALSE,
    allow_spectators BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_raids_host ON raids(host_id);
CREATE INDEX IF NOT EXISTS idx_raids_status ON raids(status);
CREATE INDEX IF NOT EXISTS idx_raids_scheduled ON raids(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_raids_public ON raids(is_public, status) WHERE is_public = TRUE AND status = 'lobby';
CREATE INDEX IF NOT EXISTS idx_raids_clan ON raids(clan_id) WHERE clan_id IS NOT NULL;

-- raid_participants
CREATE TABLE IF NOT EXISTS raid_participants (
    id                BIGSERIAL PRIMARY KEY,
    raid_id           BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_ready          BOOLEAN DEFAULT FALSE,
    finished_position INT,
    xp_earned         INT DEFAULT 0,
    km_traveled       DOUBLE PRECISION DEFAULT 0.0,
    time_seconds      INT DEFAULT 0,
    checkpoints_taken INT DEFAULT 0,
    is_completed      BOOLEAN DEFAULT FALSE,
    last_lat          DOUBLE PRECISION,
    last_lng          DOUBLE PRECISION,
    last_heading      DOUBLE PRECISION,
    last_speed_kmh    DOUBLE PRECISION,
    last_position_at  TIMESTAMPTZ,
    livekit_token     TEXT,
    livekit_room      TEXT,
    anti_cheat_flags  INT NOT NULL DEFAULT 0,
    is_flagged        BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(raid_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_raid_participants_raid ON raid_participants(raid_id);
CREATE INDEX IF NOT EXISTS idx_raid_participants_user ON raid_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_raid_participants_ready ON raid_participants(raid_id, is_ready);

-- raid_checkpoints
CREATE TABLE IF NOT EXISTS raid_checkpoints (
    id              BIGSERIAL PRIMARY KEY,
    raid_id         BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    place_id        BIGINT REFERENCES places(id) ON DELETE SET NULL,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    sort_order      INT NOT NULL DEFAULT 0,
    is_hidden       BOOLEAN DEFAULT FALSE,
    qr_code         VARCHAR(255),
    radius_meters   DOUBLE PRECISION DEFAULT 50,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_raid_cp_raid ON raid_checkpoints(raid_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_raid_cp_place ON raid_checkpoints(place_id) WHERE place_id IS NOT NULL;

-- raid_checkpoint_verifications
CREATE TABLE IF NOT EXISTS raid_checkpoint_verifications (
    id                  BIGSERIAL PRIMARY KEY,
    raid_participant_id BIGINT NOT NULL REFERENCES raid_participants(id) ON DELETE CASCADE,
    checkpoint_id       BIGINT NOT NULL REFERENCES raid_checkpoints(id) ON DELETE CASCADE,
    verified_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    photo_url           TEXT,
    lat                 DOUBLE PRECISION,
    lng                 DOUBLE PRECISION,
    accuracy_meters     DOUBLE PRECISION,
    qr_scanned          BOOLEAN DEFAULT FALSE,
    is_valid            BOOLEAN DEFAULT FALSE,
    validation_method   TEXT DEFAULT 'gps'
                        CHECK (validation_method IN ('gps', 'qr', 'gps+qr', 'photo')),
    UNIQUE(raid_participant_id, checkpoint_id)
);
CREATE INDEX IF NOT EXISTS idx_raid_verif_participant ON raid_checkpoint_verifications(raid_participant_id);
CREATE INDEX IF NOT EXISTS idx_raid_verif_checkpoint ON raid_checkpoint_verifications(checkpoint_id);

-- raid_messages (chat de raid)
CREATE TABLE IF NOT EXISTS raid_messages (
    id              BIGSERIAL PRIMARY KEY,
    raid_id         BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    type            TEXT NOT NULL DEFAULT 'text'
                    CHECK (type IN ('text', 'ping', 'system')),
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_raid_messages_raid ON raid_messages(raid_id, created_at);

-- clan_messages
CREATE TABLE IF NOT EXISTS clan_messages (
    id              BIGSERIAL PRIMARY KEY,
    clan_id         BIGINT NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_clan_messages_clan ON clan_messages(clan_id, created_at);
```

## 1.4 Schema: Tablas Nuevas — Safety, Economy, Anti-Cheat, Extra

```sql
-- ============================================================
-- MIGRATION 004: TABLAS NUEVAS — SAFETY, ECONOMY, ANTI-CHEAT, EXTRA
-- ============================================================

-- drive_scores (estilo de conducción post-raid)
CREATE TABLE IF NOT EXISTS drive_scores (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raid_participant_id     BIGINT NOT NULL REFERENCES raid_participants(id) ON DELETE CASCADE,
    overall_score           SMALLINT NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
    braking_score           SMALLINT CHECK (braking_score BETWEEN 0 AND 100),
    acceleration_score      SMALLINT CHECK (acceleration_score BETWEEN 0 AND 100),
    speed_consistency_score SMALLINT CHECK (speed_consistency_score BETWEEN 0 AND 100),
    speed_limit_score       SMALLINT CHECK (speed_limit_score BETWEEN 0 AND 100),
    raw_data                JSONB,
    calculated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- voice_channels
CREATE TABLE IF NOT EXISTS voice_channels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raid_id         BIGINT REFERENCES raids(id) ON DELETE CASCADE,
    clan_id         BIGINT REFERENCES clans(id) ON DELETE CASCADE,
    livekit_room    TEXT NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT FALSE,
    max_participants SMALLINT NOT NULL DEFAULT 20,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ
);

-- mentor_relationships
CREATE TABLE IF NOT EXISTS mentor_relationships (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mentor_id       UUID NOT NULL REFERENCES users(id),
    rookie_id       UUID NOT NULL REFERENCES users(id),
    raid_id         BIGINT NOT NULL REFERENCES raids(id),
    bonus_xp_awarded INT NOT NULL DEFAULT 0,
    completed_safely BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(mentor_id, rookie_id, raid_id)
);

-- conduct_reports
CREATE TABLE IF NOT EXISTS conduct_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id     UUID NOT NULL REFERENCES users(id),
    reported_id     UUID NOT NULL REFERENCES users(id),
    raid_id         BIGINT NOT NULL REFERENCES raids(id),
    reason          TEXT NOT NULL,
    severity        SMALLINT NOT NULL DEFAULT 1 CHECK (severity BETWEEN 1 AND 5),
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    verified_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- shop_items
CREATE TABLE IF NOT EXISTS shop_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    description     TEXT,
    type            TEXT NOT NULL CHECK (type IN ('cosmetic', 'consumable')),
    subtype         TEXT CHECK (subtype IN ('avatar_skin', 'bike_skin', 'clan_banner',
                                            'marker_color', 'checkpoint_effect', 'xp_boost_small', 'title')),
    icon_url        TEXT,
    coins_cost      INT NOT NULL CHECK (coins_cost > 0),
    battle_pass_only BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- user_purchases
CREATE TABLE IF NOT EXISTS user_purchases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    item_id         UUID NOT NULL REFERENCES shop_items(id),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    purchased_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- battle_passes
CREATE TABLE IF NOT EXISTS battle_passes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_name     TEXT NOT NULL,
    season_number   INT NOT NULL,
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    cosmetic_rewards JSONB,
    is_active       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- battle_pass_progress
CREATE TABLE IF NOT EXISTS battle_pass_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    battle_pass_id  UUID NOT NULL REFERENCES battle_passes(id),
    current_tier    INT NOT NULL DEFAULT 1,
    xp_in_season    INT NOT NULL DEFAULT 0,
    has_premium     BOOLEAN NOT NULL DEFAULT FALSE,
    claimed_rewards JSONB DEFAULT '[]'::JSONB,
    UNIQUE(user_id, battle_pass_id)
);

-- battle_pass_missions
CREATE TABLE IF NOT EXISTS battle_pass_missions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    battle_pass_id  UUID NOT NULL REFERENCES battle_passes(id),
    title           TEXT NOT NULL,
    description     TEXT NOT NULL,
    requirement     JSONB NOT NULL,
    xp_reward       INT NOT NULL,
    tier_unlock     INT NOT NULL DEFAULT 1,
    is_daily        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- user_missions_progress
CREATE TABLE IF NOT EXISTS user_missions_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    mission_id      UUID NOT NULL REFERENCES battle_pass_missions(id),
    progress        INT NOT NULL DEFAULT 0,
    target          INT NOT NULL,
    is_completed    BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at    TIMESTAMPTZ,
    UNIQUE(user_id, mission_id)
);

-- anti_cheat_log
CREATE TABLE IF NOT EXISTS anti_cheat_log (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raid_participant_id BIGINT NOT NULL REFERENCES raid_participants(id),
    checkpoint_id       BIGINT REFERENCES raid_checkpoints(id),
    check_type          TEXT NOT NULL CHECK (check_type IN ('gps_mock', 'speed', 'photo_exif', 'qr_replay', 'timestamp')),
    passed              BOOLEAN NOT NULL,
    details             JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- sos_events
CREATE TABLE IF NOT EXISTS sos_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    raid_id             BIGINT REFERENCES raids(id),
    lat                 DOUBLE PRECISION NOT NULL,
    lng                 DOUBLE PRECISION NOT NULL,
    detected_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ,
    trigger_type        TEXT NOT NULL CHECK (trigger_type IN ('manual', 'crash_detection', 'fall_detection')),
    contacted_emergency BOOLEAN NOT NULL DEFAULT FALSE,
    contacted_clan      BOOLEAN NOT NULL DEFAULT FALSE,
    notes               TEXT
);

-- raid_spectators
CREATE TABLE IF NOT EXISTS raid_spectators (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raid_id         BIGINT NOT NULL REFERENCES raids(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at         TIMESTAMPTZ,
    UNIQUE(raid_id, user_id)
);

-- raid_position_log (histórico para replays)
CREATE TABLE IF NOT EXISTS raid_position_log (
    id                  BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    raid_participant_id BIGINT NOT NULL REFERENCES raid_participants(id),
    lat                 DOUBLE PRECISION NOT NULL,
    lng                 DOUBLE PRECISION NOT NULL,
    heading             REAL,
    speed               REAL,
    timestamp           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_raid_position_log_raid ON raid_position_log(raid_participant_id, timestamp);

-- clan_territories
CREATE TABLE IF NOT EXISTS clan_territories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clan_id         BIGINT NOT NULL REFERENCES clans(id),
    zone_name       TEXT NOT NULL,
    center_lat      DOUBLE PRECISION NOT NULL,
    center_lng      DOUBLE PRECISION NOT NULL,
    radius_meters   INT NOT NULL DEFAULT 1000,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_defended_at TIMESTAMPTZ,
    last_attacked_at TIMESTAMPTZ,
    current_owner_id BIGINT REFERENCES clans(id)
);

-- ============================================================
-- Habilitar Realtime en tablas de mensajes
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE clan_messages;
```

---

# 2. Triggers y Funciones

```sql
-- ============================================================
-- MIGRATION 005: TRIGGERS
-- ============================================================

-- 2.1 Updated_at automático
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_places_updated_at
    BEFORE UPDATE ON places
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_clans_updated_at
    BEFORE UPDATE ON clans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_raids_updated_at
    BEFORE UPDATE ON raids
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_user_xp_updated_at
    BEFORE UPDATE ON user_xp
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 2.2 Streak trigger (al completar raid)
CREATE OR REPLACE FUNCTION update_streak()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_last_date DATE;
    v_today DATE := CURRENT_DATE;
BEGIN
    SELECT last_raid_date INTO v_last_date
    FROM user_xp WHERE user_id = NEW.user_id;

    IF v_last_date IS NULL THEN
        UPDATE user_xp SET
            current_streak = 1,
            longest_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date = v_today - INTERVAL '1 day' THEN
        UPDATE user_xp SET
            current_streak = current_streak + 1,
            longest_streak = GREATEST(longest_streak, current_streak + 1),
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date < v_today - INTERVAL '1 day' THEN
        UPDATE user_xp SET
            current_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_streak
    AFTER UPDATE OF is_completed ON raid_participants
    FOR EACH ROW
    WHEN (NEW.is_completed = TRUE AND OLD.is_completed = FALSE)
    EXECUTE FUNCTION update_streak();

-- 2.3 Achievement checker (al actualizar user_xp)
CREATE OR REPLACE FUNCTION check_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_ach RECORD;
    v_bonus_xp INT;
BEGIN
    FOR v_ach IN SELECT * FROM achievements
    LOOP
        IF NOT EXISTS (SELECT 1 FROM user_achievements WHERE user_id = NEW.user_id AND achievement_id = v_ach.id) THEN
            CASE v_ach.criteria->>'type'
                WHEN 'raids_completed' THEN
                    IF NEW.raids_completed >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'checkpoints_captured' THEN
                    IF NEW.checkpoints_captured >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'km_traveled' THEN
                    IF NEW.km_traveled >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'mode_wins' THEN
                    -- Evaluado por finish_raid EF
                    NULL;
                WHEN 'clan_founded' THEN
                    NULL; -- Evaluado externamente
                WHEN 'clan_members' THEN
                    NULL;
                WHEN 'following_count' THEN
                    NULL;
                WHEN 'membership_activated' THEN
                    NULL;
                WHEN 'streak_days' THEN
                    IF NEW.longest_streak >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'pings_sent' THEN
                    NULL; -- Evaluado externamente
                WHEN 'full_route_completion' THEN
                    NULL; -- Evaluado por finish_raid EF
                WHEN 'raids_as_host' THEN
                    NULL; -- Evaluado externamente
                ELSE NULL;
            END CASE;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_achievements
    AFTER UPDATE OF raids_completed, checkpoints_captured, km_traveled ON user_xp
    FOR EACH ROW
    EXECUTE FUNCTION check_achievements();

-- 2.4 Post-signup: crear registro en users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.users (id, full_name, username)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'username', 'motero_' || SUBSTRING(NEW.id::TEXT, 1, 8))
    );
    INSERT INTO public.user_xp (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_handle_new_user
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- 2.5 Detectar raids nocturnos al INSERT/UPDATE
CREATE OR REPLACE FUNCTION check_night_raid()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXTRACT(HOUR FROM NEW.scheduled_at AT TIME ZONE 'America/Argentina/Buenos_Aires') >= 20
       OR EXTRACT(HOUR FROM NEW.scheduled_at AT TIME ZONE 'America/Argentina/Buenos_Aires') < 6 THEN
        NEW.is_night_raid = TRUE;
    ELSE
        NEW.is_night_raid = FALSE;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_night_raid
    BEFORE INSERT OR UPDATE OF scheduled_at ON raids
    FOR EACH ROW
    EXECUTE FUNCTION check_night_raid();
```

---

# 3. Seed Data

```sql
-- ============================================================
-- MIGRATION 006: SEED DATA
-- ============================================================

-- 3.1 Achievements (17 del SDD)
INSERT INTO achievements (name, icon, description, xp_reward, criteria, category, sort_order) VALUES
    ('Primer Raid',          '🏁', 'Completá tu primer raid',                 100,  '{"type": "raids_completed", "count": 1}',    'raids', 1),
    ('Corredor Nocturno',    '🌙', 'Completá 5 raids',                         250,  '{"type": "raids_completed", "count": 5}',    'raids', 2),
    ('Leyenda del Asfalto',  '👑', 'Completá 25 raids',                        1000, '{"type": "raids_completed", "count": 25}',   'raids', 3),
    ('Velocista',            '⚡', 'Ganá un Rally',                             200,  '{"type": "mode_wins", "mode": "rally", "count": 1}', 'raids', 4),
    ('Ruta Gótica',          '🗺️', 'Completá todos los checkpoints de una Ruta Gótica', 300, '{"type": "full_route_completion", "mode": "ruta_gotica", "count": 1}', 'raids', 5),
    ('Sobreviviente',        '💀', 'Completá un raid en modo Sobrevivencia',   350,  '{"type": "mode_wins", "mode": "sobrevivencia", "count": 1}', 'raids', 6),
    ('Guerrero de Clanes',   '⚔️', 'Ganá una Guerra de Clanes',                500,  '{"type": "mode_wins", "mode": "guerra_clanes", "count": 1}', 'clans', 7),
    ('Fundador',             '🏗️', 'Creá un clan',                              200,  '{"type": "clan_founded", "count": 1}',      'clans', 8),
    ('Clan Unido',           '🤝', 'Tu clan llega a 10 miembros',               300,  '{"type": "clan_members", "count": 10}',     'clans', 9),
    ('Explorador',           '📍', 'Visitá 10 checkpoints diferentes',         250,  '{"type": "checkpoints_captured", "count": 10}', 'checkpoints', 10),
    ('Checkpoint Master',    '🎯', 'Capturá 50 checkpoints',                    500,  '{"type": "checkpoints_captured", "count": 50}', 'checkpoints', 11),
    ('1000km Club',          '🏍️', 'Recorré 1,000 km en raids',                 500,  '{"type": "km_traveled", "count": 1000}',    'general', 12),
    ('Host Experto',         '🎪', 'Organizá 10 raids como host',               400,  '{"type": "raids_as_host", "count": 10}',    'raids', 13),
    ('Social Rider',         '👥', 'Seguí a 20 moteros',                        150,  '{"type": "following_count", "count": 20}',  'social', 14),
    ('Premium',              '💎', 'Activá membresía premium',                  500,  '{"type": "membership_activated", "count": 1}', 'membership', 15),
    ('Racha de 7 días',      '🔥', 'Completá raids 7 días consecutivos',       750,  '{"type": "streak_days", "count": 7}',       'raids', 16),
    ('Ping Pong',            '📌', 'Enviá 50 pings en raids',                   100,  '{"type": "pings_sent", "count": 50}',       'raids', 17);

-- 3.2 Shop items iniciales
INSERT INTO shop_items (name, description, type, subtype, icon_url, coins_cost, battle_pass_only, is_active) VALUES
    ('Casco Clásico',        'Skin de avatar: casco negro clásico',            'cosmetic', 'avatar_skin', NULL, 200,  FALSE, TRUE),
    ('Casco Carbono',        'Skin de avatar: casco de fibra de carbono',      'cosmetic', 'avatar_skin', NULL, 500,  FALSE, TRUE),
    ('Moto Deportiva',       'Skin de moto: estilo deportivo',                 'cosmetic', 'bike_skin',   NULL, 300,  FALSE, TRUE),
    ('Moto Custom',          'Skin de moto: estilo chopper',                   'cosmetic', 'bike_skin',   NULL, 400,  FALSE, TRUE),
    ('Banner Fuego',         'Banner de clan: estilo llama',                   'cosmetic', 'clan_banner', NULL, 250,  FALSE, TRUE),
    ('Marcador Neón',        'Color de marcador en mapa: verde neón',          'cosmetic', 'marker_color',NULL, 150,  FALSE, TRUE),
    ('Estela Laser',         'Efecto de checkpoint: laser verde',              'cosmetic', 'checkpoint_effect', NULL, 350, TRUE, TRUE),
    ('XP Boost x2',          'Multiplica tu XP x2 en tu próximo raid',         'consumable','xp_boost_small', NULL, 100,  FALSE, TRUE),
    ('Leyenda del Asfalto',  'Título cosmético: Leyenda del Asfalto',          'cosmetic', 'title',       NULL, 800,  FALSE, TRUE),
    ('Rider Nocturno',       'Título cosmético: Rider Nocturno',               'cosmetic', 'title',       NULL, 600,  FALSE, TRUE),
    ('Banner Hielo',         'Banner de clan: estilo glacial',                 'cosmetic', 'clan_banner', NULL, 250,  TRUE, TRUE),
    ('Estela Fuego',         'Efecto de checkpoint: fuego',                    'cosmetic', 'checkpoint_effect', NULL, 350, TRUE, TRUE);

-- 3.3 Leaderboard placeholder
INSERT INTO leaderboard_snapshots (category, rank, user_id, metric_value, snapshot_date)
VALUES ('general', 1, NULL, 0, CURRENT_DATE);

-- 3.4 Challenges legacy
INSERT INTO challenges (title, description, icon, sort_order) VALUES
    ('Primera Visita',    'Visitá tu primer lugar',                '📍', 1),
    ('5 Lugares',         'Visitá 5 lugares diferentes',          '📍', 2),
    ('10 Lugares',        'Visitá 10 lugares diferentes',         '📍', 3),
    ('Ruta Larga',        'Grabá una ruta de más de 50 km',       '🏍️', 4),
    ('Madrugador',        'Visitá un lugar antes de las 8 AM',    '🌅', 5),
    ('Noctámbulo',        'Visitá un lugar después de las 10 PM', '🌙', 6);

-- 3.5 Patches legacy
INSERT INTO patches (name, icon, place, requirement) VALUES
    ('Parche Visitante',    '📍', NULL, 'Visitá 1 lugar'),
    ('Parche Explorador',   '🗺️', NULL, 'Visitá 5 lugares'),
    ('Parche Leyenda',      '🏆', NULL, 'Visitá 25 lugares');
```

---

# 4. RLS Policies

```sql
-- ============================================================
-- MIGRATION 007: RLS POLICIES
-- ============================================================

-- 4.1 Habilitar RLS en todas las tablas
DO $$ DECLARE
    t TEXT;
BEGIN
    FOR t IN
        SELECT unnest(ARRAY['users', 'user_follows', 'memberships', 'places', 'visits',
            'allies', 'evidence_photos', 'saved_routes', 'road_alerts', 'challenges',
            'user_challenges', 'patches', 'user_patches', 'clans', 'clan_members',
            'raids', 'raid_participants', 'raid_checkpoints', 'raid_checkpoint_verifications',
            'raid_messages', 'clan_messages', 'user_xp', 'achievements', 'user_achievements',
            'leaderboard_snapshots', 'drive_scores', 'voice_channels', 'mentor_relationships',
            'conduct_reports', 'shop_items', 'user_purchases', 'battle_passes',
            'battle_pass_progress', 'battle_pass_missions', 'user_missions_progress',
            'anti_cheat_log', 'sos_events', 'raid_spectators', 'raid_position_log', 'clan_territories'])
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    END LOOP;
END $$;

-- Helper: admin check
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' = 'admin'
    );
$$;

-- ============================================================
-- 4.2 users
-- ============================================================
CREATE POLICY "users_select_public" ON users FOR SELECT USING (true);
CREATE POLICY "users_insert_own" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "users_update_own" ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "users_delete_admin" ON users FOR DELETE USING (is_admin());

-- ============================================================
-- 4.3 user_follows
-- ============================================================
CREATE POLICY "follows_select_own" ON user_follows FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = followed_id);
CREATE POLICY "follows_insert_own" ON user_follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete_own" ON user_follows FOR DELETE USING (auth.uid() = follower_id);

-- ============================================================
-- 4.4 memberships
-- ============================================================
CREATE POLICY "memberships_select_own" ON memberships FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "memberships_insert_own" ON memberships FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.5 places
-- ============================================================
CREATE POLICY "places_select_public" ON places FOR SELECT USING (true);
CREATE POLICY "places_insert_auth" ON places FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "places_update_own_or_premium" ON places
    FOR UPDATE USING (
        auth.uid() = created_by OR
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND membership_tier = 'premium')
    );
CREATE POLICY "places_delete_admin" ON places FOR DELETE USING (is_admin());

-- ============================================================
-- 4.6 visits
-- ============================================================
CREATE POLICY "visits_select_own" ON visits FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "visits_insert_own" ON visits FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.7 allies
-- ============================================================
CREATE POLICY "allies_select_public" ON allies FOR SELECT USING (true);
CREATE POLICY "allies_insert_admin" ON allies FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "allies_update_admin" ON allies FOR UPDATE USING (is_admin());
CREATE POLICY "allies_delete_admin" ON allies FOR DELETE USING (is_admin());

-- ============================================================
-- 4.8 evidence_photos
-- ============================================================
CREATE POLICY "evphotos_select_own" ON evidence_photos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "evphotos_insert_own" ON evidence_photos FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.9 saved_routes
-- ============================================================
CREATE POLICY "routes_select_own" ON saved_routes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "routes_insert_own" ON saved_routes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "routes_delete_own" ON saved_routes FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.10 road_alerts
-- ============================================================
CREATE POLICY "alerts_select_public" ON road_alerts FOR SELECT USING (active = true);
CREATE POLICY "alerts_select_own" ON road_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "alerts_insert_own" ON road_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "alerts_update_own" ON road_alerts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "alerts_delete_own" ON road_alerts FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.11 challenges / user_challenges / patches / user_patches
-- ============================================================
CREATE POLICY "challenges_select_public" ON challenges FOR SELECT USING (true);
CREATE POLICY "uchallenges_select_own" ON user_challenges FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "uchallenges_update_own" ON user_challenges FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "patches_select_public" ON patches FOR SELECT USING (true);
CREATE POLICY "upatches_select_own" ON user_patches FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- 4.12 clans
-- ============================================================
CREATE POLICY "clans_select_public" ON clans FOR SELECT USING (is_public = true);
CREATE POLICY "clans_select_member" ON clans FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clans.id AND user_id = auth.uid())
);
CREATE POLICY "clans_insert_auth" ON clans FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "clans_update_founder_captain" ON clans
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role IN ('founder', 'captain'))
    );
CREATE POLICY "clans_delete_founder" ON clans
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role = 'founder')
    );

-- ============================================================
-- 4.13 clan_members
-- ============================================================
CREATE POLICY "cm_select_own" ON clan_members FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "cm_select_clan_member" ON clan_members FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id AND cm2.user_id = auth.uid())
);
CREATE POLICY "cm_insert_public" ON clan_members FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM clans WHERE id = clan_id AND is_public = true)
);
CREATE POLICY "cm_insert_invite" ON clan_members FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain'))
);
CREATE POLICY "cm_update_role" ON clan_members FOR UPDATE USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role = 'founder')
);
CREATE POLICY "cm_delete_self" ON clan_members FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "cm_delete_management" ON clan_members FOR DELETE USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain'))
);

-- ============================================================
-- 4.14 raids
-- ============================================================
CREATE POLICY "raids_select_public" ON raids FOR SELECT USING (
    is_public = true AND status IN ('planned', 'lobby')
);
CREATE POLICY "raids_select_participant" ON raids FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = id AND user_id = auth.uid())
);
CREATE POLICY "raids_select_clan_member" ON raids FOR SELECT USING (
    clan_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = raids.clan_id AND user_id = auth.uid())
);
CREATE POLICY "raids_select_host" ON raids FOR SELECT USING (auth.uid() = host_id);
CREATE POLICY "raids_insert_auth" ON raids FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "raids_update_host" ON raids FOR UPDATE USING (auth.uid() = host_id) WITH CHECK (auth.uid() = host_id);
CREATE POLICY "raids_delete_host" ON raids FOR DELETE USING (auth.uid() = host_id);

-- ============================================================
-- 4.15 raid_participants
-- ============================================================
CREATE POLICY "rp_select_own" ON raid_participants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "rp_select_raid_participants" ON raid_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants rp2 WHERE rp2.raid_id = raid_participants.raid_id AND rp2.user_id = auth.uid())
);
CREATE POLICY "rp_select_raid_host" ON raid_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rp_insert_public" ON raid_participants FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raids WHERE id = raid_id
        AND (is_public = true OR host_id = auth.uid())
        AND status = 'lobby')
);
CREATE POLICY "rp_update_own" ON raid_participants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "rp_update_host" ON raid_participants FOR UPDATE USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rp_delete_own" ON raid_participants FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.16 raid_checkpoints
-- ============================================================
CREATE POLICY "rc_select_participant" ON raid_checkpoints FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_checkpoints.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rc_select_host" ON raid_checkpoints FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_checkpoints.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rc_insert_host" ON raid_checkpoints FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
);
CREATE POLICY "rc_delete_host" ON raid_checkpoints FOR DELETE USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
);

-- ============================================================
-- 4.17 raid_checkpoint_verifications
-- ============================================================
CREATE POLICY "rcv_select_own" ON raid_checkpoint_verifications FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
);
CREATE POLICY "rcv_select_raid_host" ON raid_checkpoint_verifications FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM raid_participants rp
        JOIN raids r ON r.id = rp.raid_id
        WHERE rp.id = raid_checkpoint_verifications.raid_participant_id
        AND r.host_id = auth.uid()
    )
);
CREATE POLICY "rcv_insert_own" ON raid_checkpoint_verifications FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
);

-- ============================================================
-- 4.18 raid_messages
-- ============================================================
CREATE POLICY "rm_select_participant" ON raid_messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rm_insert_participant" ON raid_messages FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rm_delete_own" ON raid_messages FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.19 clan_messages
-- ============================================================
CREATE POLICY "cm_select_clan_member" ON clan_messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
);
CREATE POLICY "cm_insert_clan_member" ON clan_messages FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
);
CREATE POLICY "cm_delete_own" ON clan_messages FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.20 user_xp
-- ============================================================
CREATE POLICY "xp_select_all" ON user_xp FOR SELECT USING (true);
CREATE POLICY "xp_insert_own" ON user_xp FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.21 achievements / user_achievements / leaderboard_snapshots
-- ============================================================
CREATE POLICY "achievements_select_public" ON achievements FOR SELECT USING (true);
CREATE POLICY "ua_select_all" ON user_achievements FOR SELECT USING (true);
CREATE POLICY "ua_insert_system" ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');
CREATE POLICY "lb_select_public" ON leaderboard_snapshots FOR SELECT USING (true);

-- ============================================================
-- 4.22 Tablas de seguridad y economía (RLS restrictiva)
-- ============================================================
-- drive_scores: solo el participante y el host del raid
CREATE POLICY "ds_select_own" ON drive_scores FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM raid_participants rp JOIN raids r ON r.id = rp.raid_id WHERE rp.id = raid_participant_id AND r.host_id = auth.uid())
);

-- sos_events: participantes del raid y clan pueden ver
CREATE POLICY "sos_select_raid_participant" ON sos_events FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = sos_events.raid_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM clan_members cm JOIN raids r ON r.clan_id = cm.clan_id WHERE r.id = sos_events.raid_id AND cm.user_id = auth.uid())
    OR is_admin()
);

-- anti_cheat_log: solo admins
CREATE POLICY "acl_select_admin" ON anti_cheat_log FOR SELECT USING (is_admin());
CREATE POLICY "acl_insert_system" ON anti_cheat_log FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- conduct_reports: solo admins y reportado
CREATE POLICY "cr_select_admin_or_reported" ON conduct_reports FOR SELECT USING (
    is_admin() OR auth.uid() = reported_id
);

-- shop_items: lectura pública
CREATE POLICY "shop_select_public" ON shop_items FOR SELECT USING (is_active = true);
CREATE POLICY "shop_insert_admin" ON shop_items FOR INSERT WITH CHECK (is_admin());

-- user_purchases: solo propio usuario
CREATE POLICY "up_select_own" ON user_purchases FOR SELECT USING (auth.uid() = user_id);

-- battle_pass: lectura pública
CREATE POLICY "bp_select_public" ON battle_passes FOR SELECT USING (true);
CREATE POLICY "bpp_select_own" ON battle_pass_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "bpm_select_public" ON battle_pass_missions FOR SELECT USING (true);
CREATE POLICY "ump_select_own" ON user_missions_progress FOR SELECT USING (auth.uid() = user_id);

-- raid_spectators: propio y host
CREATE POLICY "rs_select_own" ON raid_spectators FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "rs_select_host" ON raid_spectators FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_spectators.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rs_insert_spectator" ON raid_spectators FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND status = 'active' AND allow_spectators = true)
);
CREATE POLICY "rs_update_own" ON raid_spectators FOR UPDATE USING (auth.uid() = user_id);

-- voice_channels: participantes del raid o miembros del clan
CREATE POLICY "vc_select_participant" ON voice_channels FOR SELECT USING (
    (raid_id IS NOT NULL AND EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = voice_channels.raid_id AND user_id = auth.uid()))
    OR (clan_id IS NOT NULL AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = voice_channels.clan_id AND user_id = auth.uid()))
);
```

---

# 5. Storage Buckets + Policies

```sql
-- ============================================================
-- MIGRATION 008: STORAGE BUCKETS Y POLICIES
-- ============================================================

-- Crear buckets
INSERT INTO storage.buckets (id, name, public) VALUES
    ('clan-logos', 'clan-logos', true),
    ('profile-images', 'profile-images', true),
    ('checkpoint-evidence', 'checkpoint-evidence', true),
    ('place-photos', 'place-photos', true)
ON CONFLICT (id) DO NOTHING;

-- === clan-logos ===
CREATE POLICY "clan_logos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'clan-logos');
CREATE POLICY "clan_logos_insert_founder_captain" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'clan-logos'
        AND auth.role() = 'authenticated'
    );
CREATE POLICY "clan_logos_delete_founder_captain" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'clan-logos'
        AND EXISTS (
            SELECT 1 FROM clan_members cm
            JOIN clans c ON c.id = cm.clan_id
            WHERE cm.user_id = auth.uid()
            AND cm.role IN ('founder', 'captain')
        )
    );

-- === profile-images ===
CREATE POLICY "profile_images_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile-images');
CREATE POLICY "profile_images_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );
CREATE POLICY "profile_images_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

-- === checkpoint-evidence ===
CREATE POLICY "checkpoint_evidence_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'checkpoint-evidence');
CREATE POLICY "checkpoint_evidence_insert_auth" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'checkpoint-evidence'
        AND auth.role() = 'authenticated'
    );

-- === place-photos ===
CREATE POLICY "place_photos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'place-photos');
CREATE POLICY "place_photos_insert_auth" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'place-photos'
        AND auth.role() = 'authenticated'
    );
```

---

# 6. Edge Functions TypeScript

## 6.1 validate-checkpoint

```typescript
// supabase/functions/validate-checkpoint/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ValidationRequest {
  raid_id: number
  checkpoint_id: number
  qr_code?: string
  latitude: number
  longitude: number
  photo_url?: string
  accuracy_meters?: number
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user }, error: authError } = await supabase.auth.getUser(
    authHeader?.replace('Bearer ', '')
  )
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const body: ValidationRequest = await req.json()
  const { raid_id, checkpoint_id, qr_code, latitude, longitude, photo_url, accuracy_meters } = body

  // 1. Verificar raid activo
  const { data: raid } = await supabase
    .from('raids').select('id, status, mode').eq('id', raid_id).single()

  if (!raid || raid.status !== 'active') {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'Raid no está activo'
    }), { status: 400 })
  }

  // 2. Verificar participación
  const { data: participant } = await supabase
    .from('raid_participants').select('id, checkpoints_taken')
    .eq('raid_id', raid_id).eq('user_id', user.id).single()

  if (!participant) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'No sos participante de este raid'
    }), { status: 403 })
  }

  // 3. Obtener checkpoint
  const { data: cp } = await supabase
    .from('raid_checkpoints').select('*').eq('id', checkpoint_id).single()

  if (!cp || cp.raid_id !== raid_id) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, message: 'Checkpoint no encontrado'
    }), { status: 404 })
  }

  // 4. Validar distancia con háversine
  const { data: distResult } = await supabase.rpc('haversine_distance', {
    lat1: latitude, lng1: longitude,
    lat2: cp.lat, lng2: cp.lng
  })
  const distance = distResult as number || 999999

  if (distance > cp.radius_meters) {
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, distance_meters: distance,
      message: `Muy lejos del checkpoint (${Math.round(distance)}m, máximo ${cp.radius_meters}m)`
    }), { status: 200 })
  }

  // 5. Validar QR si aplica
  if (cp.qr_code && qr_code !== cp.qr_code) {
    // Anti-cheat: log failed QR attempt
    await supabase.from('anti_cheat_log').insert({
      raid_participant_id: participant.id,
      checkpoint_id: cp.id,
      check_type: 'qr_replay',
      passed: false,
      details: { provided_qr: qr_code, expected_qr: '***' }
    })
    return new Response(JSON.stringify({
      valid: false, xp_awarded: 0, distance_meters: distance,
      message: 'Código QR incorrecto'
    }), { status: 200 })
  }

  // 6. Anti-cheat: validar velocidad entre checkpoints
  if (participant.checkpoints_taken > 0) {
    const { data: lastVerification } = await supabase
      .from('raid_checkpoint_verifications')
      .select('verified_at, lat, lng')
      .eq('raid_participant_id', participant.id)
      .order('verified_at', { ascending: false })
      .limit(1)
      .single()

    if (lastVerification) {
      const { data: prevDist } = await supabase.rpc('haversine_distance', {
        lat1: lastVerification.lat, lng1: lastVerification.lng,
        lat2: latitude, lng2: longitude
      })
      const distanceKm = (prevDist as number || 0) / 1000
      const timeHours = (new Date().getTime() - new Date(lastVerification.verified_at).getTime()) / 3600000
      const speedKmh = timeHours > 0 ? distanceKm / timeHours : 0

      if (speedKmh > 300) {
        await supabase.from('anti_cheat_log').insert({
          raid_participant_id: participant.id,
          checkpoint_id: cp.id,
          check_type: 'speed',
          passed: false,
          details: { speed_kmh: speedKmh, distance_km: distanceKm, time_hours: timeHours }
        })
        // Increment flags
        const { data: rp } = await supabase
          .from('raid_participants')
          .select('anti_cheat_flags')
          .eq('id', participant.id)
          .single()
        const newFlags = (rp?.anti_cheat_flags || 0) + 1
        const updateData: any = { anti_cheat_flags: newFlags }
        if (newFlags >= 2) updateData.is_flagged = true
        await supabase.from('raid_participants').update(updateData).eq('id', participant.id)

        return new Response(JSON.stringify({
          valid: false, xp_awarded: 0, distance_meters: distance,
          message: 'Velocidad imposible detectada'
        }), { status: 200 })
      }
    }
  }

  // 7. Insertar verificación
  const validationMethod = qr_code ? 'gps+qr' : (photo_url ? 'gps+photo' : 'gps')
  const { error: verifError } = await supabase.from('raid_checkpoint_verifications').upsert({
    raid_participant_id: participant.id,
    checkpoint_id: cp.id,
    photo_url: photo_url || null,
    lat: latitude,
    lng: longitude,
    accuracy_meters: accuracy_meters || null,
    qr_scanned: !!qr_code,
    is_valid: true,
    validation_method: validationMethod
  })

  if (verifError) {
    if (verifError.message?.includes('unique') || verifError.code === '23505') {
      return new Response(JSON.stringify({
        valid: false, xp_awarded: 0, distance_meters: distance,
        message: 'Ya capturaste este checkpoint anteriormente'
      }), { status: 200 })
    }
    throw verifError
  }

  // 8. Actualizar contador de checkpoints
  await supabase.rpc('increment_checkpoints', { p_participant_id: participant.id })

  // 9. Calcular XP
  let xpAwarded = 30  // base por checkpoint
  if (cp.is_hidden) xpAwarded += 30  // bonus checkpoint oculto (Ruta Gótica)
  if (photo_url) xpAwarded += 10     // bonus por foto

  await supabase.rpc('award_xp', { p_user_id: user.id, p_xp: xpAwarded })

  return new Response(JSON.stringify({
    valid: true,
    xp_awarded: xpAwarded,
    distance_meters: distance,
    message: 'Checkpoint validado ✓'
  }), { status: 200 })
})
```

## 6.2 finish-raid

```typescript
// supabase/functions/finish-raid/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { raid_id } = await req.json()

  // 1. Verificar que soy host
  const { data: raid } = await supabase
    .from('raids').select('*, host_id, mode, status, is_night_raid')
    .eq('id', raid_id).single()

  if (!raid) return new Response(JSON.stringify({ error: 'Raid no encontrado' }), { status: 404 })
  if (raid.host_id !== user.id) return new Response(JSON.stringify({ error: 'Solo el host puede finalizar' }), { status: 403 })
  if (raid.status !== 'active') return new Response(JSON.stringify({ error: 'Raid no está activo' }), { status: 400 })

  // 2. XP base por modo
  const xpTable: Record<string, number> = {
    free_ride: 10, rally: 25, ruta_gotica: 15,
    convoy: 15, sobrevivencia: 40, guerra_clanes: 20
  }
  const baseXp = xpTable[raid.mode] || 10

  // 3. Obtener total de checkpoints para bonus
  const { count: totalCheckpoints } = await supabase
    .from('raid_checkpoints')
    .select('*', { count: 'exact', head: true })
    .eq('raid_id', raid_id)

  // 4. Obtener participantes
  const { data: participants } = await supabase
    .from('raid_participants')
    .select('*, user_xp!inner(current_streak, last_raid_date)')
    .eq('raid_id', raid_id)

  let totalXpDistributed = 0
  let participantsCompleted = 0
  const participantResults: Array<{ user_id: string; xp_earned: number; position?: number }> = []
  const rallyTimes: Array<{ user_id: string; time_seconds: number }> = []

  for (const p of participants || []) {
    if (!p.is_completed) continue

    let xp = baseXp
    const streak = p.user_xp?.current_streak || 0
    const lastDate = p.user_xp?.last_raid_date

    // Bonus: todos los checkpoints
    if (totalCheckpoints && p.checkpoints_taken >= totalCheckpoints) {
      xp += 50
    }

    // Bonus: primer raid del día
    if (!lastDate || lastDate < new Date().toISOString().slice(0, 10)) {
      xp += 20
    }

    // Multiplicador de racha
    if (streak >= 7) xp *= 3
    else if (streak >= 3) xp *= 2

    // Bonus nocturno (+15%)
    if (raid.is_night_raid) xp = Math.round(xp * 1.15)

    // Rally: guardar tiempo para clasificación
    if (raid.mode === 'rally') {
      rallyTimes.push({ user_id: p.user_id, time_seconds: p.time_seconds })
    }

    // Anti-cheat: si está flagged, retener XP
    if (p.is_flagged) {
      xp = 0
    }

    // Otorgar XP
    if (xp > 0) {
      await supabase.rpc('award_xp', { p_user_id: p.user_id, p_xp: xp })
      await supabase.from('raid_participants')
        .update({ xp_earned: xp })
        .eq('id', p.id)
    }

    // Actualizar km_traveled en user_xp
    if (p.km_traveled > 0) {
      await supabase.rpc('update_km_traveled', {
        p_user_id: p.user_id,
        p_km: p.km_traveled
      })
    }

    totalXpDistributed += xp
    participantsCompleted++
    participantResults.push({ user_id: p.user_id, xp_earned: xp })
  }

  // 5. Rally: asignar posiciones por precisión ETA
  if (raid.mode === 'rally' && rallyTimes.length > 0 && raid.adjusted_eta) {
    const targetSeconds = Math.abs(new Date(raid.adjusted_eta).getTime() - new Date(raid.scheduled_at).getTime()) / 1000
    
    rallyTimes.sort((a, b) => 
      Math.abs(a.time_seconds - targetSeconds) - Math.abs(b.time_seconds - targetSeconds)
    )

    for (let i = 0; i < rallyTimes.length; i++) {
      await supabase.from('raid_participants')
        .update({ finished_position: i + 1 })
        .eq('raid_id', raid_id)
        .eq('user_id', rallyTimes[i].user_id)

      // Ganador recibe +50 XP extra
      if (i === 0) {
        await supabase.rpc('award_xp', { p_user_id: rallyTimes[i].user_id, p_xp: 50 })
      }
    }
  }

  // 6. Marcar raid como completado
  await supabase.from('raids').update({
    status: 'completed',
    updated_at: new Date().toISOString()
  }).eq('id', raid_id)

  // 7. Generar snapshot de leaderboard (diario)
  await generateLeaderboardSnapshot(supabase, 'general')

  return new Response(JSON.stringify({
    completed: true,
    xp_distributed: totalXpDistributed,
    participants_completed: participantsCompleted
  }), { status: 200 })
})

async function generateLeaderboardSnapshot(supabase: any, category: string) {
  const { data: rankings } = await supabase
    .from('user_xp')
    .select('user_id, total_xp')
    .gt('total_xp', 0)
    .order('total_xp', { ascending: false })
    .limit(100)

  if (!rankings) return

  const today = new Date().toISOString().slice(0, 10)
  const rows = rankings.map((r: any, i: number) => ({
    category,
    rank: i + 1,
    user_id: r.user_id,
    metric_value: r.total_xp,
    snapshot_date: today
  }))

  // Upsert
  for (const row of rows) {
    await supabase.from('leaderboard_snapshots').upsert(row, {
      onConflict: 'category,rank,snapshot_date'
    })
  }
}

// Edge Function register
serve(async (req) => {
  // ... same as above but with proper routing
  const url = new URL(req.url)
  if (url.pathname.includes('finish-raid')) {
    return await finishRaidHandler(req)
  }
  return new Response('Not Found', { status: 404 })
})

async function finishRaidHandler(req: Request) {
  // ... (reuse the handler above)
}
```

## 6.3 osm-import

```typescript
// supabase/functions/osm-import/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface OsmImportRequest {
  min_lat: number
  min_lng: number
  max_lat: number
  max_lng: number
  categories: string[]  // ['taller', 'hotel', 'reposteria', ...]
}

const OSM_CATEGORY_MAP: Record<string, { tag: string; value: string }> = {
  taller:     { tag: 'shop', value: 'car_repair' },
  restaurante: { tag: 'amenity', value: 'restaurant' },
  hotel:      { tag: 'tourism', value: 'hotel' },
  mirador:    { tag: 'tourism', value: 'viewpoint' },
  moto_posada: { tag: 'tourism', value: 'guest_house' },
  grua:       { tag: 'shop', value: 'car_parts' },
  reposteria: { tag: 'amenity', value: 'fuel' },
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  // Solo admin
  const { data: userData } = await supabase
    .from('users').select('id').eq('id', user.id).single()
  if (!userData) return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 })

  const body: OsmImportRequest = await req.json()
  const { min_lat, min_lng, max_lat, max_lng, categories } = body

  const bbox = `${min_lat},${min_lng},${max_lat},${max_lng}`

  // Construir query Overpass
  const queries = categories
    .filter(c => OSM_CATEGORY_MAP[c])
    .map(c => {
      const { tag, value } = OSM_CATEGORY_MAP[c]
      return `node["${tag}"="${value}"](${bbox});`
    })
    .join('\n')

  const overpassQuery = `[out:json][timeout:25];(\n${queries}\n);out body;`

  const overpassResp = await fetch('https://overpass-api.de/api/interpreter', {
    method: 'POST',
    body: `data=${encodeURIComponent(overpassQuery)}`
  })

  if (!overpassResp.ok) {
    return new Response(JSON.stringify({ error: 'Overpass API error' }), { status: 502 })
  }

  const overpassData = await overpassResp.json()
  const elements = overpassData.elements || []

  let imported = 0
  let skipped = 0

  for (const el of elements) {
    if (el.type !== 'node') continue

    const lat = el.lat
    const lng = el.lon
    const tags = el.tags || {}
    const name = tags.name || tags.operator || tags.brand || 'Sin nombre'

    // Determinar categoría AsfaltoClub
    let category = 'otro'
    for (const [acCategory, mapping] of Object.entries(OSM_CATEGORY_MAP)) {
      if (tags[mapping.tag] === mapping.value) {
        category = acCategory
        break
      }
    }

    // Verificar duplicado (lugar existente a < 50m)
    const { data: existing } = await supabase.rpc('get_nearby_places', {
      p_lat: lat,
      p_lng: lng,
      p_radius_meters: 50
    })

    if (existing && existing.length > 0) {
      skipped++
      continue
    }

    const qrToken = crypto.randomUUID().slice(0, 16)

    await supabase.from('places').insert({
      name: name.slice(0, 255),
      category,
      latitude: lat,
      longitude: lng,
      qr_token: qrToken,
      address: tags['addr:full'] || `${tags['addr:street'] || ''} ${tags['addr:housenumber'] || ''}`.trim() || null,
      city: tags['addr:city'] || null,
      department: tags['addr:state'] || null,
      created_by: user.id
    })

    imported++
  }

  return new Response(JSON.stringify({
    imported,
    skipped,
    total_found: elements.length
  }), { status: 200 })
})
```

## 6.4 get-route-weather

```typescript
// supabase/functions/get-route-weather/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { origin_lat, origin_lng, dest_lat, dest_lng, departure_time, raid_id } = await req.json()
  const OPENWEATHER_KEY = Deno.env.get('OPENWEATHER_API_KEY')

  if (!OPENWEATHER_KEY) {
    return new Response(JSON.stringify({
      error: 'OpenWeather API key not configured',
      segments: [],
      adjusted_eta: null,
      weather_alerts: []
    }), { status: 200 })
  }

  // 1. Obtener ruta de OSRM
  const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${origin_lng},${origin_lat};${dest_lng},${dest_lat}?steps=true&geometries=geojson&overview=full`
  const osrmResp = await fetch(osrmUrl)
  const osrmData = await osrmResp.json()

  if (!osrmData.routes?.[0]) {
    return new Response(JSON.stringify({
      segments: [],
      adjusted_eta: null,
      weather_alerts: []
    }), { status: 200 })
  }

  const route = osrmData.routes[0]
  const coordinates = route.geometry.coordinates  // [lng, lat]
  const baseDuration = route.duration  // segundos

  // 2. Samplear waypoints cada ~10km
  const SAMPLE_INTERVAL = 10000  // metros
  let accumulatedDist = 0
  const waypoints: Array<{ lat: number; lng: number; dist: number }> = []

  for (let i = 0; i < coordinates.length - 1; i++) {
    const [lng1, lat1] = coordinates[i]
    const [lng2, lat2] = coordinates[i + 1]
    const segDist = haversineMeters(lat1, lng1, lat2, lng2)
    accumulatedDist += segDist

    if (accumulatedDist >= SAMPLE_INTERVAL || i === coordinates.length - 2) {
      waypoints.push({ lat: lat2, lng: lng2, dist: accumulatedDist })
      accumulatedDist = 0
    }
  }

  // 3. Consultar OpenWeather para cada waypoint
  const segments: Array<{ lat: number; lng: number; condition: string; temp: number; weather_id: number }> = []

  for (const wp of waypoints) {
    const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${wp.lat}&lon=${wp.lng}&appid=${OPENWEATHER_KEY}&units=metric&lang=es`
    try {
      const weatherResp = await fetch(weatherUrl)
      const weatherData = await weatherResp.json()
      segments.push({
        lat: wp.lat,
        lng: wp.lng,
        condition: weatherData.weather?.[0]?.description || 'despejado',
        temp: weatherData.main?.temp || 20,
        weather_id: weatherData.weather?.[0]?.id || 800
      })
    } catch {
      segments.push({ lat: wp.lat, lng: wp.lng, condition: 'desconocido', temp: 20, weather_id: 800 })
    }
  }

  // 4. Calcular ajuste ETA por clima
  let etaMultiplier = 1.0
  const weatherAlerts: string[] = []

  for (const seg of segments) {
    // OpenWeather condition codes: https://openweathermap.org/weather-conditions
    if (seg.weather_id >= 200 && seg.weather_id < 300) {
      // Thunderstorm
      etaMultiplier = Math.max(etaMultiplier, 1.35)
      weatherAlerts.push('Tormenta eléctrica en la ruta')
    } else if (seg.weather_id >= 300 && seg.weather_id < 400) {
      etaMultiplier = Math.max(etaMultiplier, 1.15)  // Drizzle
    } else if (seg.weather_id >= 500 && seg.weather_id < 510) {
      etaMultiplier = Math.max(etaMultiplier, 1.15)  // Light rain
    } else if (seg.weather_id >= 510 && seg.weather_id < 600) {
      etaMultiplier = Math.max(etaMultiplier, 1.25)  // Heavy rain
      weatherAlerts.push('Lluvia fuerte en la ruta')
    } else if (seg.weather_id >= 600 && seg.weather_id < 700) {
      etaMultiplier = Math.max(etaMultiplier, 1.35)  // Snow
      weatherAlerts.push('Nieve/hielo en la ruta')
    } else if (seg.weather_id === 741) {
      etaMultiplier = Math.max(etaMultiplier, 1.20)  // Fog
      weatherAlerts.push('Niebla densa en la ruta')
    } else if (seg.weather_id >= 800 && seg.weather_id < 900) {
      // Clouds — minimal impact
    }
  }

  const adjustedDuration = Math.round(baseDuration * etaMultiplier)
  const adjustedEta = new Date(
    (departure_time ? new Date(departure_time).getTime() : Date.now()) + adjustedDuration * 1000
  ).toISOString()

  // 5. Guardar en raids si se proporcionó raid_id
  if (raid_id) {
    const weatherSummary = {
      segments,
      eta_multiplier: etaMultiplier,
      base_duration_seconds: baseDuration,
      adjusted_duration_seconds: adjustedDuration
    }
    await supabase.from('raids').update({
      weather_conditions: weatherSummary,
      adjusted_eta: adjustedEta,
      weather_checked_at: new Date().toISOString()
    }).eq('id', raid_id)
  }

  return new Response(JSON.stringify({
    segments,
    adjusted_eta: adjustedEta,
    base_duration_seconds: baseDuration,
    adjusted_duration_seconds: adjustedDuration,
    weather_alerts: weatherAlerts
  }), { status: 200 })
})

function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLng = (lng2 - lng1) * Math.PI / 180
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}
```

## 6.5 generate-replay

```typescript
// supabase/functions/generate-replay/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { raid_id } = await req.json()

  // Verificar que existe y está completado
  const { data: raid } = await supabase
    .from('raids').select('id, status').eq('id', raid_id).single()

  if (!raid || raid.status !== 'completed') {
    return new Response(JSON.stringify({ error: 'Raid no completado' }), { status: 400 })
  }

  // Obtener posiciones logueadas
  const { data: positionLogs } = await supabase
    .from('raid_position_log')
    .select('*, raid_participant!inner(user_id, raid_id)')
    .eq('raid_participant.raid_id', raid_id)
    .order('timestamp', { ascending: true })

  if (!positionLogs || positionLogs.length === 0) {
    return new Response(JSON.stringify({ error: 'Sin datos de posición' }), { status: 404 })
  }

  // Agrupar por participante y samplear (1 punto cada 5s para full, 30s para resumen)
  const participants: Record<string, any[]> = {}
  for (const log of positionLogs) {
    const pid = log.raid_participant_id
    if (!participants[pid]) participants[pid] = []
    participants[pid].push({
      lat: log.lat,
      lng: log.lng,
      heading: log.heading,
      speed: log.speed,
      timestamp: log.timestamp
    })
  }

  // Obtener checkpoints del raid
  const { data: checkpoints } = await supabase
    .from('raid_checkpoints')
    .select('*')
    .eq('raid_id', raid_id)
    .order('sort_order')

  // Obtener verificaciones
  const { data: verifications } = await supabase
    .from('raid_checkpoint_verifications')
    .select('*, raid_participant!inner(raid_id)')
    .eq('raid_participant.raid_id', raid_id)

  // Construir replay JSON
  const replayData = {
    raid_id,
    generated_at: new Date().toISOString(),
    total_participants: Object.keys(participants).length,
    total_points: positionLogs.length,
    participants: Object.entries(participants).map(([pid, points]) => ({
      participant_id: pid,
      points_count: points.length,
      avg_speed: points.reduce((s, p) => s + (p.speed || 0), 0) / points.length,
      max_speed: Math.max(...points.map(p => p.speed || 0)),
      track: points
    })),
    checkpoints: (checkpoints || []).map(cp => ({
      id: cp.id,
      name: cp.name,
      lat: cp.lat,
      lng: cp.lng,
      sort_order: cp.sort_order,
      captured_by: (verifications || [])
        .filter(v => v.checkpoint_id === cp.id)
        .map(v => v.raid_participant_id)
    }))
  }

  // Guardar en Storage
  const fileName = `replays/${raid_id}/${Date.now()}.json`
  const { data: storageData, error: storageError } = await supabase
    .storage
    .from('checkpoint-evidence')  // re-using bucket for replays
    .upload(fileName, JSON.stringify(replayData), {
      contentType: 'application/json',
      upsert: true
    })

  if (storageError) throw storageError

  const { data: publicUrl } = supabase.storage
    .from('checkpoint-evidence')
    .getPublicUrl(fileName)

  return new Response(JSON.stringify({
    replay_url: publicUrl.publicUrl,
    points_count: positionLogs.length,
    participants_count: Object.keys(participants).length
  }), { status: 200 })
})
```

## 6.6 on-raid-start (LiveKit + notificaciones)

```typescript
// supabase/functions/on-raid-start/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AccessToken } from 'https://esm.sh/livekit-server-sdk@2.8.0'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { raid_id } = await req.json()

  // Verificar raid y host
  const { data: raid } = await supabase
    .from('raids').select('*, host_id, mode, status, scheduled_at')
    .eq('id', raid_id).single()

  if (!raid || raid.host_id !== user.id) {
    return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 })
  }

  // Cambiar status a active
  await supabase.from('raids').update({
    status: 'active',
    updated_at: new Date().toISOString()
  }).eq('id', raid_id)

  // Obtener participantes
  const { data: participants } = await supabase
    .from('raid_participants')
    .select('*, users!inner(username)')
    .eq('raid_id', raid_id)

  const roomName = `raid-${raid_id}`

  // LiveKit: crear room
  const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY')
  const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET')
  const LIVEKIT_HOST = Deno.env.get('LIVEKIT_HOST') || 'https://livekit.example.com'

  if (LIVEKIT_API_KEY && LIVEKIT_API_SECRET) {
    try {
      // Crear room vía LiveKit API
      await fetch(`${LIVEKIT_HOST}/api/v1/rooms`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${LIVEKIT_API_KEY}`
        },
        body: JSON.stringify({
          name: roomName,
          max_participants: raid.max_participants || 20
        })
      })

      // Generar tokens para cada participante
      for (const p of participants || []) {
        const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
          identity: p.user_id,
          name: p.users?.username || 'Rider'
        })
        at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true })
        const token = await at.toJwt()

        await supabase.from('raid_participants').update({
          livekit_token: token,
          livekit_room: roomName
        }).eq('id', p.id)
      }

      // Guardar voice channel
      await supabase.from('voice_channels').insert({
        raid_id,
        livekit_room: roomName,
        is_active: true,
        max_participants: raid.max_participants || 20
      })
    } catch (err) {
      console.error('LiveKit error:', err)
      // Fallback: raid continúa sin voz
    }
  }

  // Enviar notificaciones push / Realtime a participantes
  for (const p of participants || []) {
    try {
      await supabase.channel(`user:${p.user_id}:notifications`).send({
        type: 'broadcast',
        event: 'raid_started',
        payload: {
          raid_id,
          mode: raid.mode,
          started_at: new Date().toISOString()
        }
      })
    } catch {
      // Notificación no crítica
    }
  }

  // Consultar clima si no se hizo antes
  if (!raid.weather_checked_at) {
    try {
      await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/get-route-weather`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
        },
        body: JSON.stringify({
          raid_id,
          origin_lat: raid.origin_lat,
          origin_lng: raid.origin_lng,
          dest_lat: raid.dest_lat,
          dest_lng: raid.dest_lng,
          departure_time: new Date().toISOString()
        })
      })
    } catch {
      // Weather no crítico
    }
  }

  return new Response(JSON.stringify({
    started: true,
    room_name: roomName,
    participants_count: participants?.length || 0
  }), { status: 200 })
})
```

## 6.7 tts (Text-to-Speech)

```typescript
// supabase/functions/tts/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const url = new URL(req.url)
  const text = url.searchParams.get('text') || 'Hola'
  const lang = url.searchParams.get('lang') || 'es-ES'

  // Cache key
  const cacheKey = `tts/${lang}/${crypto.randomUUID().slice(0, 8)}_${text.slice(0, 40).replace(/[^a-zA-Z0-9]/g, '_')}.mp3`

  // Verificar cache en Storage
  const { data: existingFiles } = await supabase.storage
    .from('checkpoint-evidence')
    .list('tts', { search: text.slice(0, 30) })

  if (existingFiles && existingFiles.length > 0) {
    const { data: publicUrl } = supabase.storage
      .from('checkpoint-evidence')
      .getPublicUrl(`tts/${existingFiles[0].name}`)
    return new Response(JSON.stringify({ url: publicUrl.publicUrl, cached: true }))
  }

  // Llamar a Google Cloud TTS
  const GOOGLE_API_KEY = Deno.env.get('GOOGLE_CLOUD_TTS_API_KEY')
  if (!GOOGLE_API_KEY) {
    return new Response(JSON.stringify({ error: 'TTS not configured' }), { status: 501 })
  }

  const ttsResponse = await fetch(
    `https://texttospeech.googleapis.com/v1/text:synthesize?key=${GOOGLE_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: lang, name: lang === 'es-ES' ? 'es-ES-Standard-A' : 'en-US-Standard-A' },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 1.1 }
      })
    }
  )

  if (!ttsResponse.ok) {
    return new Response(JSON.stringify({ error: 'TTS API error' }), { status: 502 })
  }

  const ttsData = await ttsResponse.json()
  const audioContent = ttsData.audioContent  // base64

  // Decodificar y subir a Storage
  const audioBytes = Uint8Array.from(atob(audioContent), c => c.charCodeAt(0))
  await supabase.storage
    .from('checkpoint-evidence')
    .upload(cacheKey, audioBytes, {
      contentType: 'audio/mpeg',
      upsert: false
    })

  const { data: publicUrl } = supabase.storage
    .from('checkpoint-evidence')
    .getPublicUrl(cacheKey)

  return new Response(JSON.stringify({
    url: publicUrl.publicUrl,
    cached: false,
    text,
    lang
  }), { status: 200 })
})
```

## 6.8 grant-voice-access (LiveKit JWT)

```typescript
// supabase/functions/grant-voice-access/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AccessToken } from 'https://esm.sh/livekit-server-sdk@2.8.0'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user } } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { room_name } = await req.json()

  const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY')
  const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET')

  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
    return new Response(JSON.stringify({ error: 'LiveKit not configured' }), { status: 501 })
  }

  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: user.id,
    // name from users table could be fetched here
  })
  at.addGrant({ roomJoin: true, room: room_name, canPublish: true, canSubscribe: true })
  const token = await at.toJwt()

  return new Response(JSON.stringify({ token, room: room_name }), { status: 200 })
})
```

---

# 7. Realtime Channels

## 7.1 Definición de Canales

### raid:{raid_id}:positions
| Propiedad | Valor |
|-----------|-------|
| Tipo | Broadcast (sin persistencia DB) |
| Payload | `{ user_id, lat, lng, heading, speed_kmh, timestamp }` |
| Frecuencia | Cada 5 segundos por participante |
| selfBroadcast | `false` (no recibir propia posición) |
| Compresión | Claves cortas: `{ p, lt, ln, h, s, ts }` |
| Acceso | Solo participantes del raid activo |

### raid:{raid_id}:chat
| Propiedad | Valor |
|-----------|-------|
| Tipo | Broadcast + DB (raid_messages) |
| Eventos | `message` (text/ping/system) |
| Payload | `{ id, user_id, message, type, lat?, lng?, created_at }` |
| Acceso | Solo participantes del raid |

### raid:{raid_id}:lobby
| Propiedad | Valor |
|-----------|-------|
| Tipo | Broadcast |
| Eventos | `user_joined`, `user_left`, `ready_changed`, `raid_started` |
| Payload | `{ event, payload: { user_id, username?, is_ready? } }` |
| Acceso | Solo participantes del raid |

### clan:{clan_id}:chat
| Propiedad | Valor |
|-----------|-------|
| Tipo | Broadcast + DB (clan_messages) |
| Eventos | `message` |
| Payload | `{ id, user_id, message, created_at }` |
| Acceso | Solo miembros del clan |

### user:{user_id}:notifications
| Propiedad | Valor |
|-----------|-------|
| Tipo | Broadcast |
| Eventos | `raid_invitation`, `clan_invitation`, `raid_starting_soon`, `sos_alert` |
| Payload | Variable según evento |
| Acceso | Solo el usuario destino |

## 7.2 Configuración Supabase

```sql
-- Habilitado en migración 004:
-- ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE clan_messages;
```

## 7.3 Suscripción desde Flutter

```dart
// === Canal de posiciones (Broadcast) ===
final positionsChannel = supabase.channel(
  'raid:${raidId}:positions',
  opts: const RealtimeChannelConfig(
    broadcast: BroadcastOptions(ack: true, selfBroadcast: false),
  ),
);

positionsChannel.on('broadcast', {event: 'position'}, (payload) {
  // payload claves cortas: p, lt, ln, h, s, ts
  emit(LiveMapPositionUpdated(
    userId: payload['p'],
    lat: payload['lt'],
    lng: payload['ln'],
    heading: payload['h'],
    speedKmh: payload['s'],
    timestamp: payload['ts'],
  ));
});

// Enviar posición cada 5 segundos
Timer.periodic(const Duration(seconds: 5), (_) async {
  final pos = await Geolocator.getCurrentPosition();
  positionsChannel.send(
    type: RealtimeSendType.Broadcast,
    event: 'position',
    payload: {
      'p': userId,
      'lt': pos.latitude,
      'ln': pos.longitude,
      'h': pos.heading ?? 0,
      's': (pos.speed ?? 0) * 3.6,
      'ts': DateTime.now().toIso8601String(),
    },
  );
});
positionsChannel.subscribe();

// === Canal de chat de raid ===
final raidChatChannel = supabase.channel('raid:${raidId}:chat');
raidChatChannel.on('broadcast', {event: 'message'}, (payload) {
  emit(RaidMessageReceived(payload));
});
raidChatChannel.subscribe();

// Enviar mensaje — INSERT en DB, Realtime replica automáticamente
await supabase.from('raid_messages').insert({
  'raid_id': raidId,
  'user_id': userId,
  'message': text,
  'type': 'text',
});

// === Canal de lobby ===
final lobbyChannel = supabase.channel('raid:${raidId}:lobby');
lobbyChannel.on('broadcast', {event: 'ready_changed'}, (payload) {
  emit(LobbyParticipantReadyChanged(payload));
});
lobbyChannel.on('broadcast', {event: 'user_joined'}, (payload) {
  emit(LobbyParticipantJoined(payload));
});
lobbyChannel.on('broadcast', {event: 'user_left'}, (payload) {
  emit(LobbyParticipantLeft(payload));
});
lobbyChannel.on('broadcast', {event: 'raid_started'}, (payload) {
  emit(RaidStarted(payload));
});
lobbyChannel.subscribe();

// === Canal de chat de clan ===
final clanChatChannel = supabase.channel('clan:${clanId}:chat');
clanChatChannel.on('broadcast', {event: 'message'}, (payload) {
  emit(ClanMessageReceived(payload));
});
clanChatChannel.subscribe();

// === Canal de notificaciones del usuario ===
final notifChannel = supabase.channel('user:${userId}:notifications');
notifChannel.on('broadcast', {event: 'raid_invitation'}, (payload) {
  emit(RaidInvitationReceived(payload));
});
notifChannel.on('broadcast', {event: 'sos_alert'}, (payload) {
  emit(SosAlertReceived(payload));
});
notifChannel.subscribe();
```

---

# 8. LiveKit Integration

## 8.1 Arquitectura

```
┌──────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Flutter App     │────▶│  Supabase EF         │────▶│  LiveKit Server  │
│  livekit_client  │◀────│  on_raid_start       │◀────│  (rooms + tokens)│
└──────────────────┘     └─────────────────────┘     └──────────────────┘
       │                         │
       │  WebSocket (WSS)        │  REST API
       ▼                         ▼
┌──────────────────────────────────────────────────────────┐
│  LiveKit WebSocket (LiveKit Protocol)                     │
│  Canales: raid_voice:{raid_id}, clan_voice:{clan_id}     │
└──────────────────────────────────────────────────────────┘
```

## 8.2 Flujo de Conexión

1. **Raid → active**: Edge Function `on-raid-start` se ejecuta
2. Crea room en LiveKit: `POST /api/v1/rooms` con nombre `raid-{raid_id}`
3. Genera Access Token JWT para cada participante:
   - `identity`: user_id
   - `name`: username
   - `grants`: `{ roomJoin: true, room: "raid-{raid_id}", canPublish: true, canSubscribe: true }`
4. Tokens guardados en `raid_participants.livekit_token` y `livekit_room`
5. Cliente Flutter conecta usando `LiveKitClient.connect(url, token)`
6. Push-to-talk: micrófono deshabilitado por defecto, activado por botón Bluetooth/comando de voz

## 8.3 Tipos de Canales de Voz

| Canal | Ámbito | Creación | Acceso |
|-------|--------|----------|--------|
| `raid-{raid_id}` | Participantes del raid activo | Automática al iniciar raid | Solo participantes |
| `clan-{clan_id}` | Miembros del clan (24/7) | Bajo demanda | Solo miembros |
| `convoy-{raid_id}-{subgroup}` | Subgrupo dentro de raid | Por invitación | Solo invitados |

## 8.4 Flutter LiveKit Client

```dart
// Dependencia en pubspec.yaml:
//   livekit_client: ^2.6.0

class VoiceChatService {
  Room? _room;

  Future<void> connectToRaidVoice({
    required String livekitUrl,
    required String token,
  }) async {
    _room = Room();
    await _room!.connect(livekitUrl, token,
      roomOptions: const RoomOptions(
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );

    // Push-to-talk: micrófono apagado por defecto
    await _room!.localParticipant?.setMicrophoneEnabled(false);
  }

  void enableMicrophone() {
    _room?.localParticipant?.setMicrophoneEnabled(true);
  }

  void disableMicrophone() {
    _room?.localParticipant?.setMicrophoneEnabled(false);
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
  }
}
```

## 8.5 TTS Pipeline

```dart
class TtsService {
  final Map<String, String> _audioCache = {};  // event_key → url

  Future<void> playTts(String eventType, String text, {String lang = 'es-ES'}) async {
    final cacheKey = '${eventType}_${text.hashCode}';

    // 1. Buscar en cache local
    if (_audioCache.containsKey(cacheKey)) {
      await _playAudio(_audioCache[cacheKey]!);
      return;
    }

    // 2. Llamar Edge Function
    final response = await supabase.functions.invoke('tts', {
      'method': 'GET',
      'params': {'text': text, 'lang': lang},
    });

    if (response.data != null && response.data['url'] != null) {
      _audioCache[cacheKey] = response.data['url'];
      await _playAudio(response.data['url']);
    }
  }

  Future<void> _playAudio(String url) async {
    // Usar audioplayers o similar
    final player = AudioPlayer();
    await player.setSourceUrl(url);
    await player.resume();
  }

  /// Anuncios automáticos durante raid
  void onCheckpointNearby(int meters) {
    playTts('checkpoint_near', 'Checkpoint a $meters metros en la ruta actual');
  }

  void onRiderOffRoute(String name) {
    playTts('rider_off', '$name se ha desviado de la ruta');
  }

  void onWeatherChange(String condition, String segment) {
    playTts('weather', '$condition prevista en el tramo $segment');
  }
}
```

---

# 9. Flutter Architecture

## 9.1 Dependencias (pubspec.yaml)

**Eliminar:**
```yaml
  dio: ^5.7.0
  flutter_secure_storage: ^10.3.1
  cloudinary_flutter: ^1.3.0
  firebase_core: ^4.11.0
  firebase_auth: ^6.5.4
  google_sign_in: ^7.2.0
  web_socket_channel: ^3.0.2
  provider: ^6.1.2
```

**Agregar:**
```yaml
  supabase_flutter: ^2.8.0
  livekit_client: ^2.6.0
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  flutter_background_service: ^5.0.0
  audioplayers: ^6.1.0
```

**Mantener:**
```yaml
  flutter_map: ^8.3.1
  geolocator: ^14.0.3
  mobile_scanner: ^7.2.0
  image_picker: ^1.2.3
  flutter_bloc: ^9.1.1
  equatable: ^2.0.8
  latlong2: ^0.9.1
  flutter_map_marker_cluster: ^8.2.2
  url_launcher: ^6.3.0
```

## 9.2 Inicialización (main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const MoterosApp());
}
```

## 9.3 Nuevos BLoCs

### RaidBloc
```dart
// lib/features/raid/presentation/bloc/raid_bloc.dart

enum RaidStatus { initial, loading, created, listLoaded, lobby, active, completed, error }

class RaidBloc extends Bloc<RaidEvent, RaidState> {
  final RaidRepository raidRepository;

  RaidBloc({required this.raidRepository}) : super(RaidInitial()) {
    on<CreateRaid>(_onCreateRaid);
    on<JoinRaid>(_onJoinRaid);
    on<LeaveRaid>(_onLeaveRaid);
    on<StartRaid>(_onStartRaid);
    on<CancelRaid>(_onCancelRaid);
    on<FinishRaid>(_onFinishRaid);
    on<LoadRaidList>(_onLoadRaidList);
    on<LoadMyRaids>(_onLoadMyRaids);
    on<UpdateReady>(_onUpdateReady);
  }

  Future<void> _onCreateRaid(CreateRaid event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final raid = await raidRepository.createRaid(event.raid);
      emit(RaidCreated(raid));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onJoinRaid(JoinRaid event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      await raidRepository.joinRaid(event.raidId);
      final raid = await raidRepository.getRaid(event.raidId);
      emit(RaidLobby(raid));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  // ... remaining handlers follow same pattern
}

// Events
sealed class RaidEvent extends Equatable {
  const RaidEvent();
  @override List<Object?> get props => [];
}

class CreateRaid extends RaidEvent { final RaidModel raid; const CreateRaid(this.raid); }
class JoinRaid extends RaidEvent { final int raidId; const JoinRaid(this.raidId); }
class LeaveRaid extends RaidEvent { final int raidId; const LeaveRaid(this.raidId); }
class StartRaid extends RaidEvent { final int raidId; const StartRaid(this.raidId); }
class CancelRaid extends RaidEvent { final int raidId; const CancelRaid(this.raidId); }
class FinishRaid extends RaidEvent { final int raidId; const FinishRaid(this.raidId); }
class LoadRaidList extends RaidEvent { const LoadRaidList(); }
class LoadMyRaids extends RaidEvent { const LoadMyRaids(); }
class UpdateReady extends RaidEvent { final int raidId; final bool isReady; const UpdateReady(this.raidId, this.isReady); }

// States
sealed class RaidState extends Equatable {
  const RaidState();
  @override List<Object?> get props => [];
}
class RaidInitial extends RaidState { const RaidInitial(); }
class RaidLoading extends RaidState { const RaidLoading(); }
class RaidCreated extends RaidState { final RaidModel raid; const RaidCreated(this.raid); }
class RaidListLoaded extends RaidState { final List<RaidModel> raids; const RaidListLoaded(this.raids); }
class RaidLobby extends RaidState { final RaidModel raid; const RaidLobby(this.raid); }
class RaidActive extends RaidState { final RaidModel raid; const RaidActive(this.raid); }
class RaidCompleted extends RaidState { final RaidModel raid; final List<RaidResultModel> results; const RaidCompleted(this.raid, this.results); }
class RaidError extends RaidState { final String message; const RaidError(this.message); }
```

### ClanBloc
```dart
// lib/features/clan/presentation/bloc/clan_bloc.dart
// Events: CreateClan, JoinClan, LeaveClan, UpdateRole, LoadClan, LoadMyClans, LoadClanMembers
// States: ClanInitial, ClanLoading, ClanLoaded, ClanListLoaded, ClanMembersLoaded, ClanError
```

### LiveMapBloc
```dart
// lib/features/live_map/presentation/bloc/live_map_bloc.dart
// Events: SubscribePositions, UnsubscribePositions, UpdateOwnPosition, PositionReceived, PingSent, WeatherChangeReceived
// States: LiveMapInitial, LiveMapSubscribed, LiveMapPositionUpdated, LiveMapError
```

### ProgressionBloc
```dart
// lib/features/progression/presentation/bloc/progression_bloc.dart
// Events: LoadProgression, LoadAchievements, LoadLeaderboard
// States: ProgressionInitial, ProgressionLoading, ProgressionLoaded, AchievementsLoaded, LeaderboardLoaded
```

### LeaderboardBloc
```dart
// lib/features/leaderboard/presentation/bloc/leaderboard_bloc.dart
// Events: LoadGeneral, LoadWeekly, LoadMonthly, LoadClanRankings
// States: LeaderboardInitial, LeaderboardLoading, LeaderboardLoaded
```

## 9.4 Nuevos DataSources

```dart
// lib/features/raid/data/datasources/raid_remote_datasource.dart

class RaidRemoteDataSource {
  final SupabaseClient supabase;

  RaidRemoteDataSource(this.supabase);

  Future<RaidModel> createRaid(RaidModel raid) async {
    final response = await supabase.from('raids').insert({
      'host_id': supabase.auth.currentUser!.id,
      'origin_lat': raid.originLat,
      'origin_lng': raid.originLng,
      'dest_lat': raid.destLat,
      'dest_lng': raid.destLng,
      'mode': raid.mode,
      'scheduled_at': raid.scheduledAt.toIso8601String(),
      'is_public': raid.isPublic,
      'max_participants': raid.maxParticipants,
      'description': raid.description,
      'clan_id': raid.clanId,
    }).select().single();

    return RaidModel.fromJson(response);
  }

  Future<void> joinRaid(int raidId) async {
    await supabase.from('raid_participants').insert({
      'raid_id': raidId,
      'user_id': supabase.auth.currentUser!.id,
    });
  }

  Future<RaidModel> getRaid(int raidId) async {
    final response = await supabase
      .from('raids')
      .select('*, raid_participants(*, users(username, profile_image))')
      .eq('id', raidId)
      .single();
    return RaidModel.fromJson(response);
  }

  Future<List<RaidModel>> getPublicRaids() async {
    final response = await supabase
      .from('raids')
      .select('*, raid_participants(count)')
      .eq('is_public', true)
      .in_('status', ['planned', 'lobby'])
      .order('scheduled_at');
    return (response as List).map((j) => RaidModel.fromJson(j)).toList();
  }

  Future<void> updateReady(int raidId, bool isReady) async {
    await supabase
      .from('raid_participants')
      .update({'is_ready': isReady})
      .eq('raid_id', raidId)
      .eq('user_id', supabase.auth.currentUser!.id);
  }

  Future<RaidResultModel> finishRaid(int raidId) async {
    final response = await supabase.functions.invoke('finish-raid', {
      'body': {'raid_id': raidId},
    });
    return RaidResultModel.fromJson(response.data);
  }

  Future<CheckpointValidationResult> validateCheckpoint({
    required int raidId,
    required int checkpointId,
    required double latitude,
    required double longitude,
    String? qrCode,
    String? photoUrl,
  }) async {
    final response = await supabase.functions.invoke('validate-checkpoint', {
      'body': {
        'raid_id': raidId,
        'checkpoint_id': checkpointId,
        'latitude': latitude,
        'longitude': longitude,
        'qr_code': qrCode,
        'photo_url': photoUrl,
      },
    });
    return CheckpointValidationResult.fromJson(response.data);
  }
}
```

## 9.5 Nuevos Modelos

```dart
// lib/features/raid/data/models/raid_model.dart
class RaidModel extends Equatable {
  final int id;
  final String hostId;
  final double originLat, originLng;
  final double destLat, destLng;
  final String mode;         // free_ride, rally, ruta_gotica, convoy, sobrevivencia, guerra_clanes
  final DateTime scheduledAt;
  final bool isPublic;
  final String status;       // planned, lobby, active, completed, cancelled
  final int? clanId;
  final int maxParticipants;
  final String? description;
  final Map<String, dynamic>? routeData;
  final bool isNightRaid;
  final bool allowSpectators;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RaidParticipantModel>? participants;

  const RaidModel({
    required this.id,
    required this.hostId,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.mode,
    required this.scheduledAt,
    required this.isPublic,
    required this.status,
    this.clanId,
    this.maxParticipants = 20,
    this.description,
    this.routeData,
    this.isNightRaid = false,
    this.allowSpectators = false,
    required this.createdAt,
    required this.updatedAt,
    this.participants,
  });

  factory RaidModel.fromJson(Map<String, dynamic> json) => RaidModel(
    id: json['id'],
    hostId: json['host_id'],
    originLat: (json['origin_lat'] as num).toDouble(),
    originLng: (json['origin_lng'] as num).toDouble(),
    destLat: (json['dest_lat'] as num).toDouble(),
    destLng: (json['dest_lng'] as num).toDouble(),
    mode: json['mode'],
    scheduledAt: DateTime.parse(json['scheduled_at']),
    isPublic: json['is_public'] ?? true,
    status: json['status'],
    clanId: json['clan_id'],
    maxParticipants: json['max_participants'] ?? 20,
    description: json['description'],
    routeData: json['route_data'],
    isNightRaid: json['is_night_raid'] ?? false,
    allowSpectators: json['allow_spectators'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
    participants: json['raid_participants'] != null
      ? (json['raid_participants'] as List).map((j) => RaidParticipantModel.fromJson(j)).toList()
      : null,
  );

  Map<String, dynamic> toJson() => {
    'host_id': hostId,
    'origin_lat': originLat,
    'origin_lng': originLng,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'mode': mode,
    'scheduled_at': scheduledAt.toIso8601String(),
    'is_public': isPublic,
    'max_participants': maxParticipants,
    'description': description,
    'clan_id': clanId,
  };

  @override List<Object?> get props => [id, hostId, status, mode, scheduledAt];
}

// lib/features/raid/data/models/raid_participant_model.dart
class RaidParticipantModel extends Equatable {
  final int id;
  final int raidId;
  final String userId;
  final DateTime joinedAt;
  final bool isReady;
  final int? finishedPosition;
  final int xpEarned;
  final double kmTraveled;
  final int timeSeconds;
  final int checkpointsTaken;
  final bool isCompleted;
  final double? lastLat, lastLng, lastHeading, lastSpeedKmh;
  final String? username, profileImage;

  const RaidParticipantModel({ /* all fields */ });

  factory RaidParticipantModel.fromJson(Map<String, dynamic> json) => RaidParticipantModel(
    id: json['id'],
    raidId: json['raid_id'],
    userId: json['user_id'],
    joinedAt: DateTime.parse(json['joined_at']),
    isReady: json['is_ready'] ?? false,
    finishedPosition: json['finished_position'],
    xpEarned: json['xp_earned'] ?? 0,
    kmTraveled: (json['km_traveled'] ?? 0).toDouble(),
    timeSeconds: json['time_seconds'] ?? 0,
    checkpointsTaken: json['checkpoints_taken'] ?? 0,
    isCompleted: json['is_completed'] ?? false,
    lastLat: (json['last_lat'] as num?)?.toDouble(),
    lastLng: (json['last_lng'] as num?)?.toDouble(),
    lastHeading: (json['last_heading'] as num?)?.toDouble(),
    lastSpeedKmh: (json['last_speed_kmh'] as num?)?.toDouble(),
    username: json['users'] is Map ? json['users']['username'] : null,
    profileImage: json['users'] is Map ? json['users']['profile_image'] : null,
  );

  @override List<Object?> get props => [id, userId, isReady, isCompleted];
}

// lib/features/clan/data/models/clan_model.dart
class ClanModel extends Equatable {
  final int id;
  final String name, tag;
  final String? description, logoUrl;
  final String founderId;
  final bool isPublic;
  final int maxMembers;
  final DateTime createdAt;

  factory ClanModel.fromJson(Map<String, dynamic> json) => ClanModel( /* ... */ );
  @override List<Object?> get props => [id, name, tag];
}

// lib/features/clan/data/models/clan_member_model.dart
class ClanMemberModel extends Equatable {
  final int id, clanId;
  final String userId, role;  // founder, captain, rider, recruit
  final DateTime joinedAt;
  final String? username, profileImage;

  factory ClanMemberModel.fromJson(Map<String, dynamic> json) => ClanMemberModel( /* ... */ );
}

// lib/features/raid/data/models/checkpoint_model.dart
class CheckpointModel extends Equatable {
  final int id, raidId;
  final int? placeId;
  final String name,? description;
  final double lat, lng;
  final int sortOrder;
  final bool isHidden;
  final String? qrCode;
  final double radiusMeters;

  factory CheckpointModel.fromJson(Map<String, dynamic> json) => CheckpointModel( /* ... */ );
}
```

## 9.6 Nuevas Rutas de Navegación

```
/main_shell (dashboard, mapa, refugios, challenges, perfil)
├── /raids — lista de raids disponibles / mis raids
│   ├── /raids/create — formulario de creación
│   ├── /raids/:id/lobby — lobby del raid
│   ├── /raids/:id/live — mapa en vivo durante raid activo
│   └── /raids/:id/results — post-raid stats
├── /clans
│   ├── /clans/create — formulario de creación
│   ├── /clans/:id — vista del clan (miembros, chat, stats)
│   └── /clans/:id/settings — configuración (fundador/capitán)
├── /leaderboard — rankings general, semanal, mensual, por clan
├── /profile/:id — perfil con XP, nivel, logros
└── /admin — panel de administración (solo role='admin')
```

## 9.7 Repository Pattern

```dart
// lib/features/raid/data/repositories/raid_repository_impl.dart
class RaidRepositoryImpl implements RaidRepository {
  final RaidRemoteDataSource remoteDataSource;
  final RaidLocalDataSource localDataSource;
  final SupabaseClient supabase;

  RaidRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.supabase,
  });

  @override
  Future<RaidModel> createRaid(RaidModel raid) async {
    final created = await remoteDataSource.createRaid(raid);
    // Auto-join as participant
    await remoteDataSource.joinRaid(created.id);
    return created;
  }

  @override
  Future<List<RaidModel>> getPublicRaids() async {
    return remoteDataSource.getPublicRaids();
  }

  @override
  Future<List<RaidModel>> getMyRaids() async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
      .from('raids')
      .select('*, raid_participants!inner(*)')
      .eq('raid_participants.user_id', userId)
      .order('scheduled_at', ascending: false);
    return (response as List).map((j) => RaidModel.fromJson(j)).toList();
  }

  @override
  Future<void> saveRaidLocally(RaidModel raid) async {
    await localDataSource.cacheRaid(raid);
  }

  @override
  Future<RaidModel?> getCachedRaid(int raidId) async {
    return localDataSource.getCachedRaid(raidId);
  }
}
```

## 9.8 DataSource Remoto (reemplazo de ApiClient)

```dart
// lib/features/raid/data/datasources/clan_remote_datasource.dart
class ClanRemoteDataSource {
  final SupabaseClient supabase;

  ClanRemoteDataSource(this.supabase);

  Future<ClanModel> createClan(ClanModel clan) async {
    final response = await supabase.from('clans').insert({
      'name': clan.name,
      'tag': clan.tag,
      'description': clan.description,
      'founder_id': supabase.auth.currentUser!.id,
      'is_public': clan.isPublic,
    }).select().single();

    // Auto-agregar como founder
    await supabase.from('clan_members').insert({
      'clan_id': response['id'],
      'user_id': supabase.auth.currentUser!.id,
      'role': 'founder',
    });

    return ClanModel.fromJson(response);
  }

  Future<List<ClanModel>> getPublicClans() async {
    final response = await supabase
      .from('clans')
      .select('*')
      .eq('is_public', true)
      .order('name');
    return (response as List).map((j) => ClanModel.fromJson(j)).toList();
  }

  Future<List<ClanMemberModel>> getClanMembers(int clanId) async {
    final response = await supabase
      .from('clan_members')
      .select('*, users(username, profile_image)')
      .eq('clan_id', clanId);
    return (response as List).map((j) => ClanMemberModel.fromJson(j)).toList();
  }

  Future<void> joinClan(int clanId) async {
    await supabase.from('clan_members').insert({
      'clan_id': clanId,
      'user_id': supabase.auth.currentUser!.id,
      'role': 'recruit',
    });
  }

  Future<void> updateMemberRole(int clanId, String userId, String newRole) async {
    await supabase
      .from('clan_members')
      .update({'role': newRole})
      .eq('clan_id', clanId)
      .eq('user_id', userId);
  }

  Future<void> removeMember(int clanId, String userId) async {
    await supabase
      .from('clan_members')
      .delete()
      .eq('clan_id', clanId)
      .eq('user_id', userId);
  }
}
```

---

# 10. Offline Cache Strategy

## 10.1 Arquitectura Offline-First

```
┌─────────────────────────────────────────────┐
│              FLUTTER APP                      │
│                                               │
│  ┌──────────────┐     ┌──────────────────┐   │
│  │  BLoCs        │────▶│  Repository      │   │
│  │  (RaidBloc,   │◀────│  (offline-first) │   │
│  │  LiveMapBloc) │     └───┬──────┬───────┘   │
│  └──────────────┘         │      │           │
│                           ▼      ▼           │
│               ┌────────────┐ ┌────────────┐  │
│               │ Supabase   │ │ SQLite     │  │
│               │ (Remote)   │ │ (Drift)    │  │
│               └────────────┘ └────────────┘  │
└─────────────────────────────────────────────┘
```

## 10.2 Tablas Locales (Drift/SQLite)

```dart
// lib/core/cache/local_database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// -- Definición de tablas locales --

class LocalPositionBuffer extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get raidParticipantId => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get heading => real().nullable()();
  RealColumn get speed => real().nullable()();
  TextColumn get timestamp => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

class CachedRaid extends Table {
  IntColumn get raidId => integer()();
  TextColumn get jsonData => text()();  // RaidModel serialized
  TextColumn get cachedAt => text()();
  
  @override
  Set<Column> get primaryKey => {raidId};
}

class CachedProfile extends Table {
  TextColumn get userId => text()();
  TextColumn get jsonData => text()();
  TextColumn get cachedAt => text()();
  
  @override
  Set<Column> get primaryKey => {userId};
}

class PendingChatMessage extends Table {
  IntColumn get id => integer().autoincrement()();
  TextColumn get channelType => text()();  // 'raid' or 'clan'
  IntColumn get channelId => integer()();   // raid_id or clan_id
  TextColumn get userId => text()();
  TextColumn get message => text()();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get createdAt => text()();
}

// -- Database --
@DriftDatabase(tables: [LocalPositionBuffer, CachedRaid, CachedProfile, PendingChatMessage])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return NativeDatabase(/* path from getApplicationDocumentsDirectory */);
  }

  // Position buffer
  Future<void> bufferPosition(LocalPositionBufferCompanion entry) async {
    await into(localPositionBuffer).insert(entry);
  }

  Future<List<LocalPositionBuffer>> getUnsyncedPositions() async {
    return (select(localPositionBuffer)..where((t) => t.isSynced.equals(false))).get();
  }

  Future<void> markPositionsSynced(List<int> ids) async {
    await (update(localPositionBuffer)..where((t) => t.id.isIn(ids)))
      .write(const LocalPositionBufferCompanion(isSynced: Value(true)));
  }

  // Raid cache
  Future<void> cacheRaid(RaidModel raid) async {
    await into(cachedRaid).insertOnConflictUpdate(
      CachedRaidCompanion(
        raidId: Value(raid.id),
        jsonData: Value(raid.toJson().toString()),
        cachedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<RaidModel?> getCachedRaid(int raidId) async {
    final row = await (select(cachedRaid)..where((t) => t.raidId.equals(raidId))).getSingleOrNull();
    if (row == null) return null;
    return RaidModel.fromJson(Map<String, dynamic>.from(row.jsonData as Map));
  }

  // Profile cache
  Future<void> cacheProfile(Map<String, dynamic> profile) async {
    await into(cachedProfile).insertOnConflictUpdate(
      CachedProfileCompanion(
        userId: Value(profile['id']),
        jsonData: Value(profile.toString()),
        cachedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<Map<String, dynamic>?> getCachedProfile(String userId) async {
    final row = await (select(cachedProfile)..where((t) => t.userId.equals(userId))).getSingleOrNull();
    if (row == null) return null;
    return Map<String, dynamic>.from(row.jsonData as Map);
  }

  // Pending messages
  Future<void> bufferMessage(PendingChatMessageCompanion msg) async {
    await into(pendingChatMessage).insert(msg);
  }

  Future<List<PendingChatMessage>> getPendingMessages() async {
    return select(pendingChatMessage).get();
  }

  Future<void> deletePendingMessage(int id) async {
    await (delete(pendingChatMessage)..where((t) => t.id.equals(id))).go();
  }
}
```

## 10.3 Connectivity Service

```dart
// lib/core/network/connectivity_service.dart
class ConnectivityService {
  bool _isOnline = true;
  final LocalDatabase _localDb;

  ConnectivityService(this._localDb);

  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _connectivityStream();

  Stream<bool> _connectivityStream() async* {
    while (true) {
      try {
        final result = await InternetAddress.lookup('supabase.co');
        _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        _isOnline = false;
      }
      yield _isOnline;
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  Future<void> syncPendingData() async {
    if (!_isOnline) return;

    // 1. Sync pending positions
    final unsyncedPos = await _localDb.getUnsyncedPositions();
    if (unsyncedPos.isNotEmpty) {
      for (final pos in unsyncedPos) {
        try {
          await supabase.from('raid_position_log').insert({
            'raid_participant_id': pos.raidParticipantId,
            'lat': pos.lat,
            'lng': pos.lng,
            'heading': pos.heading,
            'speed': pos.speed,
            'timestamp': pos.timestamp,
          });
        } catch (_) {
          // Skip failed — will retry next sync
        }
      }
      await _localDb.markPositionsSynced(unsyncedPos.map((p) => p.id).toList());
    }

    // 2. Sync pending chat messages
    final pendingMsgs = await _localDb.getPendingMessages();
    for (final msg in pendingMsgs) {
      try {
        if (msg.channelType == 'raid') {
          await supabase.from('raid_messages').insert({
            'raid_id': msg.channelId,
            'user_id': msg.userId,
            'message': msg.message,
            'type': msg.messageType,
          });
        } else {
          await supabase.from('clan_messages').insert({
            'clan_id': msg.channelId,
            'user_id': msg.userId,
            'message': msg.message,
          });
        }
        await _localDb.deletePendingMessage(msg.id);
      } catch (_) {
        // Will retry
      }
    }

    // 3. Sync pending checkpoint verifications (if any — stored offline)
    // Handled by the checkpoint validation flow
  }
}
```

## 10.4 GPS Offline Buffer

```dart
// lib/features/live_map/data/services/offline_gps_buffer.dart
class OfflineGpsBufferService {
  final LocalDatabase _localDb;
  final ConnectivityService _connectivity;

  OfflineGpsBufferService(this._localDb, this._connectivity);

  Future<void> recordPosition({
    required int participantId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    await _localDb.bufferPosition(
      LocalPositionBufferCompanion(
        raidParticipantId: Value(participantId.toString()),
        lat: Value(lat),
        lng: Value(lng),
        heading: Value(heading),
        speed: Value(speed),
        timestamp: Value(DateTime.now().toIso8601String()),
        isSynced: const Value(false),
      ),
    );

    // También insertar en raid_position_log si estamos online
    if (_connectivity.isOnline) {
      try {
        await supabase.from('raid_position_log').insert({
          'raid_participant_id': participantId,
          'lat': lat,
          'lng': lng,
          'heading': heading,
          'speed': speed,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _localDb.markPositionsSynced([/* last inserted id */]);
      } catch (_) {
        // Falló — se sincronizará después
      }
    }
  }
}
```

## 10.5 Estrategia de Cache por Tipo de Dato

| Dato | Estrategia | TTL | Prioridad |
|------|-----------|-----|-----------|
| Posiciones GPS | Buffer local, sync eventual | Hasta sync | Alta |
| Perfil del usuario | Cache local con refresh on login | 1 hora | Alta |
| Últimos mensajes de chat | Cache local FIFO (50 msgs) | Persistente | Media |
| Raids activos (datos) | Cache local con stale-while-revalidate | 5 min | Alta |
| Checkpoints del raid | Cache local precargado al entrar al raid | Hasta fin raid | Alta |
| Lugares cercanos | Cache local con bounding box | 30 min | Baja |
| Logros/achievements | Cache local con refresh on XP change | 5 min | Media |
| Leaderboards | Cache local con pull-to-refresh | 1 hora | Baja |
| Audio TTS | File system cache por hash de texto | Persistente | Media |

---

# 11. Archivos a Crear/Eliminar

## 11.1 Archivos NUEVOS

```
lib/
├── core/
│   ├── cache/
│   │   ├── local_database.dart              # Drift database definition
│   │   └── local_database.g.dart            # Generated by drift
│   ├── network/
│   │   └── connectivity_service.dart        # Online/offline detection
│   └── services/
│       ├── voice_chat_service.dart           # LiveKit voice service
│       └── tts_service.dart                  # TTS pipeline
├── features/
│   ├── raid/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── raid_remote_datasource.dart
│   │   │   │   └── raid_local_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── raid_model.dart
│   │   │   │   ├── raid_participant_model.dart
│   │   │   │   ├── raid_result_model.dart
│   │   │   │   └── checkpoint_model.dart
│   │   │   └── repositories/
│   │   │       └── raid_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── raid.dart
│   │   │   │   ├── raid_participant.dart
│   │   │   │   └── checkpoint.dart
│   │   │   ├── repositories/
│   │   │   │   └── raid_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_raid.dart
│   │   │       ├── join_raid.dart
│   │   │       ├── leave_raid.dart
│   │   │       ├── start_raid.dart
│   │   │       ├── finish_raid.dart
│   │   │       └── validate_checkpoint.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── raid_bloc.dart
│   │       │   ├── raid_event.dart
│   │       │   └── raid_state.dart
│   │       └── screens/
│   │           ├── raid_list_screen.dart
│   │           ├── create_raid_screen.dart
│   │           ├── raid_lobby_screen.dart
│   │           ├── raid_live_screen.dart
│   │           └── raid_results_screen.dart
│   ├── clan/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── clan_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   ├── clan_model.dart
│   │   │   │   └── clan_member_model.dart
│   │   │   └── repositories/
│   │   │       └── clan_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── clan.dart
│   │   │   │   └── clan_member.dart
│   │   │   ├── repositories/
│   │   │   │   └── clan_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_clan.dart
│   │   │       ├── join_clan.dart
│   │   │       ├── leave_clan.dart
│   │   │       └── update_member_role.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── clan_bloc.dart
│   │       │   ├── clan_event.dart
│   │       │   └── clan_state.dart
│   │       └── screens/
│   │           ├── clan_list_screen.dart
│   │           ├── clan_detail_screen.dart
│   │           ├── create_clan_screen.dart
│   │           └── clan_settings_screen.dart
│   ├── live_map/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── live_map_datasource.dart
│   │   │   └── services/
│   │   │       └── offline_gps_buffer.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── live_map_bloc.dart
│   │       │   ├── live_map_event.dart
│   │       │   └── live_map_state.dart
│   │       └── widgets/
│   │           ├── raid_marker.dart
│   │           ├── speed_color_indicator.dart
│   │           └── ping_overlay.dart
│   ├── progression/
│   │   ├── data/
│   │   │   └── datasources/
│   │   │       └── progression_datasource.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── progression_bloc.dart
│   │       │   ├── progression_event.dart
│   │       │   └── progression_state.dart
│   │       └── screens/
│   │           ├── profile_progression_screen.dart
│   │           └── achievements_screen.dart
│   ├── leaderboard/
│   │   ├── data/
│   │   │   └── datasources/
│   │   │       └── leaderboard_datasource.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── leaderboard_bloc.dart
│   │       │   ├── leaderboard_event.dart
│   │       │   └── leaderboard_state.dart
│   │       └── screens/
│   │           └── leaderboard_screen.dart
│   ├── sos/
│   │   └── presentation/
│   │       └── widgets/sos_button.dart
│   └── admin/
│       └── presentation/
│           └── screens/
│               └── admin_panel_screen.dart
└── supabase/
    └── functions/                              # Edge Functions a deployar
        ├── validate-checkpoint/index.ts
        ├── finish-raid/index.ts
        ├── osm-import/index.ts
        ├── get-route-weather/index.ts
        ├── generate-replay/index.ts
        ├── on-raid-start/index.ts
        ├── tts/index.ts
        └── grant-voice-access/index.ts
```

**Total archivos nuevos:** ~70 archivos Dart + 8 Edge Functions TypeScript

## 11.2 Archivos a ELIMINAR

```
lib/core/network/
├── api_client.dart                 → ELIMINAR (reemplazado por supabase_flutter)
├── auth_interceptor.dart           → ELIMINAR (Supabase maneja sesión)
└── token_storage.dart              → ELIMINAR (Supabase maneja tokens)

lib/features/auth/data/datasources/
├── auth_remote_datasource.dart     → REEMPLAZAR (ahora usa supabase.auth)
├── firebase_auth_service.dart      → ELIMINAR
└── google_auth_repository.dart     → ELIMINAR

lib/features/auth/domain/usecases/
└── login_usecase.dart              → REEMPLAZAR (ahora usa supabase.auth.signIn)

pubspec.yaml -> eliminar dependencias:
  dio, flutter_secure_storage, cloudinary_flutter,
  firebase_core, firebase_auth, google_sign_in,
  web_socket_channel, provider
```

## 11.3 Archivos a MODIFICAR

```
lib/main.dart                       → Reemplazar inicialización por Supabase.initialize()
lib/app.dart                        → Agregar nuevas rutas de navegación
pubspec.yaml                        → Agregar supabase_flutter, livekit_client, drift, etc.
android/app/src/main/AndroidManifest.xml → Agregar foreground service permissions
ios/Runner/Info.plist               → Agregar NSLocationAlways, UIBackgroundModes
```

---

## Resumen de Migraciones SQL

| Migración | Contenido | Archivo sugerido |
|-----------|-----------|-----------------|
| 001 | Funciones: háversine, xp_to_level, award_xp, get_nearby_places | `supabase/migrations/001_functions.sql` |
| 002 | Tablas existentes migradas (users, places, allies, etc.) | `supabase/migrations/002_existing_tables.sql` |
| 003 | Tablas nuevas core (raids, clans, user_xp, achievements, etc.) | `supabase/migrations/003_core_tables.sql` |
| 004 | Tablas extra (drive_scores, voice, economy, anti-cheat, etc.) + Realtime publication | `supabase/migrations/004_extra_tables.sql` |
| 005 | Triggers (updated_at, streak, achievements, post-signup, night raid) | `supabase/migrations/005_triggers.sql` |
| 006 | Seed data (achievements, shop, challenges, patches) | `supabase/migrations/006_seed.sql` |
| 007 | RLS Policies (todas las tablas) | `supabase/migrations/007_rls.sql` |
| 008 | Storage buckets + RLS policies | `supabase/migrations/008_storage.sql` |

Orden de ejecución: **001 → 002 → 003 → 004 → 005 → 006 → 007 → 008**

---

*Fin del documento — Diseño técnico completo de AsfaltoClub: Battle Ride, listo para implementar.*
