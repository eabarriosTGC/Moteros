-- MIGRATION 007: RLS POLICIES
-- ============================================================
-- Row Level Security policies para todas las tablas
-- ============================================================

BEGIN;

-- 4.1 Habilitar RLS en todas las tablas
DO $$ DECLARE
    t TEXT;
BEGIN
    FOR t IN
        SELECT unnest(ARRAY['users', 'user_follows', 'memberships', 'places', 'visits',
            'allies', 'evidence_photos', 'saved_routes', 'road_alerts', 'challenges',
            'user_challenges', 'patches', 'user_patches', 'clans', 'clan_members', 'clubs', 'club_members',
            'raids', 'raid_participants', 'raid_checkpoints', 'raid_checkpoint_verifications',
            'raid_messages', 'clan_messages', 'user_xp', 'achievements', 'user_achievements',
            'leaderboard_snapshots', 'drive_scores', 'voice_channels', 'mentor_relationships',
            'conduct_reports', 'shop_items', 'user_purchases', 'battle_passes',
            'battle_pass_progress', 'battle_pass_missions', 'user_missions_progress',
            'anti_cheat_log', 'sos_events', 'raid_spectators', 'raid_position_log', 'clan_territories'])
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    END LOOP;
END $$;

-- Helper: admin check
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = auth.uid()
        AND raw_user_meta_data->>'role' = 'admin'
    );
$$;

-- ============================================================
-- 4.2 users
-- ============================================================
CREATE POLICY "users_select_public" ON users FOR SELECT USING (true);
CREATE POLICY "users_insert_own" ON users FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "users_update_own" ON users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "users_delete_admin" ON users FOR DELETE USING (is_admin());

-- ============================================================
-- 4.3 user_follows
-- ============================================================
CREATE POLICY "follows_select_own" ON user_follows FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = followed_id);
CREATE POLICY "follows_insert_own" ON user_follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete_own" ON user_follows FOR DELETE USING (auth.uid() = follower_id);

-- ============================================================
-- 4.4 memberships
-- ============================================================
CREATE POLICY "memberships_select_own" ON memberships FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "memberships_insert_own" ON memberships FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.5 places
-- ============================================================
CREATE POLICY "places_select_public" ON places FOR SELECT USING (true);
CREATE POLICY "places_insert_auth" ON places FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "places_update_own_or_premium" ON places
    FOR UPDATE USING (
        auth.uid() = created_by OR
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND membership_tier = 'premium')
    );
CREATE POLICY "places_delete_admin" ON places FOR DELETE USING (is_admin());

-- ============================================================
-- 4.6 visits
-- ============================================================
CREATE POLICY "visits_select_own" ON visits FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "visits_insert_own" ON visits FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.7 allies
-- ============================================================
CREATE POLICY "allies_select_public" ON allies FOR SELECT USING (true);
CREATE POLICY "allies_insert_admin" ON allies FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "allies_update_admin" ON allies FOR UPDATE USING (is_admin());
CREATE POLICY "allies_delete_admin" ON allies FOR DELETE USING (is_admin());

-- ============================================================
-- 4.8 evidence_photos
-- ============================================================
CREATE POLICY "evphotos_select_own" ON evidence_photos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "evphotos_insert_own" ON evidence_photos FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.9 saved_routes
-- ============================================================
CREATE POLICY "routes_select_own" ON saved_routes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "routes_insert_own" ON saved_routes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "routes_delete_own" ON saved_routes FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.10 road_alerts
-- ============================================================
CREATE POLICY "alerts_select_public" ON road_alerts FOR SELECT USING (active = true);
CREATE POLICY "alerts_select_own" ON road_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "alerts_insert_own" ON road_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "alerts_update_own" ON road_alerts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "alerts_delete_own" ON road_alerts FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.11 challenges / user_challenges / patches / user_patches
-- ============================================================
CREATE POLICY "challenges_select_public" ON challenges FOR SELECT USING (true);
CREATE POLICY "uchallenges_select_own" ON user_challenges FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "uchallenges_update_own" ON user_challenges FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "patches_select_public" ON patches FOR SELECT USING (true);
CREATE POLICY "upatches_select_own" ON user_patches FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- 4.12 clans
-- ============================================================
CREATE POLICY "clans_select_public" ON clans FOR SELECT USING (is_public = true);
CREATE POLICY "clans_select_member" ON clans FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clans.id AND user_id = auth.uid())
);
CREATE POLICY "clans_insert_auth" ON clans FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "clans_update_founder_captain" ON clans
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role IN ('founder', 'captain'))
    );
