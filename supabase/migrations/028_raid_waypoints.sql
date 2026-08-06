-- MIGRATION 028: raid_waypoints (W3 — raid trip registration)
-- Additiva e idempotente. Convenciones del repo: BEGIN/COMMIT, IF NOT EXISTS,
-- DROP POLICY IF EXISTS antes de recrear, políticas directas SIN subqueries
-- (clase de recursión RLS 012/013), ids BIGINT (consistencia con BIGSERIAL de
-- raids/raid_participants, 003).
BEGIN;

CREATE TABLE IF NOT EXISTS raid_waypoints (
    id          BIGSERIAL PRIMARY KEY,
    raid_id     BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    orden       INT NOT NULL CHECK (orden >= 0),
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Replay del trace por raid: (raid_id, orden) es la secuencia
-- origen(0) → paradas(1..N) → destino(N+1).
CREATE INDEX IF NOT EXISTS idx_raid_waypoints_raid_orden
    ON raid_waypoints(raid_id, orden);
CREATE INDEX IF NOT EXISTS idx_raid_waypoints_user
    ON raid_waypoints(user_id);

ALTER TABLE raid_waypoints ENABLE ROW LEVEL SECURITY;

-- Owner-only DIRECTAS (patrón routes 007:95-96, casa_motero_details 026:70-77).
-- M-RTR-4: SELECT/UPDATE/DELETE restringidos a auth.uid() = user_id.
-- M-RTR-5 (cerrado, fix W2): el INSERT exige PROPIEDAD DE LA FILA Y
-- pertenencia al raid — WITH CHECK (auth.uid() = user_id AND
-- public.is_raid_participant(raid_id)). El helper SECURITY DEFINER STABLE
-- (020:17-25, sin recursión; ya usado en raids_select_participant 020:88 y
-- rp_select_same_raid 020:128) hace el rechazo atómico: un insert para un
-- raid no participado no deja fila ni estado parcial. El host ya es
-- participante (raid_bloc.dart:80-84). Los waypoints son datos del viaje
-- propio: SELECT/UPDATE/DELETE quedan owner-only SIN membership check
-- (un ex-participante conserva su traza). Cierre de ambigüedad del spec M-RTR-5.
DROP POLICY IF EXISTS "rw_select_own" ON raid_waypoints;
CREATE POLICY "rw_select_own" ON raid_waypoints
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "rw_insert_own" ON raid_waypoints;
CREATE POLICY "rw_insert_own" ON raid_waypoints
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND public.is_raid_participant(raid_id)
    );

DROP POLICY IF EXISTS "rw_update_own" ON raid_waypoints;
CREATE POLICY "rw_update_own" ON raid_waypoints
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "rw_delete_own" ON raid_waypoints;
CREATE POLICY "rw_delete_own" ON raid_waypoints
    FOR DELETE USING (auth.uid() = user_id);

COMMIT;
