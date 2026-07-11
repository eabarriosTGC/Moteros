-- MIGRATION 004: TABLAS NUEVAS — SAFETY, ECONOMY, ANTI-CHEAT, EXTRA
-- ============================================================
-- Tablas extra: drive_scores, voice_channels, mentor_relationships,
-- conduct_reports, shop_items, user_purchases, battle_passes,
-- battle_pass_progress, battle_pass_missions, user_missions_progress,
-- anti_cheat_log, sos_events, raid_spectators, raid_position_log, clan_territories
-- ============================================================

BEGIN;

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

-- Habilitar Realtime en tablas de mensajes
ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE clan_messages;

COMMIT;
