-- MIGRATION 001: FUNCIONES BASE
-- ============================================================
-- Funciones Háversine, XP y progresión
-- ============================================================

-- Háversine: distancia en metros entre dos coordenadas
CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT 6371000.0 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
        + COS(RADIANS(lat1)) * COS(RADIANS(lat2))
        * POWER(SIN(RADIANS(lng2 - lng1) / 2), 2)
    ));
$$;

-- Helper: está dentro de N metros?
CREATE OR REPLACE FUNCTION is_within_distance(
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    q_lat    DOUBLE PRECISION,
    q_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT haversine_distance(p_lat, p_lng, q_lat, q_lng) <= p_meters;
$$;

-- Nivel desde XP: level = floor(sqrt(total_xp / 100)) + 1
CREATE OR REPLACE FUNCTION xp_to_level(p_total_xp INT)
RETURNS INT
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT GREATEST(1, FLOOR(SQRT(p_total_xp::DOUBLE PRECISION / 100.0))::INT + 1);
$$;

-- Otorga XP, actualiza nivel, retorna nuevo total + level
CREATE OR REPLACE FUNCTION award_xp(
    p_user_id UUID,
    p_xp INT
) RETURNS TABLE(new_total_xp INT, new_level INT)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_total INT;
    v_new_level INT;
BEGIN
    INSERT INTO user_xp (user_id, total_xp, level, raids_completed, checkpoints_captured, km_traveled, updated_at)
    VALUES (p_user_id, p_xp, xp_to_level(p_xp), 0, 0, 0.0, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        total_xp  = user_xp.total_xp + p_xp,
        level     = xp_to_level(user_xp.total_xp + p_xp),
        updated_at = NOW()
    RETURNING total_xp, level INTO v_current_total, v_new_level;

    RETURN QUERY SELECT v_current_total AS new_total_xp, v_new_level;
END;
$$;

-- Incrementa checkpoints_taken (usado por Edge Function)
CREATE OR REPLACE FUNCTION increment_checkpoints(p_participant_id BIGINT)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new INT;
BEGIN
    UPDATE raid_participants
    SET checkpoints_taken = checkpoints_taken + 1
    WHERE id = p_participant_id
    RETURNING checkpoints_taken INTO v_new;
    RETURN v_new;
END;
$$;

-- Incrementa upvotes en road_alerts
CREATE OR REPLACE FUNCTION increment_alert_upvote(p_alert_id BIGINT)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_new INT;
BEGIN
    UPDATE road_alerts
    SET upvotes = upvotes + 1
    WHERE id = p_alert_id
    RETURNING upvotes INTO v_new;
    RETURN v_new;
END;
$$;

-- (get_nearby_places movida a migration 002 después de crear places)