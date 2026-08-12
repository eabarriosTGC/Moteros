-- BLOQUE 2: evaluacion mutua y reputacion separada de Motoposadas.
BEGIN;

-- Las reseñas individuales contienen texto y relaciones entre personas.
-- Cada autor/destinatario puede leer las suyas; el resto consume agregados.
DROP POLICY IF EXISTS "mrev_select" ON public.motoposada_reviews;
CREATE POLICY "mrev_select_participants"
ON public.motoposada_reviews FOR SELECT TO authenticated
USING (
  (SELECT auth.uid()) = from_user_id
  OR (SELECT auth.uid()) = to_user_id
);

-- El servidor deriva destinatario y tipo desde la estancia. El cliente solo
-- aporta request, puntuacion y comentario.
CREATE OR REPLACE FUNCTION public.submit_motoposada_review_v2(
  p_request_id BIGINT,
  p_rating INT,
  p_comment TEXT DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_req RECORD;
  v_to_user_id UUID;
  v_type TEXT;
  v_delta INT;
  v_comment TEXT := NULLIF(BTRIM(p_comment), '');
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_rating NOT BETWEEN 1 AND 5 THEN RAISE EXCEPTION 'invalid_rating'; END IF;
  IF LENGTH(COALESCE(v_comment, '')) > 500 THEN RAISE EXCEPTION 'comment_too_long'; END IF;

  SELECT r.id, r.status, r.guest_id, m.id AS motoposada_id, m.user_id AS host_id
    INTO v_req
    FROM public.motoposada_requests r
    JOIN public.motoposadas m ON m.id = r.motoposada_id
   WHERE r.id = p_request_id
   FOR UPDATE OF r;

  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found'; END IF;
  IF v_req.status <> 'completed' THEN RAISE EXCEPTION 'stay_not_completed'; END IF;

  IF v_uid = v_req.guest_id THEN
    v_to_user_id := v_req.host_id;
    v_type := 'guest_review';
  ELSIF v_uid = v_req.host_id THEN
    v_to_user_id := v_req.guest_id;
    v_type := 'host_review';
  ELSE
    RAISE EXCEPTION 'not_participant';
  END IF;

  IF v_to_user_id = v_uid THEN RAISE EXCEPTION 'self_review_not_allowed'; END IF;

  INSERT INTO public.motoposada_reviews (
    motoposada_id, request_id, from_user_id, to_user_id,
    type, rating, comment, behavior_flags
  ) VALUES (
    v_req.motoposada_id, p_request_id, v_uid, v_to_user_id,
    v_type, p_rating, v_comment, 0
  );

  v_delta := CASE WHEN p_rating >= 4 THEN 2 WHEN p_rating <= 2 THEN -2 ELSE 0 END;
  IF v_delta <> 0 THEN
    UPDATE public.user_xp
       SET trust_score = GREATEST(0, LEAST(100, COALESCE(trust_score, 50) + v_delta))
     WHERE user_id = v_to_user_id;
  END IF;
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'review_already_exists';
END;
$$;

REVOKE ALL ON FUNCTION public.submit_motoposada_review_v2(BIGINT, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_motoposada_review_v2(BIGINT, INT, TEXT) TO authenticated;

-- Agregados públicos sin comentarios ni identidad de autores.
CREATE OR REPLACE FUNCTION public.get_motoposada_reputation(p_user_id UUID)
RETURNS TABLE (
  host_average NUMERIC,
  host_reviews BIGINT,
  guest_average NUMERIC,
  guest_reviews BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    ROUND(AVG(r.rating) FILTER (WHERE r.type = 'guest_review'), 1),
    COUNT(*) FILTER (WHERE r.type = 'guest_review'),
    ROUND(AVG(r.rating) FILTER (WHERE r.type = 'host_review'), 1),
    COUNT(*) FILTER (WHERE r.type = 'host_review')
  FROM public.motoposada_reviews r
  WHERE r.to_user_id = p_user_id
    AND auth.uid() IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.get_motoposada_reputation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_motoposada_reputation(UUID) TO authenticated;

COMMIT;
