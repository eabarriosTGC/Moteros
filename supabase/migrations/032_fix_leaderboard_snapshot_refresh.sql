-- MIGRATION 032: reparar refresh_leaderboard_snapshot
-- Corrige visits.created_at (columna inexistente) por visits.verified_at,
-- hace idempotentes los tres periodos del snapshot nacional del día y cierra
-- la función SECURITY DEFINER a clientes públicos.
BEGIN;

CREATE OR REPLACE FUNCTION public.refresh_leaderboard_snapshot()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_period TEXT;
    v_cutoff TIMESTAMPTZ;
BEGIN
    DELETE FROM public.leaderboard_entries
    WHERE scope = 'nacional'
      AND snapshot_date = CURRENT_DATE
      AND period IN ('monthly', 'yearly', 'historical');

    FOR v_period, v_cutoff IN
        VALUES
            ('monthly'::TEXT, DATE_TRUNC('month', NOW())),
            ('yearly'::TEXT, DATE_TRUNC('year', NOW())),
            ('historical'::TEXT, NULL::TIMESTAMPTZ)
    LOOP
        INSERT INTO public.leaderboard_entries (
            period,
            scope,
            user_id,
            rank,
            total_puntos,
            total_km,
            total_destinos,
            total_insignias,
            club_id,
            snapshot_date
        )
        SELECT
            v_period,
            'nacional',
            ux.user_id,
            ROW_NUMBER() OVER (
                ORDER BY COALESCE(ux.total_xp, 0) DESC, ux.user_id
            )::INT,
            COALESCE(ux.total_xp, 0),
            COALESCE(um.total_km, 0),
            (
                SELECT COUNT(DISTINCT v.place_id)::INT
                FROM public.visits v
                WHERE v.user_id = ux.user_id
                  AND (v_cutoff IS NULL OR v.verified_at >= v_cutoff)
            ),
            (
                SELECT COUNT(*)::INT
                FROM public.user_achievements ua
                WHERE ua.user_id = ux.user_id
            ),
            cm.club_id,
            CURRENT_DATE
        FROM public.user_xp ux
        JOIN public.users u ON u.id = ux.user_id
        LEFT JOIN LATERAL (
            SELECT member.club_id
            FROM public.club_members member
            WHERE member.user_id = ux.user_id
              AND member.role = 'presidente'
            ORDER BY member.joined_at, member.club_id
            LIMIT 1
        ) cm ON TRUE
        LEFT JOIN public.user_mileage um ON um.user_id = ux.user_id;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_leaderboard_snapshot() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refresh_leaderboard_snapshot() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_leaderboard_snapshot() TO service_role;

COMMIT;