CREATE POLICY "clans_delete_founder" ON clans
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role = 'founder')
    );

-- ============================================================
-- 4.13 clan_members
-- ============================================================
CREATE POLICY "cm_select_own" ON clan_members FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "cm_select_clan_member" ON clan_members FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id AND cm2.user_id = auth.uid())
);
CREATE POLICY "cm_insert_public" ON clan_members FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM clans WHERE id = clan_id AND is_public = true)
);
CREATE POLICY "cm_insert_invite" ON clan_members FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain'))
);
CREATE POLICY "cm_update_role" ON clan_members FOR UPDATE USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role = 'founder')
);
CREATE POLICY "cm_delete_self" ON clan_members FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "cm_delete_management" ON clan_members FOR DELETE USING (
    EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
        AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain'))
);

-- ============================================================
-- 4.14 raids
-- ============================================================
CREATE POLICY "raids_select_public" ON raids FOR SELECT USING (
    is_public = true AND status IN ('planned', 'lobby')
);
CREATE POLICY "raids_select_participant" ON raids FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = id AND user_id = auth.uid())
);
CREATE POLICY "raids_select_clan_member" ON raids FOR SELECT USING (
    clan_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = raids.clan_id AND user_id = auth.uid())
);
CREATE POLICY "raids_select_host" ON raids FOR SELECT USING (auth.uid() = host_id);
CREATE POLICY "raids_insert_auth" ON raids FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "raids_update_host" ON raids FOR UPDATE USING (auth.uid() = host_id) WITH CHECK (auth.uid() = host_id);
CREATE POLICY "raids_delete_host" ON raids FOR DELETE USING (auth.uid() = host_id);

-- ============================================================
-- 4.15 raid_participants
-- ============================================================
CREATE POLICY "rp_select_own" ON raid_participants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "rp_select_raid_participants" ON raid_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants rp2 WHERE rp2.raid_id = raid_participants.raid_id AND rp2.user_id = auth.uid())
);
CREATE POLICY "rp_select_raid_host" ON raid_participants FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rp_insert_public" ON raid_participants FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raids WHERE id = raid_id
        AND (is_public = true OR host_id = auth.uid())
        AND status = 'lobby')
);
CREATE POLICY "rp_update_own" ON raid_participants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "rp_update_host" ON raid_participants FOR UPDATE USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rp_delete_own" ON raid_participants FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.16 raid_checkpoints
-- ============================================================
CREATE POLICY "rc_select_participant" ON raid_checkpoints FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_checkpoints.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rc_select_host" ON raid_checkpoints FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_checkpoints.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rc_insert_host" ON raid_checkpoints FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
);
CREATE POLICY "rc_delete_host" ON raid_checkpoints FOR DELETE USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
);

-- ============================================================
-- 4.17 raid_checkpoint_verifications
-- ============================================================
CREATE POLICY "rcv_select_own" ON raid_checkpoint_verifications FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
);
CREATE POLICY "rcv_select_raid_host" ON raid_checkpoint_verifications FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM raid_participants rp
        JOIN raids r ON r.id = rp.raid_id
        WHERE rp.id = raid_checkpoint_verifications.raid_participant_id
        AND r.host_id = auth.uid()
    )
);
CREATE POLICY "rcv_insert_own" ON raid_checkpoint_verifications FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
);

