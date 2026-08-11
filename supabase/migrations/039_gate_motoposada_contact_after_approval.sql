-- MIGRATION 039: contacto privado únicamente tras aprobación
-- ============================================================
BEGIN;

-- Compatibilidad con la tarjeta pública existente. El teléfono del anfitrión
-- solo se entrega al dueño o a un huésped con solicitud aprobada/completada.
CREATE OR REPLACE FUNCTION public.get_motoposada_whatsapp(p_id BIGINT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT d.whatsapp_phone
      FROM public.motoposadas m
      JOIN public.casa_motero_details d ON d.motoposada_id = m.id
     WHERE m.id = p_id
       AND m.poi_type = 'casa_motero'
       AND m.is_active = TRUE
       AND (select auth.uid()) IS NOT NULL
       AND (
           m.user_id = (select auth.uid())
           OR EXISTS (
               SELECT 1
                 FROM public.motoposada_requests r
                WHERE r.motoposada_id = m.id
                  AND r.guest_id = (select auth.uid())
                  AND r.status IN ('approved', 'completed')
           )
       )
$$;

REVOKE ALL ON FUNCTION public.get_motoposada_whatsapp(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_motoposada_whatsapp(BIGINT) TO authenticated;

-- Contacto bilateral asociado a una solicitud concreta. El huésped recibe
-- el WhatsApp privado del anfitrión; el anfitrión recibe el teléfono de perfil
-- del huésped. No revela datos para pending/rejected/cancelled ni a terceros.
CREATE OR REPLACE FUNCTION public.get_motoposada_request_contact(
    p_request_id BIGINT
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_req RECORD;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    SELECT r.guest_id, r.status, m.user_id AS host_id,
           d.whatsapp_phone AS host_phone, u.phone AS guest_phone
      INTO v_req
      FROM public.motoposada_requests r
      JOIN public.motoposadas m ON m.id = r.motoposada_id
      JOIN public.casa_motero_details d ON d.motoposada_id = m.id
      JOIN public.users u ON u.id = r.guest_id
     WHERE r.id = p_request_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    IF v_req.status NOT IN ('approved', 'completed') THEN
        RAISE EXCEPTION 'contact_not_available';
    END IF;
    IF v_uid = v_req.guest_id THEN
        RETURN v_req.host_phone;
    END IF;
    IF v_uid = v_req.host_id THEN
        RETURN NULLIF(regexp_replace(v_req.guest_phone, '[^0-9+]', '', 'g'), '');
    END IF;

    RAISE EXCEPTION 'not_participant';
END;
$$;

REVOKE ALL ON FUNCTION public.get_motoposada_request_contact(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_motoposada_request_contact(BIGINT) TO authenticated;

COMMIT;
