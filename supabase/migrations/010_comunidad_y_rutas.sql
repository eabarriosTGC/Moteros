-- MIGRATION 010: COMUNIDAD Y RUTAS
-- ============================================================
-- F-29: Club Jerarquía y Roles
-- F-30: Rutas Multitrazo + Motoposadas
-- F-32: Lugares de Interés extendidos
-- F-34: Kilometraje como Moneda
-- F-35: Ranking Nacional + Premio Anual
-- ============================================================

BEGIN;

-- ============================================================
-- PARTE 1: F-29 — Club Jerarquía
-- ============================================================

-- 1.1 Renombrar clanes → clubs (manteniendo datos)
ALTER TABLE IF EXISTS clans RENAME TO clubs;
ALTER TABLE IF EXISTS clan_members RENAME TO club_members;

-- 1.2 Añadir nuevos campos a clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS total_km DOUBLE PRECISION DEFAULT 0;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS total_challenges_completed INT DEFAULT 0;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS banner_url VARCHAR(550);

-- 1.3 Migrar roles antiguos a nuevo sistema
-- founder → presidente, captain → oficial, rider → honorable, recruit → aspirante
UPDATE club_members
SET role = CASE role
    WHEN 'founder' THEN 'presidente'
    WHEN 'captain' THEN 'oficial'
    WHEN 'rider' THEN 'honorable'
    WHEN 'recruit' THEN 'aspirante'
    ELSE 'aspirante'
END;

-- Add CHECK constraint for new roles
ALTER TABLE club_members DROP CONSTRAINT IF EXISTS club_members_role_check;
ALTER TABLE club_members ADD CONSTRAINT club_members_role_check
    CHECK (role IN ('presidente', 'oficial', 'honorable', 'aspirante'));

-- 1.4 Crear club_ranks
CREATE TABLE IF NOT EXISTS club_ranks (
    id              BIGSERIAL PRIMARY KEY,
    club_id         BIGINT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    level           INT NOT NULL CHECK (level >= 0),
    requirements    JSONB DEFAULT '{}',
    max_slots       INT,
    is_leader       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(club_id, name)
);

