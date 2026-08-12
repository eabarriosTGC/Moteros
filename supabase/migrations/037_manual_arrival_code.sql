-- 037: Código manual de llegada (8 caracteres) como credencial alternativa.
--
-- El QR y el código manual son DOS FORMAS de la MISMA credencial: ambos se
-- hashean (sha256), se comparan contra place_qr_codes y pasan por
-- verify_raid_arrival (única puerta de entrada). El código manual:
--   * 8 caracteres, mayúsculas + dígitos;
--   * excluye caracteres ambiguos: 0/O, 1/I/L;
--   * aleatorio (gen_random_bytes), no derivado de raid/club/fecha/secuencia;
--   * único entre códigos de la tabla (UNIQUE en el hash).
-- Además se registran los intentos de llegada (arrival_attempt_log) con
-- límite de fallos por usuario+raid en una ventana de 15 minutos.
--
-- Sin cambios destructivos: los QR existentes siguen funcionando.

BEGIN;

-- 1) Hash del código manual (nunca en claro), único en la tabla.
ALTER TABLE public.place_qr_codes
    ADD COLUMN IF NOT EXISTS manual_code_hash TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_place_qr_codes_manual_code
    ON public.place_qr_codes(manual_code_hash)
    WHERE manual_code_hash IS NOT NULL;

-- 2) Registro de intentos de llegada (protección contra fuerza bruta).
CREATE TABLE IF NOT EXISTS public.arrival_attempt_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    raid_id BIGINT NOT NULL REFERENCES public.raids(id) ON DELETE CASCADE,
    success BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_arrival_attempt_log_user
    ON public.arrival_attempt_log(user_id, raid_id, created_at DESC);

