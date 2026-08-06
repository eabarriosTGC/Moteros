-- MIGRATION 029: bucket conquest-photos (W4 — conquest photos upload)
-- Patrón de 008_storage.sql: buckets públicos (008:9-14) + insert/delete
-- propios por prefijo de user_id (008:35-47, profile-images).
BEGIN;

INSERT INTO storage.buckets (id, name, public) VALUES
    ('conquest-photos', 'conquest-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Lectura pública (las fotos de conquista son públicas en el álbum; la
-- frontera de borrado/inserción es del dueño).
DROP POLICY IF EXISTS "conquest_photos_select_public" ON storage.objects;
CREATE POLICY "conquest_photos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'conquest-photos');

-- Insert/delete propios: path con prefijo <user_id>/ (008:41-47).
DROP POLICY IF EXISTS "conquest_photos_insert_own" ON storage.objects;
CREATE POLICY "conquest_photos_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'conquest-photos'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

DROP POLICY IF EXISTS "conquest_photos_delete_own" ON storage.objects;
CREATE POLICY "conquest_photos_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'conquest-photos'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

COMMIT;
