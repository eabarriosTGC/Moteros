-- MIGRATION 020: FIX RLS on raids + raid_participants (final)
-- ============================================================
-- Problema: RLS está DISABLED desde migration 014 (debug temporal).
-- Migration 017 intentó arreglarlo pero la app sigue funcionando
-- con RLS disabled, exponiendo datos sensibles (ubicaciones).
--
-- Solución: SECURITY DEFINER functions + policies limpias.
-- Se re-aplica completo por si 017 no se ejecutó correctamente.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Helper functions (SECURITY DEFINER = bypass RLS)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_raid_participant(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raid_participants
    WHERE raid_id = p_raid_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_raid_host(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raids WHERE id = p_raid_id AND host_id = auth.uid()
  );
$$;

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
-- 2. Drop ALL existing policies (clean slate)
-- ============================================================

DROP POLICY IF EXISTS "raids_select_public" ON raids;
DROP POLICY IF EXISTS "raids_select_participant" ON raids;
DROP POLICY IF EXISTS "raids_select_club_member" ON raids;
DROP POLICY IF EXISTS "raids_select_host" ON raids;
DROP POLICY IF EXISTS "raids_insert_auth" ON raids;
DROP POLICY IF EXISTS "raids_update_host" ON raids;
DROP POLICY IF EXISTS "raids_delete_host" ON raids;

DROP POLICY IF EXISTS "rp_select_own" ON raid_participants;
DROP POLICY IF EXISTS "rp_select_raid_participants" ON raid_participants;
DROP POLICY IF EXISTS "rp_select_raid_host" ON raid_participants;
DROP POLICY IF EXISTS "rp_select_same_raid" ON raid_participants;
DROP POLICY IF EXISTS "rp_insert_public" ON raid_participants;
DROP POLICY IF EXISTS "rp_update_own" ON raid_participants;
DROP POLICY IF EXISTS "rp_update_host" ON raid_participants;
DROP POLICY IF EXISTS "rp_delete_own" ON raid_participants;

-- ============================================================
-- 3. ENABLE RLS (en caso de que esté DISABLED)
-- ============================================================

ALTER TABLE raids ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_participants ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. raids — SELECT policies
-- ============================================================

-- 4a. Public raids in lobby/planned
CREATE POLICY "raids_select_public" ON raids
  FOR SELECT USING (
    is_public = true AND status IN ('planned', 'lobby')
  );

-- 4b. Participant can see the raid (SECURITY DEFINER → no recursion)
CREATE POLICY "raids_select_participant" ON raids
  FOR SELECT USING (public.is_raid_participant(id));

-- 4c. Club members can see club raids
CREATE POLICY "raids_select_club_member" ON raids
  FOR SELECT USING (
    clan_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM club_members
      WHERE club_id = raids.clan_id AND user_id = auth.uid()
    )
  );

-- 4d. Host sees own raids
CREATE POLICY "raids_select_host" ON raids
  FOR SELECT USING (auth.uid() = host_id);

-- ============================================================
-- 5. raids — INSERT / UPDATE / DELETE
-- ============================================================

CREATE POLICY "raids_insert_auth" ON raids
  FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_update_host" ON raids
  FOR UPDATE USING (auth.uid() = host_id)
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_delete_host" ON raids
  FOR DELETE USING (auth.uid() = host_id);

-- ============================================================
-- 6. raid_participants — SELECT
-- ============================================================

-- 6a. Own participation
CREATE POLICY "rp_select_own" ON raid_participants
  FOR SELECT USING (auth.uid() = user_id);

-- 6b. Same raid participants (SECURITY DEFINER → no recursion)
CREATE POLICY "rp_select_same_raid" ON raid_participants
  FOR SELECT USING (public.is_raid_participant(raid_id));

-- 6c. Host sees all participants
CREATE POLICY "rp_select_raid_host" ON raid_participants
  FOR SELECT USING (public.is_raid_host(raid_id));

-- ============================================================
-- 7. raid_participants — INSERT
-- ============================================================

CREATE POLICY "rp_insert_public" ON raid_participants
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND public.is_raid_joinable(raid_id)
  );

-- ============================================================
-- 8. raid_participants — UPDATE
-- ============================================================

CREATE POLICY "rp_update_own" ON raid_participants
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "rp_update_host" ON raid_participants
  FOR UPDATE USING (public.is_raid_host(raid_id));

-- ============================================================
-- 9. raid_participants — DELETE
-- ============================================================

CREATE POLICY "rp_delete_own" ON raid_participants
  FOR DELETE USING (auth.uid() = user_id);

COMMIT;