-- ============================================================
-- 4.18 raid_messages
-- ============================================================
CREATE POLICY "rm_select_participant" ON raid_messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rm_insert_participant" ON raid_messages FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
);
CREATE POLICY "rm_delete_own" ON raid_messages FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.19 clan_messages
-- ============================================================
CREATE POLICY "cm_select_clan_member" ON clan_messages FOR SELECT USING (
    EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
);
CREATE POLICY "cm_insert_clan_member" ON clan_messages FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
);
CREATE POLICY "cm_delete_own" ON clan_messages FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4.20 user_xp
-- ============================================================
CREATE POLICY "xp_select_all" ON user_xp FOR SELECT USING (true);
CREATE POLICY "xp_insert_own" ON user_xp FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4.21 achievements / user_achievements / leaderboard_snapshots
-- ============================================================
CREATE POLICY "achievements_select_public" ON achievements FOR SELECT USING (true);
CREATE POLICY "ua_select_all" ON user_achievements FOR SELECT USING (true);
CREATE POLICY "ua_insert_system" ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');
CREATE POLICY "lb_select_public" ON leaderboard_snapshots FOR SELECT USING (true);

-- ============================================================
-- 4.22 Tablas de seguridad y economía (RLS restrictiva)
-- ============================================================
-- drive_scores: solo el participante y el host del raid
CREATE POLICY "ds_select_own" ON drive_scores FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM raid_participants rp JOIN raids r ON r.id = rp.raid_id WHERE rp.id = raid_participant_id AND r.host_id = auth.uid())
);

-- sos_events: participantes del raid y clan pueden ver
CREATE POLICY "sos_select_raid_participant" ON sos_events FOR SELECT USING (
    EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = sos_events.raid_id AND user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM clan_members cm JOIN raids r ON r.clan_id = cm.clan_id WHERE r.id = sos_events.raid_id AND cm.user_id = auth.uid())
    OR is_admin()
);

-- anti_cheat_log: solo admins
CREATE POLICY "acl_select_admin" ON anti_cheat_log FOR SELECT USING (is_admin());
CREATE POLICY "acl_insert_system" ON anti_cheat_log FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- conduct_reports: solo admins y reportado
CREATE POLICY "cr_select_admin_or_reported" ON conduct_reports FOR SELECT USING (
    is_admin() OR auth.uid() = reported_id
);

-- shop_items: lectura pública
CREATE POLICY "shop_select_public" ON shop_items FOR SELECT USING (is_active = true);
CREATE POLICY "shop_insert_admin" ON shop_items FOR INSERT WITH CHECK (is_admin());

-- user_purchases: solo propio usuario
CREATE POLICY "up_select_own" ON user_purchases FOR SELECT USING (auth.uid() = user_id);

-- battle_pass: lectura pública
CREATE POLICY "bp_select_public" ON battle_passes FOR SELECT USING (true);
CREATE POLICY "bpp_select_own" ON battle_pass_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "bpm_select_public" ON battle_pass_missions FOR SELECT USING (true);
CREATE POLICY "ump_select_own" ON user_missions_progress FOR SELECT USING (auth.uid() = user_id);

-- raid_spectators: propio y host
CREATE POLICY "rs_select_own" ON raid_spectators FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "rs_select_host" ON raid_spectators FOR SELECT USING (
    EXISTS (SELECT 1 FROM raids WHERE id = raid_spectators.raid_id AND host_id = auth.uid())
);
CREATE POLICY "rs_insert_spectator" ON raid_spectators FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND status = 'active' AND allow_spectators = true)
);
CREATE POLICY "rs_update_own" ON raid_spectators FOR UPDATE USING (auth.uid() = user_id);

-- voice_channels: participantes del raid o miembros del clan
CREATE POLICY "vc_select_participant" ON voice_channels FOR SELECT USING (
    (raid_id IS NOT NULL AND EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = voice_channels.raid_id AND user_id = auth.uid()))
    OR (clan_id IS NOT NULL AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = voice_channels.clan_id AND user_id = auth.uid()))
);

COMMIT;
