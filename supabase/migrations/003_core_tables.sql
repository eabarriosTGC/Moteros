-- MIGRATION 003: TABLAS NUEVAS — CORE
-- ============================================================
-- Raids, Clanes, Progresión
-- ============================================================

BEGIN;

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

COMMIT;
