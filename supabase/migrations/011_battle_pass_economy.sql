-- MIGRATION 011: BATTLE PASS + ECONOMY + SHOWCASE PROFILE
-- ============================================================
-- Dependencias: migrations 003 (user_xp), 004 (shop_items, battle_passes, etc.),
--               006 (seed data), 007 (RLS existentes)
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Función para otorgar coins (usada por triggers + EF)
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins(
    p_user_id UUID,
    p_coins INT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new_coins INT;
BEGIN
    UPDATE user_xp
    SET coins = coins + p_coins
    WHERE user_id = p_user_id
    RETURNING coins INTO v_new_coins;
    RETURN v_new_coins;
END;
$$;

-- ============================================================
-- 2. Función para descontar coins (usada por EF de compra)
-- ============================================================
CREATE OR REPLACE FUNCTION spend_coins(
    p_user_id UUID,
    p_coins INT
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current INT;
    v_new INT;
BEGIN
    SELECT coins INTO v_current FROM user_xp WHERE user_id = p_user_id;
    IF v_current IS NULL OR v_current < p_coins THEN
        RAISE EXCEPTION 'Coins insuficientes: tiene %, necesita %', COALESCE(v_current, 0), p_coins;
    END IF;
    UPDATE user_xp SET coins = coins - p_coins WHERE user_id = p_user_id
    RETURNING coins INTO v_new;
    RETURN v_new;
END;
$$;

-- ============================================================
-- 3. Trigger: otorgar coins al subir de nivel
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins_on_level_up()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_levels_gained INT;
    v_bonus INT;
    i INT;
BEGIN
    IF NEW.level > OLD.level THEN
        v_levels_gained := NEW.level - OLD.level;
        v_bonus := 0;
        FOR i IN 1..v_levels_gained LOOP
            v_bonus := v_bonus + (OLD.level + i) * 10;
        END LOOP;
        UPDATE user_xp SET coins = coins + v_bonus WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_coins_on_level_up ON user_xp;
CREATE TRIGGER trg_coins_on_level_up
    AFTER UPDATE OF level ON user_xp
    FOR EACH ROW
    WHEN (NEW.level > OLD.level)
    EXECUTE FUNCTION award_coins_on_level_up();

-- ============================================================
-- 4. Trigger: otorgar coins al completar logro
-- ============================================================
CREATE OR REPLACE FUNCTION award_coins_on_achievement()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_coins_reward INT;
BEGIN
    SELECT COALESCE(xp_reward / 2, 10) INTO v_coins_reward
    FROM achievements WHERE id = NEW.achievement_id;
    UPDATE user_xp SET coins = coins + v_coins_reward WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_coins_on_achievement ON user_achievements;
CREATE TRIGGER trg_coins_on_achievement
    AFTER INSERT ON user_achievements
    FOR EACH ROW
    EXECUTE FUNCTION award_coins_on_achievement();

-- ============================================================
-- 5. RLS: permitir INSERT en user_purchases (solo via EF service_role)
-- ============================================================
CREATE POLICY "up_insert_system" ON user_purchases
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 6. RLS: permitir INSERT/UPDATE en battle_pass_progress y user_missions_progress
-- ============================================================
CREATE POLICY "bpp_insert_system" ON battle_pass_progress
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "bpp_update_system" ON battle_pass_progress
    FOR UPDATE USING (auth.role() = 'service_role');
CREATE POLICY "ump_insert_system" ON user_missions_progress
    FOR INSERT WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "ump_update_system" ON user_missions_progress
    FOR UPDATE USING (auth.role() = 'service_role');

-- ============================================================
-- 7. Tabla: season_pass_xp_log (auditoría de XP de temporada)
-- ============================================================
CREATE TABLE IF NOT EXISTS season_pass_xp_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    battle_pass_id  UUID NOT NULL REFERENCES battle_passes(id) ON DELETE CASCADE,
    source          TEXT NOT NULL CHECK (source IN ('raid', 'checkpoint', 'route', 'mission', 'purchase')),
    source_id       BIGINT,
    xp_awarded      INT NOT NULL CHECK (xp_awarded > 0),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sp_xp_log_user_bp ON season_pass_xp_log(user_id, battle_pass_id);

-- ============================================================
-- 8. RPC: claim_battle_pass_tier — reclamar recompensa de tier
-- ============================================================
CREATE OR REPLACE FUNCTION claim_battle_pass_tier(
    p_user_id UUID,
    p_battle_pass_id UUID
) RETURNS TABLE(new_tier INT, claimed BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_tier INT;
    v_xp_in_season INT;
    v_xp_required INT;
    v_has_premium BOOLEAN;
    v_rewards JSONB;
    v_claimed JSONB;
BEGIN
    SELECT current_tier, xp_in_season, has_premium, claimed_rewards
    INTO v_current_tier, v_xp_in_season, v_has_premium, v_claimed
    FROM battle_pass_progress
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    IF v_current_tier IS NULL THEN
        RAISE EXCEPTION 'No hay progreso activo para este Battle Pass';
    END IF;

    IF v_claimed IS NOT NULL AND v_claimed @> to_jsonb(v_current_tier) THEN
        RETURN QUERY SELECT v_current_tier, false;
        RETURN;
    END IF;

    v_xp_required := 100 + (v_current_tier * 10);

    IF v_xp_in_season < v_xp_required THEN
        RAISE EXCEPTION 'XP insuficiente para el tier %: necesita %, tiene %',
            v_current_tier, v_xp_required, v_xp_in_season;
    END IF;

    v_claimed := COALESCE(v_claimed, '[]'::JSONB) || to_jsonb(v_current_tier);

    UPDATE battle_pass_progress
    SET claimed_rewards = v_claimed
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    RETURN QUERY SELECT v_current_tier, true;
END;
$$;

-- ============================================================
-- 9. RPC: advance_battle_pass_tier — avanzar al siguiente tier
-- ============================================================
CREATE OR REPLACE FUNCTION advance_battle_pass_tier(
    p_user_id UUID,
    p_battle_pass_id UUID
) RETURNS TABLE(new_tier INT, advanced BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_tier INT;
    v_xp_in_season INT;
    v_max_tier INT := 50;
BEGIN
    SELECT current_tier, xp_in_season
    INTO v_current_tier, v_xp_in_season
    FROM battle_pass_progress
    WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id;

    IF v_current_tier >= v_max_tier THEN
        RETURN QUERY SELECT v_current_tier, false;
        RETURN;
    END IF;

    IF v_xp_in_season >= 100 + (v_current_tier * 10) THEN
        UPDATE battle_pass_progress
        SET current_tier = current_tier + 1
        WHERE user_id = p_user_id AND battle_pass_id = p_battle_pass_id
        RETURNING current_tier INTO v_current_tier;

        RETURN QUERY SELECT v_current_tier, true;
    ELSE
        RETURN QUERY SELECT v_current_tier, false;
    END IF;
END;
$$;

-- ============================================================
-- 10. Tabla: user_showcase — items equipados en el perfil épico
-- ============================================================
CREATE TABLE IF NOT EXISTS user_showcase (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    equipped_patches UUID[] DEFAULT '{}',
    equipped_banner UUID,
    equipped_title  UUID,
    equipped_frame  UUID,
    bg_color        TEXT DEFAULT '#0A0A0F',
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 11. Tabla: conquest_photos — álbum de fotos trofeo
-- ============================================================
CREATE TABLE IF NOT EXISTS conquest_photos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source          TEXT NOT NULL CHECK (source IN ('raid', 'achievement', 'route', 'checkpoint')),
    source_id       TEXT,
    photo_url       TEXT NOT NULL,
    caption         TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_conquest_photos_user ON conquest_photos(user_id);

-- ============================================================
-- RLS para user_showcase
-- ============================================================
ALTER TABLE user_showcase ENABLE ROW LEVEL SECURITY;
CREATE POLICY "usc_select_public" ON user_showcase FOR SELECT USING (true);
CREATE POLICY "usc_update_own" ON user_showcase FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- RLS para conquest_photos
-- ============================================================
ALTER TABLE conquest_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cp_select_public" ON conquest_photos FOR SELECT USING (true);
CREATE POLICY "cp_insert_own" ON conquest_photos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "cp_delete_own" ON conquest_photos FOR DELETE USING (auth.uid() = user_id);

COMMIT;
