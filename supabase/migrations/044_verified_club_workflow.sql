-- BLOQUE 6: clanes verificados, presidentes y solicitudes de ingreso.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.clubs DROP CONSTRAINT IF EXISTS clubs_approval_status_check;
ALTER TABLE public.clubs ADD CONSTRAINT clubs_approval_status_check
  CHECK (approval_status IN ('pending','active','rejected','suspended'));

UPDATE public.clubs
SET approval_status = CASE WHEN COALESCE(is_approved, FALSE) THEN 'active' ELSE 'pending' END
WHERE approval_status = 'pending';

CREATE TABLE IF NOT EXISTS public.club_join_requests (
  id BIGSERIAL PRIMARY KEY,
  club_id BIGINT NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled')),
  reviewed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS club_join_requests_one_pending
  ON public.club_join_requests(club_id,user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS club_join_requests_club_status
  ON public.club_join_requests(club_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS club_join_requests_user
  ON public.club_join_requests(user_id,created_at DESC);

ALTER TABLE public.club_join_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.club_join_requests FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.club_join_requests FROM authenticated;
GRANT SELECT ON public.club_join_requests TO authenticated;

CREATE OR REPLACE FUNCTION private.manages_club(p_club_id BIGINT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.club_members m
    WHERE m.club_id=p_club_id AND m.user_id=(SELECT auth.uid())
      AND m.role IN ('presidente','oficial')
  )
$$;
REVOKE ALL ON FUNCTION private.manages_club(BIGINT) FROM PUBLIC,anon,authenticated;

-- Pending/rejected clubs are visible only to their founder, managers and admin.
DROP POLICY IF EXISTS "clubs_select_public" ON public.clubs;
DROP POLICY IF EXISTS clubs_select_verified ON public.clubs;
CREATE POLICY clubs_select_verified ON public.clubs FOR SELECT TO authenticated USING (
  approval_status='active' OR founder_id=(SELECT auth.uid())
  OR private.current_club_member_role(id) IS NOT NULL
  OR (SELECT public.is_admin())
);
REVOKE INSERT ON public.clubs FROM authenticated;

CREATE OR REPLACE FUNCTION private.protect_club_approval_fields()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF (NEW.approval_status,NEW.is_approved,NEW.reviewed_by,NEW.reviewed_at,NEW.rejection_reason)
     IS DISTINCT FROM
     (OLD.approval_status,OLD.is_approved,OLD.reviewed_by,OLD.reviewed_at,OLD.rejection_reason)
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_required';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.protect_club_approval_fields() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_protect_club_approval_fields ON public.clubs;
CREATE TRIGGER trg_protect_club_approval_fields BEFORE UPDATE ON public.clubs
FOR EACH ROW EXECUTE FUNCTION private.protect_club_approval_fields();

DROP POLICY IF EXISTS club_join_requests_select ON public.club_join_requests;
CREATE POLICY club_join_requests_select ON public.club_join_requests
FOR SELECT TO authenticated USING (
  user_id=(SELECT auth.uid())
  OR private.manages_club(club_id)
  OR (SELECT public.is_admin())
);

CREATE OR REPLACE FUNCTION public.request_club_creation(
  p_name TEXT, p_tag TEXT, p_description TEXT, p_city TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID := auth.uid(); v_id BIGINT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;
  IF length(trim(p_name)) < 3 OR length(trim(p_tag)) < 2 THEN
    RAISE EXCEPTION 'invalid_club_data';
  END IF;
  IF EXISTS (SELECT 1 FROM public.club_members WHERE user_id=v_uid) THEN
    RAISE EXCEPTION 'already_in_club';
  END IF;
  IF EXISTS (SELECT 1 FROM public.clubs WHERE founder_id=v_uid AND approval_status='pending') THEN
    RAISE EXCEPTION 'creation_request_exists';
  END IF;
  INSERT INTO public.clubs(name,tag,description,founder_id,is_public,requires_approval,is_approved,approval_status)
  VALUES(trim(p_name),upper(trim(p_tag)),concat_ws(E'\n',nullif(trim(p_description),''),
    CASE WHEN nullif(trim(p_city),'') IS NULL THEN NULL ELSE 'Ciudad: '||trim(p_city) END),
    v_uid,TRUE,TRUE,FALSE,'pending') RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.review_club_creation(
  p_club_id BIGINT, p_approve BOOLEAN, p_reason TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID:=auth.uid(); v_founder UUID;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'admin_required'; END IF;
  SELECT founder_id INTO v_founder FROM public.clubs WHERE id=p_club_id AND approval_status='pending' FOR UPDATE;
  IF v_founder IS NULL THEN RAISE EXCEPTION 'club_request_not_pending'; END IF;
  UPDATE public.clubs SET approval_status=CASE WHEN p_approve THEN 'active' ELSE 'rejected' END,
    is_approved=p_approve,reviewed_by=v_uid,reviewed_at=CURRENT_TIMESTAMP,
    rejection_reason=CASE WHEN p_approve THEN NULL ELSE nullif(trim(p_reason),'') END
  WHERE id=p_club_id;
  IF p_approve THEN
    INSERT INTO public.club_members(club_id,user_id,role)
    VALUES(p_club_id,v_founder,'presidente') ON CONFLICT(club_id,user_id) DO NOTHING;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.request_to_join_club(p_club_id BIGINT,p_message TEXT DEFAULT '')
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID:=auth.uid(); v_id BIGINT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;
  IF EXISTS(SELECT 1 FROM public.club_members WHERE user_id=v_uid) THEN RAISE EXCEPTION 'already_in_club'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.clubs WHERE id=p_club_id AND approval_status='active') THEN RAISE EXCEPTION 'club_not_active'; END IF;
  INSERT INTO public.club_join_requests(club_id,user_id,message)
  VALUES(p_club_id,v_uid,left(trim(p_message),500)) RETURNING id INTO v_id;
  RETURN v_id;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'join_request_exists';
END $$;

CREATE OR REPLACE FUNCTION public.cancel_club_join_request(p_request_id BIGINT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE public.club_join_requests SET status='cancelled',reviewed_at=CURRENT_TIMESTAMP
  WHERE id=p_request_id AND user_id=auth.uid() AND status='pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'join_request_not_pending'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.review_club_join_request(
  p_request_id BIGINT,p_approve BOOLEAN
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid UUID:=auth.uid(); v_req public.club_join_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_req FROM public.club_join_requests WHERE id=p_request_id AND status='pending' FOR UPDATE;
  IF v_req.id IS NULL THEN RAISE EXCEPTION 'join_request_not_pending'; END IF;
  IF NOT private.manages_club(v_req.club_id) THEN RAISE EXCEPTION 'club_manager_required'; END IF;
  IF p_approve AND EXISTS(SELECT 1 FROM public.club_members WHERE user_id=v_req.user_id) THEN
    RAISE EXCEPTION 'applicant_already_in_club';
  END IF;
  UPDATE public.club_join_requests SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    reviewed_by=v_uid,reviewed_at=CURRENT_TIMESTAMP WHERE id=p_request_id;
  IF p_approve THEN
    INSERT INTO public.club_members(club_id,user_id,role) VALUES(v_req.club_id,v_req.user_id,'aspirante');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.leave_club(p_club_id BIGINT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.club_members WHERE club_id=p_club_id AND user_id=auth.uid() AND role<>'presidente';
  IF NOT FOUND THEN RAISE EXCEPTION 'cannot_leave_club'; END IF;
END $$;

-- “Solo mi clan” means the guest and host share the same approved membership,
-- not merely that both belong to any club.
DROP POLICY IF EXISTS "mp_select_public" ON public.motoposadas;
CREATE POLICY "mp_select_public" ON public.motoposadas FOR SELECT TO authenticated USING (
  visibility='public' OR user_id=(SELECT auth.uid())
  OR (visibility='clan_specific' AND target_clan_id IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.club_members guest
    WHERE guest.user_id=(SELECT auth.uid()) AND guest.club_id=target_clan_id
  ))
  OR (visibility='clan_only' AND EXISTS(
    SELECT 1 FROM public.club_members guest
    JOIN public.club_members host ON host.club_id=guest.club_id
    WHERE guest.user_id=(SELECT auth.uid()) AND host.user_id=motoposadas.user_id
  ))
);

CREATE OR REPLACE FUNCTION private.enforce_motoposada_clan_request()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_mp public.motoposadas%ROWTYPE;
BEGIN
  SELECT * INTO v_mp FROM public.motoposadas WHERE id=NEW.motoposada_id;
  IF v_mp.visibility='clan_specific' AND NOT EXISTS(
    SELECT 1 FROM public.club_members m WHERE m.user_id=NEW.guest_id AND m.club_id=v_mp.target_clan_id
  ) THEN RAISE EXCEPTION 'motoposada_not_visible'; END IF;
  IF v_mp.visibility='clan_only' AND NOT EXISTS(
    SELECT 1 FROM public.club_members guest JOIN public.club_members host ON host.club_id=guest.club_id
    WHERE guest.user_id=NEW.guest_id AND host.user_id=v_mp.user_id
  ) THEN RAISE EXCEPTION 'motoposada_not_visible'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.enforce_motoposada_clan_request() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_enforce_motoposada_clan_request ON public.motoposada_requests;
CREATE TRIGGER trg_enforce_motoposada_clan_request BEFORE INSERT ON public.motoposada_requests
FOR EACH ROW EXECUTE FUNCTION private.enforce_motoposada_clan_request();

REVOKE ALL ON FUNCTION public.request_club_creation(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.review_club_creation(BIGINT,BOOLEAN,TEXT) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.request_to_join_club(BIGINT,TEXT) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.cancel_club_join_request(BIGINT) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.review_club_join_request(BIGINT,BOOLEAN) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.leave_club(BIGINT) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_club_creation(TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_club_creation(BIGINT,BOOLEAN,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_to_join_club(BIGINT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_club_join_request(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_club_join_request(BIGINT,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_club(BIGINT) TO authenticated;

COMMIT;
