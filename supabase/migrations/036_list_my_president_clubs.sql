-- 036: RPC list_my_president_clubs
-- Clubs presididos por el usuario autenticado. La identidad sale SOLO de
-- auth.uid(); el cliente nunca envía user_id. Devuelve club_id + club_name
-- únicamente cuando club_members.role = 'presidente'.
CREATE OR REPLACE FUNCTION public.list_my_president_clubs()
RETURNS TABLE (club_id BIGINT, club_name TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF (SELECT auth.uid()) IS NULL THEN
        RETURN;
    END IF;
    RETURN QUERY
    SELECT member.club_id, club.name::TEXT
    FROM public.club_members AS member
    JOIN public.clubs AS club ON club.id = member.club_id
    WHERE member.user_id = (SELECT auth.uid())
      AND member.role = 'presidente'
    ORDER BY club.name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_president_clubs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_my_president_clubs() TO authenticated;
