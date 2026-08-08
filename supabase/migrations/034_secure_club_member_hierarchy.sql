-- MIGRATION 034: secure club member hierarchy
--
-- The legacy policies only checked whether the caller was presidente/oficial.
-- They did not constrain the target's current role or the resulting role, so a
-- modified client could bypass the hierarchy enforced by the Flutter UI.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.current_club_member_role(p_club_id BIGINT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT member.role
    FROM public.club_members AS member
    WHERE member.club_id = p_club_id
      AND member.user_id = (SELECT auth.uid())
    LIMIT 1
$$;

REVOKE ALL ON FUNCTION private.current_club_member_role(BIGINT)
    FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_club_member_role(BIGINT)
    TO authenticated;

CREATE OR REPLACE FUNCTION private.sync_club_member_role_metadata()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    SELECT rank.id
    INTO NEW.rank_id
    FROM public.club_ranks AS rank
    WHERE rank.club_id = NEW.club_id
      AND rank.name = NEW.role
    ORDER BY rank.level DESC, rank.id
    LIMIT 1;

    IF TG_OP = 'UPDATE' THEN
        NEW.promoted_at := CURRENT_TIMESTAMP;
        NEW.promoted_by := (SELECT auth.uid());
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_club_member_role_metadata()
    FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_club_member_role_metadata
    ON public.club_members;
CREATE TRIGGER trg_sync_club_member_role_metadata
    BEFORE INSERT OR UPDATE OF role ON public.club_members
    FOR EACH ROW
    EXECUTE FUNCTION private.sync_club_member_role_metadata();

-- Prevent clients from moving a membership to another user or club or from
-- forging rank/promotion metadata. The trigger derives that metadata from role.
REVOKE UPDATE ON public.club_members FROM anon, authenticated;
GRANT UPDATE (role)
    ON public.club_members TO authenticated;

DROP POLICY IF EXISTS "members_insert" ON public.club_members;
CREATE POLICY "members_insert"
ON public.club_members
FOR INSERT
TO authenticated
WITH CHECK (
    -- The club creator may create the single presidente membership.
    (
        user_id = (SELECT auth.uid())
        AND role = 'presidente'
        AND EXISTS (
            SELECT 1
            FROM public.clubs
            WHERE clubs.id = club_members.club_id
              AND clubs.founder_id = (SELECT auth.uid())
        )
    )
    OR
    -- Users may join public clubs that do not require approval.
    (
        user_id = (SELECT auth.uid())
        AND role = 'aspirante'
        AND EXISTS (
            SELECT 1
            FROM public.clubs
            WHERE clubs.id = club_members.club_id
              AND clubs.is_public = TRUE
              AND COALESCE(clubs.requires_approval, FALSE) = FALSE
        )
    )
    OR
    -- Presidente/oficial invitations always start at aspirante.
    (
        user_id <> (SELECT auth.uid())
        AND role = 'aspirante'
        AND private.current_club_member_role(club_id)
            IN ('presidente', 'oficial')
    )
);

DROP POLICY IF EXISTS "members_update_role" ON public.club_members;
CREATE POLICY "members_update_role"
ON public.club_members
FOR UPDATE
TO authenticated
USING (
    user_id <> (SELECT auth.uid())
    AND (
        (
            private.current_club_member_role(club_id) = 'presidente'
            AND role <> 'presidente'
        )
        OR
        (
            private.current_club_member_role(club_id) = 'oficial'
            AND role IN ('honorable', 'aspirante')
        )
    )
)
WITH CHECK (
    user_id <> (SELECT auth.uid())
    AND (
        (
            private.current_club_member_role(club_id) = 'presidente'
            AND role IN ('oficial', 'honorable', 'aspirante')
        )
        OR
        (
            private.current_club_member_role(club_id) = 'oficial'
            AND role IN ('honorable', 'aspirante')
        )
    )
);

DROP POLICY IF EXISTS "members_delete_self" ON public.club_members;
DROP POLICY IF EXISTS "members_delete_management" ON public.club_members;
CREATE POLICY "members_delete"
ON public.club_members
FOR DELETE
TO authenticated
USING (
    -- Any non-president member may leave voluntarily.
    (user_id = (SELECT auth.uid()) AND role <> 'presidente')
    OR
    -- Presidente may remove any lower role.
    (
        user_id <> (SELECT auth.uid())
        AND private.current_club_member_role(club_id) = 'presidente'
        AND role <> 'presidente'
    )
    OR
    -- Oficial may only remove aspirantes.
    (
        user_id <> (SELECT auth.uid())
        AND private.current_club_member_role(club_id) = 'oficial'
        AND role = 'aspirante'
    )
);

COMMIT;
