-- MIGRATION 005: TRIGGERS Y FUNCIONES ASOCIADAS
-- ============================================================
-- Triggers: updated_at automático, streaks, achievements,
-- post-signup handler, night raid detection
-- ============================================================

BEGIN;

-- 2.1 Updated_at automático
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_places_updated_at
    BEFORE UPDATE ON places
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_clans_updated_at
    BEFORE UPDATE ON clans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_raids_updated_at
    BEFORE UPDATE ON raids
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_user_xp_updated_at
    BEFORE UPDATE ON user_xp
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 2.2 Streak trigger (al completar raid)
CREATE OR REPLACE FUNCTION update_streak()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_last_date DATE;
    v_today DATE := CURRENT_DATE;
BEGIN
    SELECT last_raid_date INTO v_last_date
    FROM user_xp WHERE user_id = NEW.user_id;

    IF v_last_date IS NULL THEN
        UPDATE user_xp SET
            current_streak = 1,
            longest_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date = v_today - INTERVAL '1 day' THEN
        UPDATE user_xp SET
            current_streak = current_streak + 1,
            longest_streak = GREATEST(longest_streak, current_streak + 1),
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date < v_today - INTERVAL '1 day' THEN
        UPDATE user_xp SET
            current_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_streak
    AFTER UPDATE OF is_completed ON raid_participants
    FOR EACH ROW
    WHEN (NEW.is_completed = TRUE AND OLD.is_completed = FALSE)
    EXECUTE FUNCTION update_streak();

-- 2.3 Achievement checker (al actualizar user_xp)
CREATE OR REPLACE FUNCTION check_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_ach RECORD;
    v_bonus_xp INT;
BEGIN
    FOR v_ach IN SELECT * FROM achievements
    LOOP
        IF NOT EXISTS (SELECT 1 FROM user_achievements WHERE user_id = NEW.user_id AND achievement_id = v_ach.id) THEN
            CASE v_ach.criteria->>'type'
                WHEN 'raids_completed' THEN
                    IF NEW.raids_completed >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'checkpoints_captured' THEN
                    IF NEW.checkpoints_captured >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'km_traveled' THEN
                    IF NEW.km_traveled >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'mode_wins' THEN
                    -- Evaluado por finish_raid EF
                    NULL;
                WHEN 'clan_founded' THEN
                    NULL; -- Evaluado externamente
                WHEN 'clan_members' THEN
                    NULL;
                WHEN 'following_count' THEN
                    NULL;
                WHEN 'membership_activated' THEN
                    NULL;
                WHEN 'streak_days' THEN
                    IF NEW.longest_streak >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'pings_sent' THEN
                    NULL; -- Evaluado externamente
                WHEN 'full_route_completion' THEN
                    NULL; -- Evaluado por finish_raid EF
                WHEN 'raids_as_host' THEN
                    NULL; -- Evaluado externamente
                ELSE NULL;
            END CASE;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_achievements
    AFTER UPDATE OF raids_completed, checkpoints_captured, km_traveled ON user_xp
    FOR EACH ROW
    EXECUTE FUNCTION check_achievements();

-- 2.4 Post-signup: crear registro en users
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.users (id, full_name, username)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'username', 'motero_' || SUBSTRING(NEW.id::TEXT, 1, 8))
    );
    INSERT INTO public.user_xp (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_handle_new_user
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- 2.5 Detectar raids nocturnos al INSERT/UPDATE
CREATE OR REPLACE FUNCTION check_night_raid()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXTRACT(HOUR FROM NEW.scheduled_at AT TIME ZONE 'America/Argentina/Buenos_Aires') >= 20
       OR EXTRACT(HOUR FROM NEW.scheduled_at AT TIME ZONE 'America/Argentina/Buenos_Aires') < 6 THEN
        NEW.is_night_raid = TRUE;
    ELSE
        NEW.is_night_raid = FALSE;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_night_raid
    BEFORE INSERT OR UPDATE OF scheduled_at ON raids
    FOR EACH ROW
    EXECUTE FUNCTION check_night_raid();

COMMIT;
