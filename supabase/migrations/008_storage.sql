-- MIGRATION 008: STORAGE BUCKETS Y POLICIES
-- ============================================================
-- Buckets de almacenamiento y RLS policies para storage.objects
-- ============================================================

BEGIN;

-- Crear buckets
INSERT INTO storage.buckets (id, name, public) VALUES
    ('clan-logos', 'clan-logos', true),
    ('profile-images', 'profile-images', true),
    ('checkpoint-evidence', 'checkpoint-evidence', true),
    ('place-photos', 'place-photos', true)
ON CONFLICT (id) DO NOTHING;

-- === clan-logos ===
CREATE POLICY "clan_logos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'clan-logos');
CREATE POLICY "clan_logos_insert_founder_captain" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'clan-logos'
        AND auth.role() = 'authenticated'
    );
CREATE POLICY "clan_logos_delete_founder_captain" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'clan-logos'
        AND EXISTS (
            SELECT 1 FROM clan_members cm
            JOIN clans c ON c.id = cm.clan_id
            WHERE cm.user_id = auth.uid()
            AND cm.role IN ('founder', 'captain')
        )
    );

-- === profile-images ===
CREATE POLICY "profile_images_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile-images');
CREATE POLICY "profile_images_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );
CREATE POLICY "profile_images_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

-- === checkpoint-evidence ===
CREATE POLICY "checkpoint_evidence_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'checkpoint-evidence');
CREATE POLICY "checkpoint_evidence_insert_auth" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'checkpoint-evidence'
        AND auth.role() = 'authenticated'
    );

-- === place-photos ===
CREATE POLICY "place_photos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'place-photos');
CREATE POLICY "place_photos_insert_auth" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'place-photos'
        AND auth.role() = 'authenticated'
    );

COMMIT;
