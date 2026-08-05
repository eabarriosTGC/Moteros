-- MIGRATION 025: users profile fields for mandatory onboarding gate (F-M12)
-- + public trip-count RPC for F-M13 trust signals.
-- Additive, nullable, idempotent. bike_model/phone are already written by the
-- app today but were never declared in the migration trail.
BEGIN;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone      TEXT,
    ADD COLUMN IF NOT EXISTS bike_model TEXT,
    ADD COLUMN IF NOT EXISTS city       TEXT;

-- F-M13: public trip counts. saved_routes carries polyline_json / lat-lng
-- (GPS tracks) and its RLS (routes_select_own) filters to the viewer's own
-- rows — a count embed under users would silently show 0 trips for every
-- non-owner. A SECURITY DEFINER RPC exposes ONLY counts (never rows), so
-- viewers see real trip numbers without any GPS leak. Never replace this
-- with a blanket SELECT policy on saved_routes.
CREATE OR REPLACE FUNCTION public.get_trip_counts(user_ids uuid[])
RETURNS TABLE(user_id uuid, trips bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT s.user_id, COUNT(*)::bigint AS trips
    FROM saved_routes s
    WHERE s.user_id = ANY(user_ids)
    GROUP BY s.user_id;
$$;

REVOKE ALL ON FUNCTION public.get_trip_counts(uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.get_trip_counts(uuid[]) TO authenticated;

COMMIT;
