-- 038: Fix triggers SECURITY DEFINER con referencias sin calificar.
--
-- EVIDENCIA (no hipótesis):
--   1. El log de Supabase del 404 de verify_raid_arrival expone el header:
--      proxy_status: "PostgREST; error=42P01" (undefined_table).
--   2. Reproducción con claims JWT seteados (request.jwt.claim.sub/role):
--      ERROR: 42P01: relation "achievements" does not exist
--      QUERY:  SELECT * FROM achievements
--      CONTEXT: PL/pgSQL function public.check_achievements() line 6
--      SQL statement: INSERT INTO public.user_xp(...)
--      (y luego el mismo 42P01 en award_coins_on_achievement al insertar en
--      user_achievements).
--
-- Causa: los triggers SECURITY DEFINER de la cadena de logros/monedas
-- referencian tablas SIN calificar y heredan el search_path del caller.
-- verify_raid_arrival corre con SET search_path = '' → 42P01 → PostgREST
-- mapea el error interno a 404. El raid 16 (TOO_FAR) no llegaba al INSERT
-- de user_xp; el 17 sí. Sin search_path explícito, la misma clase de bug
-- podía romper en cualquier otro flujo según el caller.
--
-- Fix: calificar todas las referencias (public.*) y fijar search_path = ''
-- explícito en las 5 funciones de la clase. Los triggers no cambian.

BEGIN;

-- 1) check_achievements: AFTER UPDATE de user_xp (raids_completed, km, ...)
CREATE OR REPLACE FUNCTION public.check_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ach RECORD;
    v_bonus_xp INT;
BEGIN
    FOR v_ach IN SELECT * FROM public.achievements
    LOOP
        IF NOT EXISTS (SELECT 1 FROM public.user_achievements
                       WHERE user_id = NEW.user_id AND achievement_id = v_ach.id) THEN
            CASE v_ach.criteria->>'type'
                WHEN 'raids_completed' THEN
                    IF NEW.raids_completed >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO public.user_achievements (user_id, achievement_id)
                        VALUES (NEW.user_id, v_ach.id);
                        UPDATE public.user_xp
                        SET total_xp = total_xp + v_ach.xp_reward,
                            level = public.xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'checkpoints_captured' THEN
                    IF NEW.checkpoints_captured >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO public.user_achievements (user_id, achievement_id)
                        VALUES (NEW.user_id, v_ach.id);
                        UPDATE public.user_xp
                        SET total_xp = total_xp + v_ach.xp_reward,
                            level = public.xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'km_traveled' THEN
                    IF NEW.km_traveled >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO public.user_achievements (user_id, achievement_id)
                        VALUES (NEW.user_id, v_ach.id);
                        UPDATE public.user_xp
                        SET total_xp = total_xp + v_ach.xp_reward,
                            level = public.xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'streak_days' THEN
                    IF NEW.longest_streak >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO public.user_achievements (user_id, achievement_id)
                        VALUES (NEW.user_id, v_ach.id);
                        UPDATE public.user_xp
                        SET total_xp = total_xp + v_ach.xp_reward,
                            level = public.xp_to_level(total_xp)
                        WHERE user_id = NEW.user_id;
                    END IF;
                ELSE NULL; -- criterios evaluados externamente
            END CASE;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

-- 2) award_coins_on_achievement: AFTER INSERT en user_achievements
CREATE OR REPLACE FUNCTION public.award_coins_on_achievement()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_coins_reward INT;
BEGIN
    SELECT COALESCE(xp_reward / 2, 10) INTO v_coins_reward
    FROM public.achievements WHERE id = NEW.achievement_id;
    UPDATE public.user_xp
    SET coins = coins + v_coins_reward
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$;

-- 3) award_coins_on_level_up: AFTER UPDATE de level en user_xp
CREATE OR REPLACE FUNCTION public.award_coins_on_level_up()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
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
        UPDATE public.user_xp
        SET coins = coins + v_bonus
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

-- 4) award_coins_on_raid_complete: AFTER UPDATE de status en raids
CREATE OR REPLACE FUNCTION public.award_coins_on_raid_complete()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_base_coins INT;
  v_bonus_coins INT := 0;
  v_participant RECORD;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    v_base_coins := CASE NEW.mode
      WHEN 'aventura' THEN 10
      WHEN 'velocidad' THEN 15
      WHEN 'precision' THEN 12
      WHEN 'sobrevivencia' THEN 25
      WHEN 'exploracion' THEN 5
      ELSE 5
    END;
    IF NEW.is_night_raid THEN
      v_base_coins := ROUND(v_base_coins * 1.1);
    END IF;
    FOR v_participant IN
      SELECT rp.id, rp.user_id, rp.checkpoints_taken, rp.is_flagged,
             ux.current_streak, ux.last_raid_date
      FROM public.raid_participants rp
      LEFT JOIN public.user_xp ux ON ux.user_id = rp.user_id
      WHERE rp.raid_id = NEW.id AND rp.is_completed = TRUE
    LOOP
      IF v_participant.is_flagged THEN
        CONTINUE;
      END IF;
      v_bonus_coins := 0;
      IF v_participant.last_raid_date IS NULL
         OR v_participant.last_raid_date < CURRENT_DATE THEN
        v_bonus_coins := v_bonus_coins + 5;
      END IF;
      UPDATE public.user_xp
      SET coins = coins + v_base_coins + v_bonus_coins
      WHERE user_id = v_participant.user_id;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

-- 5) award_coins_on_checkpoint: AFTER INSERT en raid_checkpoint_verifications
CREATE OR REPLACE FUNCTION public.award_coins_on_checkpoint()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_coins INT := 5;
  v_user_id UUID;
BEGIN
  SELECT user_id INTO v_user_id
  FROM public.raid_participants
  WHERE id = NEW.raid_participant_id;
  IF EXISTS (
    SELECT 1 FROM public.raid_checkpoints
    WHERE id = NEW.checkpoint_id AND is_hidden = TRUE
  ) THEN
    v_coins := v_coins + 10;
  END IF;
  IF NEW.photo_url IS NOT NULL THEN
    v_coins := v_coins + 3;
  END IF;
  UPDATE public.user_xp
  SET coins = coins + v_coins
  WHERE user_id = v_user_id;
  RETURN NEW;
END;
$$;

-- 6) update_streak: AFTER UPDATE en raid_participants (misma clase de bug)
CREATE OR REPLACE FUNCTION public.update_streak()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_last_date DATE;
    v_today DATE := CURRENT_DATE;
BEGIN
    SELECT last_raid_date INTO v_last_date
    FROM public.user_xp WHERE user_id = NEW.user_id;

    IF v_last_date IS NULL THEN
        UPDATE public.user_xp SET
            current_streak = 1,
            longest_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date = v_today - INTERVAL '1 day' THEN
        UPDATE public.user_xp SET
            current_streak = current_streak + 1,
            longest_streak = GREATEST(longest_streak, current_streak + 1),
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date < v_today - INTERVAL '1 day' THEN
        UPDATE public.user_xp SET
            current_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSE
        UPDATE public.user_xp SET
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

COMMIT;