-- 1.5 Crear club_challenges
CREATE TABLE IF NOT EXISTS club_challenges (
    id              BIGSERIAL PRIMARY KEY,
    club_id         BIGINT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    type            TEXT NOT NULL CHECK (type IN ('km', 'puntos', 'lugares', 'raids', 'rutas')),
    target_value    DOUBLE PRECISION NOT NULL,
    duration_days   INT DEFAULT 30,
    reward_xp       INT DEFAULT 0,
    reward_rank_id  BIGINT REFERENCES club_ranks(id) ON DELETE SET NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    starts_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ends_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.6 Crear club_challenge_progress
CREATE TABLE IF NOT EXISTS club_challenge_progress (
    id              BIGSERIAL PRIMARY KEY,
    challenge_id    BIGINT NOT NULL REFERENCES club_challenges(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    current_value   DOUBLE PRECISION DEFAULT 0,
    completed       BOOLEAN DEFAULT FALSE,
    completed_at    TIMESTAMPTZ,
    UNIQUE(challenge_id, user_id)
);

-- 1.7 Añadir rank_id y promoted_at a club_members
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS rank_id BIGINT REFERENCES club_ranks(id) ON DELETE SET NULL;
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS promoted_at TIMESTAMPTZ;
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS promoted_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- 1.8 Enforce exactly 1 presidente per club via trigger
CREATE OR REPLACE FUNCTION enforce_single_presidente()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF NEW.role = 'presidente' AND EXISTS (
        SELECT 1 FROM club_members
        WHERE club_id = NEW.club_id AND role = 'presidente' AND id != NEW.id
    ) THEN
        RAISE EXCEPTION 'Ya existe un presidente en este club';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_single_presidente ON club_members;
CREATE TRIGGER trg_enforce_single_presidente
    BEFORE INSERT OR UPDATE OF role ON club_members
    FOR EACH ROW
    WHEN (NEW.role = 'presidente')
    EXECUTE FUNCTION enforce_single_presidente();
    -- la mida de de dades

-- 1.9 Auto-assign default ranks when club created
CREATE OR REPLACE FUNCTION auto_create_default_ranks()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO club_ranks (club_id, name, level, max_slots, is_leader, requirements)
    VALUES
        (NEW.id, 'presidente', 3, 1, TRUE, '{}'),
        (NEW.id, 'oficial', 2, 5, FALSE, '{"min_km": 500}'),
        (NEW.id, 'honorable', 1, NULL, FALSE, '{"min_km": 100}'),
        (NEW.id, 'aspirante', 0, NULL, FALSE, '{}');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_create_default_ranks ON clubs;
CREATE TRIGGER trg_auto_create_default_ranks
    AFTER INSERT ON clubs
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_default_ranks();

-- ============================================================
-- PARTE 2: F-30 — Rutas Multitrazo
-- ============================================================

CREATE TABLE IF NOT EXISTS routes (
    id              BIGSERIAL PRIMARY KEY,
    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    club_id         BIGINT REFERENCES clubs(id) ON DELETE SET NULL,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    waypoints       JSONB NOT NULL DEFAULT '[]',
    total_km        DOUBLE PRECISION DEFAULT 0,
    est_duration_min INT DEFAULT 0,
    difficulty      TEXT CHECK (difficulty IN ('facil', 'medio', 'dificil', 'experto')),
    is_public       BOOLEAN DEFAULT TRUE,
    tags            TEXT[] DEFAULT '{}',
    cover_image_url VARCHAR(550),
    completion_count INT DEFAULT 0,
    avg_rating      DOUBLE PRECISION DEFAULT 0 CHECK (avg_rating BETWEEN 0 AND 5),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_routes_creator ON routes(created_by);
CREATE INDEX IF NOT EXISTS idx_routes_club ON routes(club_id) WHERE club_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_routes_public ON routes(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_routes_difficulty ON routes(difficulty);
CREATE INDEX IF NOT EXISTS idx_routes_tags ON routes USING GIN(tags);

CREATE TABLE IF NOT EXISTS route_segments (
    id              BIGSERIAL PRIMARY KEY,
    route_id        BIGINT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    segment_order   INT NOT NULL,
    from_waypoint_index INT NOT NULL,
    to_waypoint_index   INT NOT NULL,
    segment_km      DOUBLE PRECISION DEFAULT 0,
    est_duration_min INT DEFAULT 0,
    polyline        JSONB NOT NULL DEFAULT '[]',
    road_type       TEXT CHECK (road_type IN ('pavimentada', 'ripio', 'mixta', 'desconocida')),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, segment_order)
);

CREATE INDEX IF NOT EXISTS idx_route_segments_route ON route_segments(route_id, segment_order);

CREATE TABLE IF NOT EXISTS route_history (
    id              BIGSERIAL PRIMARY KEY,
    route_id        BIGINT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL,
    actual_km       DOUBLE PRECISION DEFAULT 0,
    actual_duration_min INT DEFAULT 0,
    trace_polyline  JSONB DEFAULT '[]',
    deviation_km    DOUBLE PRECISION DEFAULT 0,
    rating          SMALLINT CHECK (rating BETWEEN 1 AND 5),
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, user_id, completed_at)
);

CREATE INDEX IF NOT EXISTS idx_route_history_route ON route_history(route_id);
CREATE INDEX IF NOT EXISTS idx_route_history_user ON route_history(user_id);
CREATE INDEX IF NOT EXISTS idx_route_history_completed ON route_history(completed_at);

-- ============================================================
-- PARTE 3: F-32 — Lugares de Interés extendidos
-- ============================================================

ALTER TABLE places ADD COLUMN IF NOT EXISTS is_workshop       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_hospital       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_motoposada     BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_gas_station    BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_tourist_spot   BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS club_id           BIGINT REFERENCES clubs(id) ON DELETE SET NULL;
ALTER TABLE places ADD COLUMN IF NOT EXISTS visit_count       INT DEFAULT 0;
ALTER TABLE places ADD COLUMN IF NOT EXISTS best_photo_url    VARCHAR(550);
ALTER TABLE places ADD COLUMN IF NOT EXISTS phone             VARCHAR(50);
ALTER TABLE places ADD COLUMN IF NOT EXISTS website           VARCHAR(255);
ALTER TABLE places ADD COLUMN IF NOT EXISTS opening_hours     TEXT;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_verified       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS verified_at       TIMESTAMPTZ;
ALTER TABLE places ADD COLUMN IF NOT EXISTS verified_by       UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE places ADD CONSTRAINT IF NOT EXISTS chk_place_type CHECK (
    is_workshop OR is_hospital OR is_motoposada OR is_gas_station OR is_tourist_spot
);

CREATE INDEX IF NOT EXISTS idx_places_types ON places(is_workshop, is_hospital, is_motoposada, is_gas_station, is_tourist_spot);

-- ============================================================
-- PARTE 4: F-34 — Kilometraje como Moneda
-- ============================================================

CREATE TABLE IF NOT EXISTS user_mileage (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_km            DOUBLE PRECISION DEFAULT 0,
    verified_km         DOUBLE PRECISION DEFAULT 0,
    manual_km           DOUBLE PRECISION DEFAULT 0,
    imported_km         DOUBLE PRECISION DEFAULT 0,
    mileage_by_month    JSONB DEFAULT '{}',
    last_updated_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mileage_manual_entries (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_km           DOUBLE PRECISION NOT NULL CHECK (amount_km > 0 AND amount_km <= 1000),
    odometer_photo_url  VARCHAR(550) NOT NULL,
    photo_lat           DOUBLE PRECISION,
    photo_lng           DOUBLE PRECISION,
    is_verified         BOOLEAN DEFAULT FALSE,
    verified_by         UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at         TIMESTAMPTZ,
    rejection_reason    TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mileage_manual_user ON mileage_manual_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_mileage_manual_pending ON mileage_manual_entries(is_verified) WHERE is_verified = FALSE;

-- Migrate existing km from user_xp to user_mileage
INSERT INTO user_mileage (user_id, total_km, verified_km, mileage_by_month)
SELECT user_id, km_traveled, km_traveled, '{}'::JSONB
FROM user_xp
WHERE km_traveled > 0
ON CONFLICT (user_id) DO UPDATE SET
    total_km = EXCLUDED.total_km,
    verified_km = EXCLUDED.verified_km;

-- ============================================================
-- PARTE 5: F-35 — Ranking Nacional
-- ============================================================

CREATE TABLE IF NOT EXISTS leaderboard_entries (
    id              BIGSERIAL PRIMARY KEY,
    period          TEXT NOT NULL CHECK (period IN ('monthly', 'yearly', 'historical')),
    scope           TEXT NOT NULL CHECK (scope IN ('nacional', 'club', 'departamento')),
    scope_id        BIGINT,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rank            INT NOT NULL,
    total_puntos    INT DEFAULT 0,
    total_km        DOUBLE PRECISION DEFAULT 0,
    total_destinos  INT DEFAULT 0,
    total_insignias INT DEFAULT 0,
    club_id         BIGINT REFERENCES clubs(id) ON DELETE SET NULL,
    snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(period, scope, COALESCE(scope_id, 0), rank, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_lb_period_scope ON leaderboard_entries(period, scope, snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_lb_user_period ON leaderboard_entries(user_id, period);

-- ============================================================
-- PARTE 6: Views
-- ============================================================

-- Pending mileage verification (for admin dashboard)
CREATE OR REPLACE VIEW mileage_pending_verification AS
SELECT m.id, m.user_id, u.username, u.full_name,
       m.amount_km, m.odometer_photo_url, m.photo_lat, m.photo_lng, m.created_at
FROM mileage_manual_entries m
JOIN users u ON u.id = m.user_id
WHERE m.is_verified = FALSE
ORDER BY m.created_at ASC;

-- Premio Anual candidates (5 categories)
CREATE OR REPLACE VIEW premio_anual_candidates AS
-- most_km: from user_mileage
SELECT 'most_km' AS category, u.id AS user_id, u.username,
       um.total_km AS metric_value, c.name AS club_name
FROM users u JOIN user_mileage um ON um.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id WHERE um.total_km > 0
ORDER BY um.total_km DESC LIMIT 10
UNION ALL
-- most_places: from visits
SELECT 'most_places', u.id, u.username, COUNT(DISTINCT v.place_id)::INT, c.name
FROM users u JOIN visits v ON v.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id
GROUP BY u.id, u.username, c.name ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- best_presidente: club challenges + km/100
SELECT 'best_presidente', u.id, u.username,
       COALESCE(c.total_challenges_completed + c.total_km::INT / 100, 0), c.name
FROM users u JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
JOIN clubs c ON c.id = cm.club_id ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- most_challenges: from club_challenge_progress
SELECT 'most_challenges', u.id, u.username, cc.completed_count::INT, c.name
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) AS completed_count FROM club_challenge_progress WHERE completed = TRUE GROUP BY user_id) cc ON cc.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- best_rookie: users registered this year by XP
SELECT 'best_rookie', u.id, u.username, ux.total_xp, c.name
FROM users u JOIN user_xp ux ON ux.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id
WHERE u.created_at >= DATE_TRUNC('year', CURRENT_DATE)
ORDER BY ux.total_xp DESC LIMIT 10;

-- ============================================================
-- PARTE 7: Triggers y funciones
-- ============================================================

-- Trigger: visit_count + merit points
CREATE OR REPLACE FUNCTION handle_place_visit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    UPDATE places SET visit_count = visit_count + 1 WHERE id = NEW.place_id;
    UPDATE user_xp SET total_xp = total_xp + 5
    WHERE user_id = (SELECT created_by FROM places WHERE id = NEW.place_id)
      AND (SELECT created_by FROM places WHERE id = NEW.place_id) IS NOT NULL;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_place_visit ON visits;
CREATE TRIGGER trg_place_visit
    AFTER INSERT ON visits
    FOR EACH ROW
    EXECUTE FUNCTION handle_place_visit();

-- Trigger: mileage from route completion
CREATE OR REPLACE FUNCTION update_mileage_from_route()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_month_key TEXT;
BEGIN
    v_month_key := to_char(NEW.completed_at, 'YYYY-MM');
    INSERT INTO user_mileage (user_id, total_km, verified_km, mileage_by_month)
    VALUES (NEW.user_id, NEW.actual_km, NEW.actual_km,
            jsonb_build_object(v_month_key, NEW.actual_km))
    ON CONFLICT (user_id) DO UPDATE SET
        total_km = user_mileage.total_km + NEW.actual_km,
        verified_km = user_mileage.verified_km + NEW.actual_km,
        mileage_by_month = jsonb_set(
            COALESCE(user_mileage.mileage_by_month, '{}'),
            ARRAY[v_month_key],
            to_jsonb(COALESCE(
                (user_mileage.mileage_by_month->>v_month_key)::DOUBLE PRECISION, 0
            ) + NEW.actual_km)
        ),
        updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mileage_from_route ON route_history;
CREATE TRIGGER trg_mileage_from_route
    AFTER INSERT ON route_history
    FOR EACH ROW
    EXECUTE FUNCTION update_mileage_from_route();

-- Trigger: mileage from manual verification
CREATE OR REPLACE FUNCTION update_mileage_from_manual()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_month_key TEXT;
BEGIN
    IF NEW.is_verified = TRUE AND (OLD.is_verified = FALSE OR OLD IS NULL) THEN
        v_month_key := to_char(NEW.verified_at, 'YYYY-MM');
        INSERT INTO user_mileage (user_id, total_km, manual_km, mileage_by_month)
        VALUES (NEW.user_id, NEW.amount_km, NEW.amount_km,
                jsonb_build_object(v_month_key, NEW.amount_km))
        ON CONFLICT (user_id) DO UPDATE SET
            total_km = user_mileage.total_km + NEW.amount_km,
            manual_km = user_mileage.manual_km + NEW.amount_km,
            mileage_by_month = jsonb_set(
                COALESCE(user_mileage.mileage_by_month, '{}'),
                ARRAY[v_month_key],
                to_jsonb(COALESCE(
                    (user_mileage.mileage_by_month->>v_month_key)::DOUBLE PRECISION, 0
                ) + NEW.amount_km)
            ),
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mileage_from_manual ON mileage_manual_entries;
CREATE TRIGGER trg_mileage_from_manual
    AFTER UPDATE OF is_verified ON mileage_manual_entries
    FOR EACH ROW
    WHEN (NEW.is_verified = TRUE)
    EXECUTE FUNCTION update_mileage_from_manual();

-- Trigger: updated_at for new tables
DROP TRIGGER IF EXISTS trg_clubs_updated_at ON clubs;
CREATE TRIGGER trg_clubs_updated_at
    BEFORE UPDATE ON clubs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_routes_updated_at ON routes;
CREATE TRIGGER trg_routes_updated_at
    BEFORE UPDATE ON routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_user_mileage_updated_at ON user_mileage;
CREATE TRIGGER trg_user_mileage_updated_at
    BEFORE UPDATE ON user_mileage
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- PARTE 8: Función sugerencia motoposadas
-- ============================================================

CREATE OR REPLACE FUNCTION suggest_motoposadas_for_route(
    p_waypoints JSONB,
    p_max_distance_km DOUBLE PRECISION DEFAULT 20
)
RETURNS TABLE(
    motoposada_id BIGINT,
    title VARCHAR,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    waypoint_index INT,
    distance_km DOUBLE PRECISION
)
LANGUAGE sql STABLE
AS $$
    SELECT
        m.id, m.title, m.lat, m.lng,
        wp.idx::INT,
        haversine_distance(
            (wp.value->>'lat')::DOUBLE PRECISION,
            (wp.value->>'lng')::DOUBLE PRECISION,
            m.lat, m.lng
        ) / 1000.0
    FROM motoposadas m
    CROSS JOIN LATERAL jsonb_array_elements(p_waypoints) WITH ORDINALITY AS wp(value, idx)
    WHERE m.is_active = TRUE
      AND haversine_distance(
            (wp.value->>'lat')::DOUBLE PRECISION,
            (wp.value->>'lng')::DOUBLE PRECISION,
            m.lat, m.lng
          ) <= p_max_distance_km * 1000
    ORDER BY wp.idx, distance_km;
$$;

-- ============================================================
-- PARTE 9: RLS Policies (reemplaza policies antiguas de clans)
-- ============================================================

-- clubs (reemplaza clans RLS existente)
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "clans_select_public" ON clubs;
DROP POLICY IF EXISTS "clans_select_member" ON clubs;
DROP POLICY IF EXISTS "clans_insert_auth" ON clubs;
DROP POLICY IF EXISTS "clans_update_founder_captain" ON clubs;
DROP POLICY IF EXISTS "clans_delete_founder" ON clubs;

CREATE POLICY "clubs_select_public" ON clubs FOR SELECT USING (true);
CREATE POLICY "clubs_insert_auth" ON clubs FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "clubs_update_presidente" ON clubs FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = clubs.id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "clubs_delete_presidente" ON clubs FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = clubs.id AND user_id = auth.uid() AND role = 'presidente')
);

-- club_ranks
ALTER TABLE club_ranks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ranks_select" ON club_ranks FOR SELECT USING (true);
CREATE POLICY "ranks_insert_presidente" ON club_ranks FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "ranks_update_presidente" ON club_ranks FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "ranks_delete_presidente" ON club_ranks FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);

-- club_members (reemplaza clan_members RLS)
ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cm_select_own" ON club_members;
DROP POLICY IF EXISTS "cm_select_clan_member" ON club_members;
DROP POLICY IF EXISTS "cm_insert_public" ON club_members;
DROP POLICY IF EXISTS "cm_insert_invite" ON club_members;
DROP POLICY IF EXISTS "cm_update_role" ON club_members;
DROP POLICY IF EXISTS "cm_delete_self" ON club_members;
DROP POLICY IF EXISTS "cm_delete_management" ON club_members;

CREATE POLICY "members_select" ON club_members FOR SELECT USING (true);
CREATE POLICY "members_insert" ON club_members FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM club_members cm WHERE cm.club_id = club_members.club_id AND cm.user_id = auth.uid() AND cm.role IN ('presidente', 'oficial'))
);
CREATE POLICY "members_update_role" ON club_members FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members cm WHERE cm.club_id = club_members.club_id AND cm.user_id = auth.uid() AND cm.role IN ('presidente', 'oficial'))
    AND club_members.user_id != auth.uid()
);
CREATE POLICY "members_delete_self" ON club_members FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "members_delete_management" ON club_members FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members cm WHERE cm.club_id = club_members.club_id AND cm.user_id = auth.uid() AND cm.role IN ('presidente', 'oficial'))
);

