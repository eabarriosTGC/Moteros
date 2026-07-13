-- Club Access Codes + Admin Approval Migration
-- Run: psql -h db.PROJECT_REF.supabase.co -U postgres -d postgres -f 006_club_access_codes.sql
-- Or via Supabase Dashboard > SQL Editor

-- Add access code and approval flag to clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT false;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS join_code VARCHAR(10) UNIQUE;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT false;

-- Function to generate unique join code
CREATE OR REPLACE FUNCTION generate_club_join_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.join_code = upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
  RETURN NEW;
END;
$$;

-- Trigger to auto-generate code on club creation
DROP TRIGGER IF EXISTS trg_club_join_code ON clubs;
CREATE TRIGGER trg_club_join_code
  BEFORE INSERT ON clubs
  FOR EACH ROW
  EXECUTE FUNCTION generate_club_join_code();

-- Add admin flag to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
