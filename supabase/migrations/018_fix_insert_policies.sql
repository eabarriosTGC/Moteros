-- MIGRATION 018: FIX INSERT POLICIES FOR club_members + raid_participants
-- ============================================================
-- Problema: Al crear un club, el fundador no puede insertarse
-- como miembro porque members_insert requiere que YA sea
-- presidente/oficial (chicken-and-egg).
--
-- Solución: Agregar excepción para el fundador del club.
-- Si auth.uid() == founder_id del club, puede insertarse.
--
-- Misma lógica para raid_participants: agregar que el host
-- siempre puede insertarse en su propio raid.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Fix club_members insert policy
-- ============================================================

DROP POLICY IF EXISTS "members_insert" ON club_members;

CREATE POLICY "members_insert" ON club_members
  FOR INSERT WITH CHECK (
    -- Self-insert: founder creating the club
    (auth.uid() = user_id
     AND EXISTS (
       SELECT 1 FROM clubs
       WHERE id = club_members.club_id
       AND founder_id = auth.uid()
     ))
    OR
    -- Invite/approve by presidente or oficial
    EXISTS (
      SELECT 1 FROM club_members cm
      WHERE cm.club_id = club_members.club_id
        AND cm.user_id = auth.uid()
        AND cm.role IN ('presidente', 'oficial')
    )
  );

-- ============================================================
-- 2. Fix raid_participants insert policy (belt-and-suspenders)
-- ============================================================

DROP POLICY IF EXISTS "rp_insert_public" ON raid_participants;

CREATE POLICY "rp_insert_public" ON raid_participants
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND (
      -- Raid is joinable (public + lobby, or my own raid)
      public.is_raid_joinable(raid_id)
      OR
      -- Host can always join their own raid (belt)
      public.is_raid_host(raid_id)
    )
  );

COMMIT;
