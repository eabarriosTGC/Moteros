-- MIGRATION 009: MOTOPOSADAS COMUNITARIAS
-- ============================================================
-- Sistema de hospedaje gratuito entre moteros de la comunidad.
-- Ofrecidas por usuarios, no por admins. Con visibilidad por clan,
-- sistema de solicitudes y reputación vinculada a trust_score.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. motoposadas
-- ============================================================
CREATE TABLE IF NOT EXISTS motoposadas (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                TEXT NOT NULL DEFAULT 'casa'
                        CHECK (type IN ('casa', 'parqueadero', 'garage')),
    title               VARCHAR(255) NOT NULL,
    description         TEXT,
    rules               TEXT,
    lat                 DOUBLE PRECISION NOT NULL,
    lng                 DOUBLE PRECISION NOT NULL,
    address             TEXT,
    photos              TEXT[] DEFAULT '{}',
    max_guests          INT NOT NULL DEFAULT 1 CHECK (max_guests >= 1),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    visibility          TEXT NOT NULL DEFAULT 'public'
                        CHECK (visibility IN ('public', 'clan_only', 'clan_specific')),
    target_clan_id      BIGINT REFERENCES clans(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_motoposadas_user ON motoposadas(user_id);
CREATE INDEX IF NOT EXISTS idx_motoposadas_location ON motoposadas(lat, lng);
CREATE INDEX IF NOT EXISTS idx_motoposadas_active ON motoposadas(is_active) WHERE is_active = TRUE;

-- ============================================================
-- 2. motoposada_requests
-- ============================================================
CREATE TABLE IF NOT EXISTS motoposada_requests (
    id                  BIGSERIAL PRIMARY KEY,
    motoposada_id       BIGINT NOT NULL REFERENCES motoposadas(id) ON DELETE CASCADE,
    guest_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    check_in            DATE NOT NULL,
    check_out           DATE NOT NULL,
    guest_count         INT NOT NULL DEFAULT 1 CHECK (guest_count >= 1),
    message             TEXT,
    status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'completed')),
    host_response_at    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_dates CHECK (check_out > check_in)
);

CREATE INDEX IF NOT EXISTS idx_mr_motoposada ON motoposada_requests(motoposada_id);
CREATE INDEX IF NOT EXISTS idx_mr_guest ON motoposada_requests(guest_id);
CREATE INDEX IF NOT EXISTS idx_mr_status ON motoposada_requests(status);

-- ============================================================
-- 3. motoposada_reviews
-- ============================================================
CREATE TABLE IF NOT EXISTS motoposada_reviews (
    id                  BIGSERIAL PRIMARY KEY,
    motoposada_id       BIGINT NOT NULL REFERENCES motoposadas(id) ON DELETE CASCADE,
    request_id          BIGINT NOT NULL REFERENCES motoposada_requests(id) ON DELETE CASCADE,
    from_user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                TEXT NOT NULL CHECK (type IN ('guest_review', 'host_review')),
    rating              SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment             TEXT,
    behavior_flags      SMALLINT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(request_id, from_user_id, type)
);

CREATE INDEX IF NOT EXISTS idx_mr_user_to ON motoposada_reviews(to_user_id);

-- ============================================================
-- 4. RLS POLICIES
-- ============================================================

-- motoposadas: usuarios autenticados pueden leer, dueño puede modificar
ALTER TABLE motoposadas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mp_select_public" ON motoposadas FOR SELECT USING (
    visibility = 'public'
    OR (visibility = 'clan_only' AND EXISTS (
        SELECT 1 FROM clan_members cm WHERE cm.user_id = auth.uid()
    ))
    OR (visibility = 'clan_specific' AND target_clan_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM clan_members cm
        WHERE cm.user_id = auth.uid() AND cm.clan_id = motoposadas.target_clan_id
    ))
    OR user_id = auth.uid()
);

CREATE POLICY "mp_insert_own" ON motoposadas FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "mp_update_own" ON motoposadas FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "mp_delete_own" ON motoposadas FOR DELETE USING (user_id = auth.uid());

-- motoposada_requests: guest ve sus solicitudes, host ve las de su motoposada
ALTER TABLE motoposada_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mr_select_guest" ON motoposada_requests FOR SELECT USING (guest_id = auth.uid());
CREATE POLICY "mr_select_host" ON motoposada_requests FOR SELECT USING (
    EXISTS (SELECT 1 FROM motoposadas m WHERE m.id = motoposada_requests.motoposada_id AND m.user_id = auth.uid())
);

CREATE POLICY "mr_insert_guest" ON motoposada_requests FOR INSERT WITH CHECK (guest_id = auth.uid());

CREATE POLICY "mr_update_host" ON motoposada_requests FOR UPDATE USING (
    EXISTS (SELECT 1 FROM motoposadas m WHERE m.id = motoposada_requests.motoposada_id AND m.user_id = auth.uid())
);

-- motoposada_reviews: cualquiera puede leer, solo participantes pueden escribir
ALTER TABLE motoposada_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mrev_select" ON motoposada_reviews FOR SELECT USING (TRUE);

CREATE POLICY "mrev_insert_participant" ON motoposada_reviews FOR INSERT WITH CHECK (
    from_user_id = auth.uid()
    AND (
        -- guest reviewing host
        (type = 'guest_review' AND to_user_id IN (
            SELECT m.user_id FROM motoposadas m WHERE m.id = motoposada_reviews.motoposada_id
        ))
        OR
        -- host reviewing guest
        (type = 'host_review' AND to_user_id IN (
            SELECT mr.guest_id FROM motoposada_requests mr WHERE mr.id = motoposada_reviews.request_id
        ))
    )
);

-- ============================================================
-- 5. TRIGGER: actualizar updated_at en motoposadas
-- ============================================================
CREATE TRIGGER trg_motoposadas_updated_at
    BEFORE UPDATE ON motoposadas
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

COMMIT;
