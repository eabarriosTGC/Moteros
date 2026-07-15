-- FIX: Recursive RLS policies on raid_participants
-- Problema: raids_select_participant → raid_participants → rp_select_raid_participants → ∞
-- Ejecutado directo en prod el 2026-07-15

BEGIN;

-- Fix: raids_select_participant comparaba raid_participants.id con raids.id,
-- pero escribia raid_participants.id en vez de raids.id (autoreferencia)
DROP POLICY IF EXISTS raids_select_participant ON raids;
CREATE POLICY raids_select_participant ON raids
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants
      WHERE raid_participants.raid_id = raids.id
      AND raid_participants.user_id = auth.uid())
  );

-- Simplify: rp_insert_public no necesita subquery a raids
-- (la validacion de que el raid existe/publico se hace desde la app)
DROP POLICY IF EXISTS rp_insert_public ON raid_participants;
CREATE POLICY rp_insert_public ON raid_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Remove: rp_select_raid_participants causaba recursion porque
-- leia raid_participants dentro de raid_participants
DROP POLICY IF EXISTS rp_select_raid_participants ON raid_participants;

COMMIT;