-- 3) generate_place_qr: además del token QR, genera el código manual.
--    Misma firma de entrada; el RETURNS gana la columna manual_code
--    (por eso se DROP primero: postgres no permite cambiar OUT con OR REPLACE).
DROP FUNCTION IF EXISTS public.generate_place_qr(BIGINT, TEXT, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.generate_place_qr(
    p_raid_id BIGINT,
    p_label TEXT,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    qr_id UUID, qr_token TEXT, label TEXT,
    manual_code TEXT, expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_place_id BIGINT;
    v_club_id BIGINT;
    v_token TEXT;
    v_manual TEXT;
    v_id UUID;
BEGIN
    SELECT raid.conquest_place_id, raid.club_id INTO v_place_id, v_club_id
    FROM public.raids raid WHERE raid.id = p_raid_id;
    IF v_uid IS NULL OR v_place_id IS NULL OR
       NOT private.is_club_president(v_club_id, v_uid) THEN
        RAISE EXCEPTION 'PRESIDENT_REQUIRED' USING ERRCODE = '42501';
    END IF;
    IF NULLIF(BTRIM(p_label), '') IS NULL THEN
        RAISE EXCEPTION 'LABEL_REQUIRED' USING ERRCODE = '22023';
    END IF;

    v_token := 'asfaltoclub:arrival:v1:' || gen_random_uuid()::text || ':' ||
               encode(extensions.gen_random_bytes(18), 'base64');
    -- 8 caracteres del alfabeto sin ambiguos (0/O, 1/I/L): 31 símbolos.
    v_manual := (
        SELECT string_agg(
            substr(
                'ABCDEFGHJKMNPQRSTUVWXYZ23456789',
                (get_byte(extensions.gen_random_bytes(1), 0) % 31) + 1,
                1
            ),
            ''
        )
        FROM generate_series(1, 8)
    );

    INSERT INTO public.place_qr_codes(
        place_id, label, token_hash, manual_code_hash, expires_at, created_by
    ) VALUES (
        v_place_id, BTRIM(p_label),
        encode(extensions.digest(v_token, 'sha256'), 'hex'),
        encode(extensions.digest(v_manual, 'sha256'), 'hex'),
        p_expires_at, v_uid
    ) RETURNING id INTO v_id;

    RETURN QUERY SELECT v_id, v_token, BTRIM(p_label), v_manual, p_expires_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.generate_place_qr(BIGINT, TEXT, TIMESTAMPTZ)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_place_qr(BIGINT, TEXT, TIMESTAMPTZ)
    TO authenticated;

-- 4) verify_raid_arrival: acepta token QR o código manual como la MISMA
--    credencial, registra intentos y limita fallos por ventana.
--    Mensajes comunes: INVALID_QR no distingue inexistente / de otro lugar /
--    revocado / expirado.
CREATE OR REPLACE FUNCTION public.verify_raid_arrival(
    p_raid_id BIGINT,
    p_qr_token TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_accuracy_meters DOUBLE PRECISION
)
RETURNS TABLE(arrival_id UUID, verified_km DOUBLE PRECISION, place_name TEXT, verified_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_credential TEXT;
    v_log_id BIGINT;
    v_raid public.raids;
    v_place public.conquest_places;
    v_qr public.place_qr_codes;
    v_attempt_id UUID;
    v_arrival_id UUID;
    v_distance DOUBLE PRECISION;
    v_now TIMESTAMPTZ := CURRENT_TIMESTAMP;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '28000'; END IF;
    IF p_accuracy_meters IS NULL OR p_accuracy_meters <= 0 OR p_accuracy_meters > 100 THEN
        RAISE EXCEPTION 'GPS_ACCURACY_TOO_LOW' USING ERRCODE = '22023';
    END IF;

    v_credential := BTRIM(p_qr_token);
    IF v_credential = '' THEN
        RAISE EXCEPTION 'INVALID_QR' USING ERRCODE = '22023';
    END IF;

    -- Registro de intento y límite de fallos (5 por usuario+raid en 15 min).
    INSERT INTO public.arrival_attempt_log(user_id, raid_id)
    VALUES (v_uid, p_raid_id)
    RETURNING id INTO v_log_id;
    IF (SELECT count(*)
        FROM public.arrival_attempt_log a
        WHERE a.user_id = v_uid AND a.raid_id = p_raid_id
          AND a.success = FALSE
          AND a.created_at > v_now - INTERVAL '15 minutes'
       ) >= 5 THEN
        RAISE EXCEPTION 'TOO_MANY_ATTEMPTS' USING ERRCODE = '42900';
    END IF;

    SELECT * INTO v_raid FROM public.raids raid
    WHERE raid.id = p_raid_id AND raid.status IN ('planned', 'lobby', 'active');
    IF NOT FOUND OR v_raid.conquest_place_id IS NULL OR v_raid.distance_km IS NULL THEN
        RAISE EXCEPTION 'RAID_NOT_AVAILABLE' USING ERRCODE = 'P0002';
    END IF;
    IF v_raid.raid_type = 'scheduled' THEN
        IF v_now < v_raid.starts_at - INTERVAL '2 hours' OR v_now > v_raid.ends_at THEN
            RAISE EXCEPTION 'OUTSIDE_EVENT_WINDOW' USING ERRCODE = '22023';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM public.raid_participants participant
            WHERE participant.raid_id = v_raid.id AND participant.user_id = v_uid
        ) THEN
            RAISE EXCEPTION 'JOIN_REQUIRED' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT * INTO v_place FROM public.conquest_places place
    WHERE place.id = v_raid.conquest_place_id AND place.is_active;

    -- La credencial puede ser el token QR o el código manual (mismo hash).
    SELECT * INTO v_qr FROM public.place_qr_codes code
    WHERE code.place_id = v_place.id
      AND (
        code.token_hash = encode(extensions.digest(v_credential, 'sha256'), 'hex')
        OR code.manual_code_hash = encode(extensions.digest(v_credential, 'sha256'), 'hex')
      )
      AND code.is_active
      AND (code.expires_at IS NULL OR code.expires_at >= v_now);
    IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_QR' USING ERRCODE = '22023'; END IF;

    v_distance := private.haversine_meters(
        p_latitude, p_longitude, v_place.latitude, v_place.longitude
    );
    IF v_distance > v_place.radius_meters THEN
        RAISE EXCEPTION 'TOO_FAR_FROM_DESTINATION:%', ROUND(v_distance)
            USING ERRCODE = '22023';
    END IF;
    IF EXISTS (SELECT 1 FROM public.raid_arrivals a WHERE a.raid_id = v_raid.id AND a.user_id = v_uid) THEN
        RAISE EXCEPTION 'ALREADY_VERIFIED' USING ERRCODE = '23505';
    END IF;

    INSERT INTO public.raid_attempts(raid_id, user_id, status, completed_at)
    VALUES (v_raid.id, v_uid, 'completed', v_now)
    RETURNING id INTO v_attempt_id;

    INSERT INTO public.raid_arrivals(
        attempt_id, raid_id, user_id, place_id, qr_code_id,
        latitude, longitude, accuracy_meters, distance_to_place_meters,
        verified_km, verified_at
    ) VALUES (
        v_attempt_id, v_raid.id, v_uid, v_place.id, v_qr.id,
        p_latitude, p_longitude, p_accuracy_meters, v_distance,
        v_raid.distance_km, v_now
    ) RETURNING id INTO v_arrival_id;

    INSERT INTO public.verified_kilometers(user_id, raid_id, arrival_id, kilometers)
    VALUES (v_uid, v_raid.id, v_arrival_id, v_raid.distance_km);

    INSERT INTO public.user_xp(user_id, total_xp, raids_completed, km_traveled, updated_at)
    VALUES (v_uid, 100, 1, v_raid.distance_km, v_now)
    ON CONFLICT (user_id) DO UPDATE SET
        total_xp = public.user_xp.total_xp + 100,
        raids_completed = public.user_xp.raids_completed + 1,
        km_traveled = public.user_xp.km_traveled + EXCLUDED.km_traveled,
        last_raid_date = CURRENT_DATE,
        updated_at = v_now;

    UPDATE public.raid_participants SET
        is_completed = TRUE, km_traveled = v_raid.distance_km
    WHERE raid_id = v_raid.id AND user_id = v_uid;
    UPDATE public.place_qr_codes SET last_used_at = v_now WHERE id = v_qr.id;
    UPDATE public.arrival_attempt_log SET success = TRUE WHERE id = v_log_id;

    RETURN QUERY SELECT v_arrival_id, v_raid.distance_km, v_place.name::TEXT, v_now;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.verify_raid_arrival(
    BIGINT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_raid_arrival(
    BIGINT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;

COMMIT;
