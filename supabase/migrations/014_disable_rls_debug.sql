-- TEMP: Disable RLS on raids and raid_participants to debug
-- Both tables have infinite recursion RLS issues.
-- Will re-enable with simpler policies after confirmation.

ALTER TABLE raid_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE raids DISABLE ROW LEVEL SECURITY;