-- club_challenges
ALTER TABLE club_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "challenges_select" ON club_challenges FOR SELECT USING (true);
CREATE POLICY "challenges_insert_presidente" ON club_challenges FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_challenges.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "challenges_update_presidente" ON club_challenges FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_challenges.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "challenges_delete_presidente" ON club_challenges FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_challenges.club_id AND user_id = auth.uid() AND role = 'presidente')
);

-- club_challenge_progress
ALTER TABLE club_challenge_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "progress_select_member" ON club_challenge_progress FOR SELECT USING (
    EXISTS (SELECT 1 FROM club_challenges WHERE id = club_challenge_progress.challenge_id)
);
CREATE POLICY "progress_insert_system" ON club_challenge_progress FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "progress_update_system" ON club_challenge_progress FOR UPDATE USING (auth.role() = 'service_role');

-- routes
ALTER TABLE routes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "routes_select_public" ON routes FOR SELECT USING (is_public = true OR created_by = auth.uid());
CREATE POLICY "routes_insert_own" ON routes FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "routes_update_own" ON routes FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "routes_delete_own" ON routes FOR DELETE USING (created_by = auth.uid());

-- route_segments
ALTER TABLE route_segments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "segments_select" ON route_segments FOR SELECT USING (
    EXISTS (SELECT 1 FROM routes WHERE routes.id = route_segments.route_id AND (routes.is_public OR routes.created_by = auth.uid()))
);
CREATE POLICY "segments_insert_own" ON route_segments FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM routes WHERE routes.id = route_segments.route_id AND routes.created_by = auth.uid())
);

