-- MIGRATION 035: raids permanentes/temporales y conquistas verificadas
-- Reemplaza el seguimiento continuo como requisito para acreditar kilometros.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA IF NOT EXISTS private;

-- Los raids existentes se conservan como eventos programados.
ALTER TABLE public.raids
    ADD COLUMN IF NOT EXISTS raid_type TEXT NOT NULL DEFAULT 'scheduled',
    ADD COLUMN IF NOT EXISTS club_id BIGINT REFERENCES public.clubs(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS origin_name TEXT,
    ADD COLUMN IF NOT EXISTS destination_name TEXT,
    ADD COLUMN IF NOT EXISTS distance_km DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS duration_minutes INTEGER,
    ADD COLUMN IF NOT EXISTS route_polyline JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS participant_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;

ALTER TABLE public.raids DROP CONSTRAINT IF EXISTS raids_raid_type_check;
ALTER TABLE public.raids ADD CONSTRAINT raids_raid_type_check
    CHECK (raid_type IN ('permanent', 'scheduled'));
ALTER TABLE public.raids DROP CONSTRAINT IF EXISTS raids_distance_km_check;
ALTER TABLE public.raids ADD CONSTRAINT raids_distance_km_check
    CHECK (distance_km IS NULL OR distance_km > 0);
ALTER TABLE public.raids DROP CONSTRAINT IF EXISTS raids_schedule_window_check;
ALTER TABLE public.raids ADD CONSTRAINT raids_schedule_window_check
    CHECK (
        raid_type = 'permanent'
        OR (starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at > starts_at)
    ) NOT VALID;

UPDATE public.raids
SET starts_at = COALESCE(starts_at, scheduled_at),
    ends_at = COALESCE(ends_at, scheduled_at + INTERVAL '12 hours'),
    published_at = COALESCE(published_at, created_at)
WHERE raid_type = 'scheduled';

ALTER TABLE public.raids VALIDATE CONSTRAINT raids_schedule_window_check;

CREATE INDEX IF NOT EXISTS idx_raids_type_status
    ON public.raids(raid_type, status);
CREATE INDEX IF NOT EXISTS idx_raids_event_window
    ON public.raids(starts_at, ends_at) WHERE raid_type = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_raids_club_id ON public.raids(club_id);

ALTER TABLE public.raid_participants
    ADD COLUMN IF NOT EXISTS show_on_roster BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE public.raids raid SET participant_count = (
    SELECT COUNT(*)::INTEGER FROM public.raid_participants participant
    WHERE participant.raid_id = raid.id
);

CREATE TABLE IF NOT EXISTS public.conquest_places (
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL REFERENCES public.clubs(id) ON DELETE RESTRICT,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    name VARCHAR(180) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    radius_meters INTEGER NOT NULL DEFAULT 150 CHECK (radius_meters BETWEEN 30 AND 1000),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.raids
    ADD COLUMN IF NOT EXISTS conquest_place_id BIGINT
        REFERENCES public.conquest_places(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_conquest_places_map
    ON public.conquest_places(latitude, longitude) WHERE is_active;

CREATE TABLE IF NOT EXISTS public.place_qr_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    place_id BIGINT NOT NULL REFERENCES public.conquest_places(id) ON DELETE CASCADE,
    label VARCHAR(120) NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_place_qr_codes_place
    ON public.place_qr_codes(place_id, is_active);

CREATE TABLE IF NOT EXISTS public.raid_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raid_id BIGINT NOT NULL REFERENCES public.raids(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'started'
        CHECK (status IN ('started', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_raid_attempt_active
    ON public.raid_attempts(raid_id, user_id) WHERE status = 'started';
CREATE INDEX IF NOT EXISTS idx_raid_attempts_user
    ON public.raid_attempts(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.raid_arrivals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL UNIQUE REFERENCES public.raid_attempts(id) ON DELETE CASCADE,
    raid_id BIGINT NOT NULL REFERENCES public.raids(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    place_id BIGINT NOT NULL REFERENCES public.conquest_places(id) ON DELETE RESTRICT,
    qr_code_id UUID NOT NULL REFERENCES public.place_qr_codes(id) ON DELETE RESTRICT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy_meters DOUBLE PRECISION NOT NULL,
    distance_to_place_meters DOUBLE PRECISION NOT NULL,
    verified_km DOUBLE PRECISION NOT NULL CHECK (verified_km > 0),
    photo_url TEXT,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(raid_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_raid_arrivals_user
    ON public.raid_arrivals(user_id, verified_at DESC);

CREATE TABLE IF NOT EXISTS public.verified_kilometers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    raid_id BIGINT NOT NULL REFERENCES public.raids(id) ON DELETE CASCADE,
    arrival_id UUID NOT NULL UNIQUE REFERENCES public.raid_arrivals(id) ON DELETE CASCADE,
    kilometers DOUBLE PRECISION NOT NULL CHECK (kilometers > 0),
    reason TEXT NOT NULL DEFAULT 'raid_arrival' CHECK (reason = 'raid_arrival'),
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, raid_id)
);
CREATE INDEX IF NOT EXISTS idx_verified_kilometers_user
    ON public.verified_kilometers(user_id, awarded_at DESC);

-- El cliente nunca recibe hashes de QR ni puede acreditar kilometros.
ALTER TABLE public.conquest_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.raid_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.raid_arrivals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verified_kilometers ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.conquest_places, public.place_qr_codes,
    public.raid_attempts, public.raid_arrivals, public.verified_kilometers
    FROM anon, authenticated;
GRANT SELECT ON public.conquest_places TO authenticated;
GRANT SELECT ON public.raid_attempts, public.raid_arrivals,
    public.verified_kilometers TO authenticated;

CREATE POLICY "conquest_places_read_active" ON public.conquest_places
    FOR SELECT TO authenticated USING (is_active);
CREATE POLICY "raid_attempts_read_own" ON public.raid_attempts
    FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "raid_arrivals_read_own" ON public.raid_arrivals
    FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "verified_km_read_own" ON public.verified_kilometers
    FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

CREATE OR REPLACE FUNCTION private.is_club_president(p_club_id BIGINT, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.club_members member
        WHERE member.club_id = p_club_id
          AND member.user_id = p_user_id
          AND member.role = 'presidente'
    )
$$;
REVOKE ALL ON FUNCTION private.is_club_president(BIGINT, UUID)
    FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.haversine_meters(
    p_lat1 DOUBLE PRECISION, p_lng1 DOUBLE PRECISION,
    p_lat2 DOUBLE PRECISION, p_lng2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
    SELECT 6371000 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(p_lat2 - p_lat1) / 2), 2) +
        COS(RADIANS(p_lat1)) * COS(RADIANS(p_lat2)) *
        POWER(SIN(RADIANS(p_lng2 - p_lng1) / 2), 2)
    ))
$$;
REVOKE ALL ON FUNCTION private.haversine_meters(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.sync_raid_participant_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.raids SET participant_count = participant_count + 1
        WHERE id = NEW.raid_id;
        RETURN NEW;
    END IF;
    UPDATE public.raids SET participant_count = GREATEST(participant_count - 1, 0)
    WHERE id = OLD.raid_id;
    RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION private.sync_raid_participant_count()
    FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_sync_raid_participant_count ON public.raid_participants;
CREATE TRIGGER trg_sync_raid_participant_count
    AFTER INSERT OR DELETE ON public.raid_participants
    FOR EACH ROW EXECUTE FUNCTION private.sync_raid_participant_count();

-- Endurece el helper usado por la policy heredada rp_insert_public: los raids
-- permanentes no tienen inscripcion y un evento lleno/vencido no acepta altas.
CREATE OR REPLACE FUNCTION public.is_raid_joinable(p_raid_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.raids raid
        WHERE raid.id = p_raid_id
          AND raid.raid_type = 'scheduled'
          AND raid.is_public
          AND raid.status = 'lobby'
          AND raid.participant_count < raid.max_participants
          AND (raid.ends_at IS NULL OR raid.ends_at >= CURRENT_TIMESTAMP)
    )
$$;
REVOKE EXECUTE ON FUNCTION public.is_raid_joinable(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_raid_joinable(BIGINT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_raid_roster(p_raid_id BIGINT)
RETURNS TABLE(
    user_id UUID,
    full_name TEXT,
    username TEXT,
    profile_image TEXT,
    joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF (SELECT auth.uid()) IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.raids raid
        WHERE raid.id = p_raid_id AND raid.is_public
    ) THEN
        RAISE EXCEPTION 'RAID_NOT_AVAILABLE' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT users.id, users.full_name::TEXT, users.username::TEXT,
           users.profile_image::TEXT, participant.joined_at
    FROM public.raid_participants participant
    JOIN public.users users ON users.id = participant.user_id
    WHERE participant.raid_id = p_raid_id
      AND participant.show_on_roster
    ORDER BY participant.joined_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_raid_roster(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_raid_roster(BIGINT) TO authenticated;

-- Creacion atomica: lugar + raid. Solo presidentes.
CREATE OR REPLACE FUNCTION public.create_conquest_raid(
    p_club_id BIGINT,
    p_title TEXT,
    p_description TEXT,
    p_raid_type TEXT,
    p_origin_name TEXT,
    p_origin_lat DOUBLE PRECISION,
    p_origin_lng DOUBLE PRECISION,
    p_destination_name TEXT,
    p_dest_lat DOUBLE PRECISION,
    p_dest_lng DOUBLE PRECISION,
    p_distance_km DOUBLE PRECISION,
    p_duration_minutes INTEGER,
    p_route_polyline JSONB,
    p_starts_at TIMESTAMPTZ DEFAULT NULL,
    p_ends_at TIMESTAMPTZ DEFAULT NULL,
    p_radius_meters INTEGER DEFAULT 150,
    p_max_participants INTEGER DEFAULT 100
)
RETURNS public.raids
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_place_id BIGINT;
    v_raid public.raids;
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '28000'; END IF;
    IF NOT private.is_club_president(p_club_id, v_uid) THEN
        RAISE EXCEPTION 'PRESIDENT_REQUIRED' USING ERRCODE = '42501';
    END IF;
    IF p_raid_type NOT IN ('permanent', 'scheduled') THEN
        RAISE EXCEPTION 'INVALID_RAID_TYPE' USING ERRCODE = '22023';
    END IF;
    IF p_distance_km IS NULL OR p_distance_km <= 0 OR p_distance_km > 5000 THEN
        RAISE EXCEPTION 'INVALID_DISTANCE' USING ERRCODE = '22023';
    END IF;
    IF p_raid_type = 'scheduled' AND
       (p_starts_at IS NULL OR p_ends_at IS NULL OR p_ends_at <= p_starts_at) THEN
        RAISE EXCEPTION 'INVALID_EVENT_WINDOW' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.conquest_places(
        club_id, created_by, name, description, latitude, longitude, radius_meters
    ) VALUES (
        p_club_id, v_uid, p_destination_name, p_description,
        p_dest_lat, p_dest_lng, p_radius_meters
    ) RETURNING id INTO v_place_id;

    INSERT INTO public.raids(
        host_id, club_id, conquest_place_id, raid_type,
        origin_name, origin_lat, origin_lng,
        destination_name, dest_lat, dest_lng,
        distance_km, duration_minutes, route_polyline, route_data,
        mode, scheduled_at, starts_at, ends_at,
        is_public, status, max_participants, description, published_at
    ) VALUES (
        v_uid, p_club_id, v_place_id, p_raid_type,
        p_origin_name, p_origin_lat, p_origin_lng,
        p_destination_name, p_dest_lat, p_dest_lng,
        p_distance_km, p_duration_minutes, COALESCE(p_route_polyline, '[]'::jsonb),
        jsonb_build_object('distance_km', p_distance_km, 'duration_minutes', p_duration_minutes),
        'aventura', COALESCE(p_starts_at, CURRENT_TIMESTAMP), p_starts_at, p_ends_at,
        TRUE, 'lobby', LEAST(GREATEST(p_max_participants, 1), 1000),
        COALESCE(NULLIF(BTRIM(p_title), ''), p_description), CURRENT_TIMESTAMP
    ) RETURNING * INTO v_raid;

    IF p_raid_type = 'scheduled' THEN
        INSERT INTO public.raid_participants(raid_id, user_id, is_ready)
        VALUES (v_raid.id, v_uid, TRUE)
        ON CONFLICT (raid_id, user_id) DO NOTHING;
    END IF;
    RETURN v_raid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_conquest_raid(
    BIGINT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION,
    TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER,
    JSONB, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_conquest_raid(
    BIGINT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION,
    TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER,
    JSONB, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER
) TO authenticated;

CREATE OR REPLACE FUNCTION public.generate_place_qr(
    p_raid_id BIGINT,
    p_label TEXT,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(qr_id UUID, qr_token TEXT, label TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_place_id BIGINT;
    v_club_id BIGINT;
    v_token TEXT;
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
    INSERT INTO public.place_qr_codes(
        place_id, label, token_hash, expires_at, created_by
    ) VALUES (
        v_place_id, BTRIM(p_label),
        encode(extensions.digest(v_token, 'sha256'), 'hex'), p_expires_at, v_uid
    ) RETURNING id INTO v_id;
    RETURN QUERY SELECT v_id, v_token, BTRIM(p_label), p_expires_at;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.generate_place_qr(BIGINT, TEXT, TIMESTAMPTZ)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_place_qr(BIGINT, TEXT, TIMESTAMPTZ)
    TO authenticated;

CREATE OR REPLACE FUNCTION public.list_place_qr_codes(p_raid_id BIGINT)
RETURNS TABLE(id UUID, label TEXT, is_active BOOLEAN, expires_at TIMESTAMPTZ, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_place_id BIGINT;
    v_club_id BIGINT;
BEGIN
    SELECT raid.conquest_place_id, raid.club_id INTO v_place_id, v_club_id
    FROM public.raids raid WHERE raid.id = p_raid_id;
    IF v_uid IS NULL OR NOT private.is_club_president(v_club_id, v_uid) THEN
        RAISE EXCEPTION 'PRESIDENT_REQUIRED' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT code.id, code.label::TEXT, code.is_active, code.expires_at, code.created_at
    FROM public.place_qr_codes code
    WHERE code.place_id = v_place_id
    ORDER BY code.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_place_qr_codes(BIGINT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_place_qr_codes(BIGINT) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_place_qr_active(p_qr_id UUID, p_is_active BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_club_id BIGINT;
BEGIN
    SELECT place.club_id INTO v_club_id
    FROM public.place_qr_codes code
    JOIN public.conquest_places place ON place.id = code.place_id
    WHERE code.id = p_qr_id;
    IF v_uid IS NULL OR NOT private.is_club_president(v_club_id, v_uid) THEN
        RAISE EXCEPTION 'PRESIDENT_REQUIRED' USING ERRCODE = '42501';
    END IF;
    UPDATE public.place_qr_codes SET is_active = p_is_active WHERE id = p_qr_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.set_place_qr_active(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_place_qr_active(UUID, BOOLEAN) TO authenticated;

-- QR + GPS + ventana temporal + participacion se validan en una transaccion.
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
    SELECT * INTO v_qr FROM public.place_qr_codes code
    WHERE code.place_id = v_place.id
      AND code.token_hash = encode(extensions.digest(p_qr_token, 'sha256'), 'hex')
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

    RETURN QUERY SELECT v_arrival_id, v_raid.distance_km, v_place.name::TEXT, v_now;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.verify_raid_arrival(
    BIGINT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_raid_arrival(
    BIGINT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;

CREATE OR REPLACE FUNCTION public.attach_raid_conquest_photo(
    p_arrival_id UUID,
    p_photo_url TEXT,
    p_caption TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := (SELECT auth.uid());
    v_raid_id BIGINT;
    v_photo_id UUID;
BEGIN
    SELECT arrival.raid_id INTO v_raid_id
    FROM public.raid_arrivals arrival
    WHERE arrival.id = p_arrival_id AND arrival.user_id = v_uid
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'ARRIVAL_NOT_FOUND' USING ERRCODE = 'P0002'; END IF;
    IF NULLIF(BTRIM(p_photo_url), '') IS NULL THEN
        RAISE EXCEPTION 'PHOTO_URL_REQUIRED' USING ERRCODE = '22023';
    END IF;
    IF p_photo_url NOT LIKE '%/storage/v1/object/public/conquest-photos/' || v_uid::TEXT || '/%' THEN
        RAISE EXCEPTION 'INVALID_PHOTO_URL' USING ERRCODE = '22023';
    END IF;

    UPDATE public.raid_arrivals SET photo_url = p_photo_url WHERE id = p_arrival_id;
    INSERT INTO public.conquest_photos(user_id, source, source_id, photo_url, caption)
    VALUES (v_uid, 'raid', v_raid_id::TEXT, p_photo_url, p_caption)
    RETURNING id INTO v_photo_id;
    RETURN v_photo_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.attach_raid_conquest_photo(UUID, TEXT, TEXT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.attach_raid_conquest_photo(UUID, TEXT, TEXT)
    TO authenticated;

-- La app crea raids solo mediante RPC; evita falsificar club/distancia.
REVOKE INSERT, UPDATE, DELETE ON public.raids FROM anon, authenticated;
GRANT SELECT ON public.raids TO authenticated;

COMMIT;
