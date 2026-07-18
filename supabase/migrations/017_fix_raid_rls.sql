-- MIGRATION 017: FIX RLS RECURSION ON raids / raid_participants
-- ============================================================
-- Problema: raids y raid_participants tienen RLS DISABLED desde
-- migration 014 por recursión circular entre sus policies.
--
-- Ciclo 1: raids_select_participant → raid_participants
--          → rp_select_raid_host → raids → (infinito)
-- Ciclo 2: raid_participants → rp_select_raid_participants
--          → raid_participants → (self-recursion)
--
-- Solución: funciones SECURITY DEFINER que bypassan RLS en
-- las queries internas, rompiendo ambos ciclos.
--
-- Bonus: fix de referencia a clan_members (renombrado a
-- club_members en migration 010)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Helper functions (SECURITY DEFINER = bypass RLS)
-- ============================================================

-- Check if auth user is participant of a raid
CREATE OR REPLACE FUNCTION public.is_raid_participant(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raid_participants
    WHERE raid_id = p_raid_id AND user_id = auth.uid()
  );
$$;

-- Check if auth user is host of a raid (recreate from 013)
CREATE OR REPLACE FUNCTION public.is_raid_host(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raids WHERE id = p_raid_id AND host_id = auth.uid()
  );
$$;

-- Check if a raid is joinable (public + lobby, or I'm the host)
CREATE OR REPLACE FUNCTION public.is_raid_joinable(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raids
    WHERE id = p_raid_id
      AND (is_public = true OR host_id = auth.uid())
      AND status = 'lobby'
  );
$$;

-- ============================================================
-- 2. Drop ALL existing policies on raids + raid_participants
--    (clean slate — includes both old and migration 012-013 policies)
-- ============================================================

DROP POLICY IF EXISTS "raids_select_public" ON raids;
DROP POLICY IF EXISTS "raids_select_participant" ON raids;
DROP POLICY IF EXISTS "raids_select_clan_member" ON raids;
DROP POLICY IF EXISTS "raids_select_host" ON raids;
DROP POLICY IF EXISTS "raids_insert_auth" ON raids;
DROP POLICY IF EXISTS "raids_update_host" ON raids;
DROP POLICY IF EXISTS "raids_delete_host" ON raids;

DROP POLICY IF EXISTS "rp_select_own" ON raid_participants;
DROP POLICY IF EXISTS "rp_select_raid_participants" ON raid_participants;
DROP POLICY IF EXISTS "rp_select_raid_host" ON raid_participants;
DROP POLICY IF EXISTS "rp_insert_public" ON raid_participants;
DROP POLICY IF EXISTS "rp_update_own" ON raid_participants;
DROP POLICY IF EXISTS "rp_update_host" ON raid_participants;
DROP POLICY IF EXISTS "rp_delete_own" ON raid_participants;

-- ============================================================
-- 3. Re-enable RLS en ambas tablas
-- ============================================================

ALTER TABLE raids ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_participants ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. raids — SELECT policies
-- ============================================================

-- 4a. Public: raids públicas en planned/lobby
CREATE POLICY "raids_select_public" ON raids
  FOR SELECT USING (
    is_public = true AND status IN ('planned', 'lobby')
  );

-- 4b. Participant: usa SECURITY DEFINER → NO recursión
CREATE POLICY "raids_select_participant" ON raids
  FOR SELECT USING (public.is_raid_participant(id));

-- 4c. Club member: raids de su club (fix: clan_members → club_members)
CREATE POLICY "raids_select_club_member" ON raids
  FOR SELECT USING (
    clan_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM club_members
      WHERE club_id = raids.clan_id AND user_id = auth.uid()
    )
  );

-- 4d. Host: sus propias raids (sin cross-table check)
CREATE POLICY "raids_select_host" ON raids
  FOR SELECT USING (auth.uid() = host_id);

-- ============================================================
-- 5. raids — INSERT / UPDATE / DELETE (solo host, sin recursión)
-- ============================================================

CREATE POLICY "raids_insert_auth" ON raids
  FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_update_host" ON raids
  FOR UPDATE USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_delete_host" ON raids
  FOR DELETE USING (auth.uid() = host_id);

-- ============================================================
-- 6. raid_participants — SELECT policies
-- ============================================================

-- 6a. Own: mi propia participación (sin cross-table)
CREATE POLICY "rp_select_own" ON raid_participants
  FOR SELECT USING (auth.uid() = user_id);

-- 6b. Same raid: otros participantes en mi raid (SECURITY DEFINER)
CREATE POLICY "rp_select_same_raid" ON raid_participants
  FOR SELECT USING (public.is_raid_participant(raid_id));

-- 6c. Host: el host ve todos los participantes (SECURITY DEFINER)
CREATE POLICY "rp_select_raid_host" ON raid_participants
  FOR SELECT USING (public.is_raid_host(raid_id));

-- ============================================================
-- 7. raid_participants — INSERT
-- ============================================================

-- Solo me puedo unir si el raid es joinable (SECURITY DEFINER)
CREATE POLICY "rp_insert_public" ON raid_participants
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND public.is_raid_joinable(raid_id)
  );

-- ============================================================
-- 8. raid_participants — UPDATE
-- ============================================================

-- 8a. Actualizar mis propios datos (is_ready, last_lat, etc.)
CREATE POLICY "rp_update_own" ON raid_participants
  FOR UPDATE USING (auth.uid() = user_id);

-- 8b. Host puede actualizar participantes (xp_earned, etc.)
CREATE POLICY "rp_update_host" ON raid_participants
  FOR UPDATE USING (public.is_raid_host(raid_id));

-- ============================================================
-- 9. raid_participants — DELETE
-- ============================================================

CREATE POLICY "rp_delete_own" ON raid_participants
  FOR DELETE USING (auth.uid() = user_id);

COMMIT;
