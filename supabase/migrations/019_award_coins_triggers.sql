-- MIGRATION 019: AWARD COINS ON RAID COMPLETION + CHECKPOINT
-- ============================================================
-- En lugar de modificar Edge Functions (requieren sbp_ token),
-- creamos triggers en DB que otorgan coins cuando:
-- 1. Un raid se completa (status → 'completed')
-- 2. Un checkpoint se valida (insert en raid_checkpoint_verifications)
--
-- Coins por modo de juego:
--   aventura: 10, velocidad: 15, precision: 12,
--   sobrevivencia: 25, exploracion: 5
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Función: otorgar coins al completar raid
-- ============================================================

CREATE OR REPLACE FUNCTION award_coins_on_raid_complete()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_base_coins INT;
  v_bonus_coins INT := 0;
  v_participant RECORD;
BEGIN
  -- Only fire when status changes TO 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    -- Base coins by mode
    v_base_coins := CASE NEW.mode
      WHEN 'aventura' THEN 10
      WHEN 'velocidad' THEN 15
      WHEN 'precision' THEN 12
      WHEN 'sobrevivencia' THEN 25
      WHEN 'exploracion' THEN 5
      ELSE 5
    END;

    -- Night raid bonus
    IF NEW.is_night_raid THEN
      v_base_coins := ROUND(v_base_coins * 1.1);
    END IF;

    -- Award coins to each completed participant
    FOR v_participant IN
      SELECT rp.id, rp.user_id, rp.checkpoints_taken, rp.is_flagged,
             ux.current_streak, ux.last_raid_date
      FROM raid_participants rp
      LEFT JOIN user_xp ux ON ux.user_id = rp.user_id
      WHERE rp.raid_id = NEW.id AND rp.is_completed = TRUE
    LOOP
      -- Skip flagged participants
      IF v_participant.is_flagged THEN
        CONTINUE;
      END IF;

      -- Calculate coins
      v_bonus_coins := 0;

      -- First raid of the day bonus
      IF v_participant.last_raid_date IS NULL
         OR v_participant.last_raid_date < CURRENT_DATE THEN
        v_bonus_coins := v_bonus_coins + 5;
      END IF;

      -- Award
      UPDATE user_xp
      SET coins = coins + v_base_coins + v_bonus_coins
      WHERE user_id = v_participant.user_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_coins_on_raid_complete ON raids;
CREATE TRIGGER trg_award_coins_on_raid_complete
  AFTER UPDATE OF status ON raids
  FOR EACH ROW
  EXECUTE FUNCTION award_coins_on_raid_complete();

-- ============================================================
-- 2. Función: otorgar coins al validar checkpoint
-- ============================================================

CREATE OR REPLACE FUNCTION award_coins_on_checkpoint()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_coins INT := 5; -- base per checkpoint
  v_user_id UUID;
BEGIN
  -- Get the user who owns this participant record
  SELECT user_id INTO v_user_id
  FROM raid_participants
  WHERE id = NEW.raid_participant_id;

  -- Hidden checkpoint bonus
  IF EXISTS (
    SELECT 1 FROM raid_checkpoints
    WHERE id = NEW.checkpoint_id AND is_hidden = TRUE
  ) THEN
    v_coins := v_coins + 10;
  END IF;

  -- Photo bonus
  IF NEW.photo_url IS NOT NULL THEN
    v_coins := v_coins + 3;
  END IF;

  -- Award coins to user_xp
  UPDATE user_xp
  SET coins = coins + v_coins
  WHERE user_id = v_user_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_award_coins_on_checkpoint ON raid_checkpoint_verifications;
CREATE TRIGGER trg_award_coins_on_checkpoint
  AFTER INSERT ON raid_checkpoint_verifications
  FOR EACH ROW
  EXECUTE FUNCTION award_coins_on_checkpoint();

COMMIT;
