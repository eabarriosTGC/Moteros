-- FIX: Use SECURITY DEFINER function to break RLS recursion
-- rp_select_raid_host → raids → rp_select_raid_host → ∞
-- By using SECURITY DEFINER, the inner check on `raids` bypasses RLS

BEGIN;

DROP POLICY IF EXISTS rp_select_raid_host ON raid_participants;

CREATE OR REPLACE FUNCTION public.is_raid_host(p_raid_id bigint)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM raids WHERE id = p_raid_id AND host_id = auth.uid()
  );
$$;

CREATE POLICY rp_select_raid_host ON raid_participants
  FOR SELECT USING (public.is_raid_host(raid_id));

COMMIT;