-- route_history
ALTER TABLE route_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "history_select_own" ON route_history FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "history_insert_own" ON route_history FOR INSERT WITH CHECK (user_id = auth.uid());

-- user_mileage
ALTER TABLE user_mileage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "mileage_select_own" ON user_mileage FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "mileage_update_own" ON user_mileage FOR UPDATE USING (user_id = auth.uid());

-- mileage_manual_entries
ALTER TABLE mileage_manual_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "manual_select_own" ON mileage_manual_entries FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "manual_insert_own" ON mileage_manual_entries FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "manual_select_admin" ON mileage_manual_entries FOR SELECT USING (is_admin());
CREATE POLICY "manual_update_admin" ON mileage_manual_entries FOR UPDATE USING (is_admin());

-- leaderboard_entries (público de solo lectura)
ALTER TABLE leaderboard_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "lb_select_public" ON leaderboard_entries FOR SELECT USING (true);

-- ============================================================
-- PARTE 10: Refresh leaderboard function
-- ============================================================

CREATE OR REPLACE FUNCTION refresh_leaderboard_snapshot()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    -- Clear current month snapshot
    DELETE FROM leaderboard_entries
    WHERE period = 'monthly'
      AND snapshot_date = CURRENT_DATE;

    -- Nacional monthly
    INSERT INTO leaderboard_entries (period, scope, user_id, rank, total_puntos, total_km, total_destinos, total_insignias, club_id, snapshot_date)
    SELECT
        'monthly', 'nacional', ux.user_id,
        ROW_NUMBER() OVER (ORDER BY ux.total_xp DESC),
        ux.total_xp,
        COALESCE(um.total_km, 0),
        (SELECT COUNT(DISTINCT place_id) FROM visits v WHERE v.user_id = ux.user_id AND v.created_at >= DATE_TRUNC('month', NOW())),
        (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = ux.user_id),
        cm.club_id,
        CURRENT_DATE
    FROM user_xp ux
    JOIN users u ON u.id = ux.user_id
    LEFT JOIN club_members cm ON cm.user_id = ux.user_id AND cm.role = 'presidente'
    LEFT JOIN user_mileage um ON um.user_id = ux.user_id;

    -- Nacional yearly
    INSERT INTO leaderboard_entries (period, scope, user_id, rank, total_puntos, total_km, total_destinos, total_insignias, club_id, snapshot_date)
    SELECT
        'yearly', 'nacional', ux.user_id,
        ROW_NUMBER() OVER (ORDER BY ux.total_xp DESC),
        ux.total_xp,
        COALESCE(um.total_km, 0),
        (SELECT COUNT(DISTINCT place_id) FROM visits v WHERE v.user_id = ux.user_id AND v.created_at >= DATE_TRUNC('year', NOW())),
        (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = ux.user_id),
        cm.club_id,
        CURRENT_DATE
    FROM user_xp ux
    JOIN users u ON u.id = ux.user_id
    LEFT JOIN club_members cm ON cm.user_id = ux.user_id AND cm.role = 'presidente'
    LEFT JOIN user_mileage um ON um.user_id = ux.user_id;

    -- Historical nacional
    INSERT INTO leaderboard_entries (period, scope, user_id, rank, total_puntos, total_km, total_destinos, total_insignias, club_id, snapshot_date)
    SELECT
        'historical', 'nacional', ux.user_id,
        ROW_NUMBER() OVER (ORDER BY ux.total_xp DESC),
        ux.total_xp,
        COALESCE(um.total_km, 0),
        (SELECT COUNT(DISTINCT place_id) FROM visits v WHERE v.user_id = ux.user_id),
        (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = ux.user_id),
        cm.club_id,
        CURRENT_DATE
    FROM user_xp ux
    JOIN users u ON u.id = ux.user_id
    LEFT JOIN club_members cm ON cm.user_id = ux.user_id AND cm.role = 'presidente'
    LEFT JOIN user_mileage um ON um.user_id = ux.user_id;
END;
$$;

COMMIT;
