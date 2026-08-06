-- Migration 024: Tourist POI support
-- Extends motoposadas table with tourist POI subtype fields
-- and users table (the profile table in this project) with curator fields.
--
-- NOTE (2026-08-05): original draft referenced a `profiles` table that never
-- existed in this project — the profile table is `users` everywhere else
-- (001/002/009). The APK has been writing poi_type='tourist' since v0.8.0, so
-- this migration was required but never applied; the wrong table name made
-- every apply fail with 42P01. Corrected to `users`.

-- ============================================================
-- 1. Extend users table with curator fields
-- ============================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_city_curator BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS curator_city TEXT;

-- ============================================================
-- 2. Extend motoposadas table with tourist POI fields
-- ============================================================
ALTER TABLE motoposadas
  ADD COLUMN IF NOT EXISTS poi_type TEXT DEFAULT 'standard',
  ADD COLUMN IF NOT EXISTS is_tourist BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS city TEXT;

-- ============================================================
-- 3. RLS: curator-only create for tourist POIs
-- ============================================================
CREATE POLICY "curator_create_tourist" ON motoposadas
  FOR INSERT WITH CHECK (
    (poi_type IS DISTINCT FROM 'tourist') OR
    (poi_type = 'tourist' AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND is_city_curator = true
        AND curator_city = city
    ))
  );
