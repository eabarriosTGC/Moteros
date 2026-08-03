-- Migration 024: Tourist POI support
-- Extends motoposadas table with tourist POI subtype fields
-- and profiles table with curator fields for authorization.

-- ============================================================
-- 1. Extend profiles table with curator fields
-- ============================================================
ALTER TABLE profiles
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
      SELECT 1 FROM profiles
      WHERE user_id = auth.uid()
        AND is_city_curator = true
        AND curator_city = city
    ))
  );
