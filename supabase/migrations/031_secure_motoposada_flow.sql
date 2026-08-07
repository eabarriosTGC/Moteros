-- MIGRATION 031: flujo seguro de solicitudes motoposada (mutaciones SOLO vía RPC)
-- =============================================================================
-- Contexto (2026-08-07, rama agent/secure-motoposada-flow):
--   El flujo anterior mezclaba operaciones directas desde Flutter con reglas
--   que deben vivir en PostgreSQL: `mr_insert_guest` (009) permitía al guest
--   insertar solicitudes sin validar fechas/capacidad/propiedad/solapamiento,
--   `mr_update_host` permitía al host mutar status sin validar transiciones ni
--   fechas cruzadas, y `mrev_insert_participant` permitía reseñas sin exigir
--   estancia completada. El cliente podía "convencerse a sí mismo" de que una
--   reserva terminó o de que merece más reputación.
--
--   Fix: se cierran las mutaciones directas (RLS sin policies de INSERT/
--   UPDATE/DELETE sobre solicitudes y reseñas — solo quedan los SELECT) y se
--   exponen CINCO RPC autenticadas (SECURITY DEFINER, firma estrecha) que
--   validan fechas, capacidad, propiedad, visibilidad, solapamientos,
--   transiciones y reputación de forma ATÓMICA:
--     1. request_motoposada            — crear solicitud (guest)
--     2. respond_motoposada_request    — aprobar/rechazar (host)
--     3. complete_motoposada_request   — finalizar estancia (host)
--     4. cancel_motoposada_request     — cancelar antes del check-in (guest)
--     5. submit_motoposada_review      — reseña post-completado + trust_score
--   trust_score se actualiza DENTRO de submit_motoposada_review (clamp 0..100,
--   delta por rating), sin depender del cálculo del cliente (030 queda como
--   RPC independiente, sin romper compatibilidad).
--
--   Serialización de concurrencia: cada RPC toma lock FOR UPDATE sobre la/s
--   fila/s que gobiernan la decisión ANTES de validar (request row, fila de la
--   motoposada y fila del guest en users) — así el chequeo de solapamiento se
--   evalúa con snapshot fresco tras el lock wait y dos aprobaciones
--   concurrentes no pueden cruzar fechas (sin deadlock: orden de locks
--   request → motoposada → users).
-- =============================================================================
BEGIN;

-- ============================================================
-- 1. Cierre de mutaciones directas (RLS)
-- ============================================================
-- Lecturas se mantienen: mr_select_guest / mr_select_host (009) y
-- mrev_select (009). INSERT/UPDATE/DELETE directos quedan SIN policy → el
-- API PostgREST los rechaza con 403; el único path de mutación son los RPC
-- (SECURITY DEFINER del owner, bypass RLS por diseño, patrón 026).
DROP POLICY IF EXISTS "mr_insert_guest" ON motoposada_requests;
DROP POLICY IF EXISTS "mr_update_host" ON motoposada_requests;
DROP POLICY IF EXISTS "mrev_insert_participant" ON motoposada_reviews;

-- ============================================================
-- 2. Índices para los chequeos de solapamiento
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_mr_active_overlap_mp
    ON motoposada_requests(motoposada_id, status, check_in, check_out)
    WHERE status IN ('pending', 'approved');

CREATE INDEX IF NOT EXISTS idx_mr_active_overlap_guest
    ON motoposada_requests(guest_id, status, check_in, check_out)
    WHERE status IN ('pending', 'approved');

-- Backstop anti-duplicados concurrentes: mismo guest + misma motoposada +
-- mismo rango exacto mientras la solicitud siga activa (pending/approved).
-- Tras reject/cancel el guest puede volver a pedir las mismas fechas.
CREATE UNIQUE INDEX IF NOT EXISTS uq_motoposada_requests_active_range
    ON motoposada_requests(motoposada_id, guest_id, check_in, check_out)
    WHERE status IN ('pending', 'approved');

-- ============================================================
-- 3. Helper de solapamiento de rangos [a_in, a_out) ∩ [b_in, b_out)
-- ============================================================
CREATE OR REPLACE FUNCTION public.dates_overlap(
    a_in DATE, a_out DATE, b_in DATE, b_out DATE
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE STRICT
SET search_path = public
AS $$
    SELECT (a_in < b_out AND b_in < a_out)
$$;

-- ============================================================
-- 4. RPC request_motoposada — crear solicitud (guest)
-- ============================================================
-- Valida: autenticado, motoposada existente y activa, NO propia, visibilidad
-- (mismo predicado que mp_select_public: no se reserva lo que no se ve),
-- fechas válidas (check_out > check_in, check_in no en el pasado), capacidad
-- (1..max_guests) y solapamiento del mismo guest en la misma motoposada.
-- Lock FOR UPDATE sobre la fila del guest en users: serializa solicitudes
-- concurrentes del mismo usuario (el chequeo de solapamiento se evalúa con
-- snapshot fresco tras el lock wait).
CREATE OR REPLACE FUNCTION public.request_motoposada(
    p_motoposada_id BIGINT,
    p_check_in      DATE,
    p_check_out     DATE,
    p_guest_count   INT DEFAULT 1,
    p_message       TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_mp  RECORD;
    v_id  BIGINT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_check_in IS NULL OR p_check_out IS NULL OR p_check_out <= p_check_in THEN
        RAISE EXCEPTION 'invalid_dates';
    END IF;
    IF p_check_in < current_date THEN
        RAISE EXCEPTION 'check_in_in_past';
    END IF;

    -- Serializa solicitudes concurrentes del mismo guest.
    PERFORM 1 FROM public.users WHERE id = v_uid FOR UPDATE;

    SELECT user_id, max_guests, visibility, target_clan_id, is_active
      INTO v_mp
      FROM motoposadas
     WHERE id = p_motoposada_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'motoposada_not_found';
    END IF;
    IF NOT v_mp.is_active THEN
        RAISE EXCEPTION 'motoposada_inactive';
    END IF;
    IF v_mp.user_id = v_uid THEN
        RAISE EXCEPTION 'cannot_book_own_motoposada';
    END IF;
    IF v_mp.visibility = 'clan_specific'
       AND (v_mp.target_clan_id IS NULL OR NOT EXISTS (
           SELECT 1 FROM clan_members cm
           WHERE cm.user_id = v_uid AND cm.clan_id = v_mp.target_clan_id
       )) THEN
        RAISE EXCEPTION 'motoposada_not_visible';
    END IF;
    IF v_mp.visibility = 'clan_only' AND NOT EXISTS (
        SELECT 1 FROM clan_members cm WHERE cm.user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'motoposada_not_visible';
    END IF;
    IF p_guest_count < 1 OR p_guest_count > v_mp.max_guests THEN
        RAISE EXCEPTION 'invalid_guest_count';
    END IF;
    IF EXISTS (
        SELECT 1 FROM motoposada_requests r
        WHERE r.motoposada_id = p_motoposada_id
          AND r.guest_id = v_uid
          AND r.status IN ('pending', 'approved')
          AND dates_overlap(r.check_in, r.check_out, p_check_in, p_check_out)
    ) THEN
        RAISE EXCEPTION 'overlapping_request';
    END IF;

    INSERT INTO motoposada_requests (
        motoposada_id, guest_id, check_in, check_out, guest_count, message, status
    ) VALUES (
        p_motoposada_id, v_uid, p_check_in, p_check_out,
        p_guest_count, p_message, 'pending'
    ) RETURNING id INTO v_id;

    RETURN v_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'overlapping_request';
END;
$$;

REVOKE ALL ON FUNCTION public.request_motoposada(
    BIGINT, DATE, DATE, INT, TEXT
) FROM public;
GRANT EXECUTE ON FUNCTION public.request_motoposada(
    BIGINT, DATE, DATE, INT, TEXT
) TO authenticated;

-- ============================================================
-- 5. RPC respond_motoposada_request — aprobar/rechazar (host)
-- ============================================================
-- Solo el dueño de la motoposada. Transición ÚNICA: pending → approved/
-- rejected (cualquier otro estado → invalid_status). En aprobación se
-- validan fechas cruzadas: la motoposada no puede quedar doble-reservada
-- y el guest no puede tener otra estancia aprobada en el mismo rango.
-- Locks en orden fijo request → motoposada → users (sin deadlock): el
-- chequeo de solapamiento corre como statement POSTERIOR al lock wait, con
-- snapshot fresco — dos approves concurrentes no cruzan fechas.
CREATE OR REPLACE FUNCTION public.respond_motoposada_request(
    p_request_id BIGINT,
    p_approve    BOOLEAN
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_req RECORD;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT r.*, m.user_id AS host_id
      INTO v_req
      FROM motoposada_requests r
      JOIN motoposadas m ON m.id = r.motoposada_id
     WHERE r.id = p_request_id
       FOR UPDATE OF r;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'request_not_found';
    END IF;
    IF v_req.host_id <> v_uid THEN
        RAISE EXCEPTION 'not_host';
    END IF;
    IF v_req.status <> 'pending' THEN
        RAISE EXCEPTION 'invalid_status';
    END IF;

    IF p_approve THEN
        -- Serializa aprobaciones de la misma motoposada.
        PERFORM 1 FROM motoposadas WHERE id = v_req.motoposada_id FOR UPDATE;
        -- Serializa aprobaciones cruzadas del mismo guest (otro host).
        PERFORM 1 FROM public.users WHERE id = v_req.guest_id FOR UPDATE;

        -- La casa ya está reservada en ese rango.
        IF EXISTS (
            SELECT 1 FROM motoposada_requests x
            WHERE x.motoposada_id = v_req.motoposada_id
              AND x.id <> p_request_id
              AND x.status = 'approved'
              AND dates_overlap(x.check_in, x.check_out, v_req.check_in, v_req.check_out)
        ) THEN
            RAISE EXCEPTION 'motoposada_already_booked';
        END IF;
        -- El guest ya tiene otra estancia aprobada con fechas cruzadas.
        IF EXISTS (
            SELECT 1 FROM motoposada_requests x
            WHERE x.guest_id = v_req.guest_id
              AND x.id <> p_request_id
              AND x.status = 'approved'
              AND dates_overlap(x.check_in, x.check_out, v_req.check_in, v_req.check_out)
        ) THEN
            RAISE EXCEPTION 'guest_already_booked';
        END IF;
    END IF;

    UPDATE motoposada_requests
       SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
           host_response_at = now()
     WHERE id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.respond_motoposada_request(BIGINT, BOOLEAN) FROM public;
GRANT EXECUTE ON FUNCTION public.respond_motoposada_request(BIGINT, BOOLEAN) TO authenticated;

-- ============================================================
-- 6. RPC complete_motoposada_request — finalizar estancia (host)
-- ============================================================
-- Transición ÚNICA: approved → completed. Guarda de control: la estancia
-- debe haber comenzado (check_in <= current_date) — no se finaliza una
-- reserva futura.
CREATE OR REPLACE FUNCTION public.complete_motoposada_request(
    p_request_id BIGINT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_req RECORD;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT r.*, m.user_id AS host_id
      INTO v_req
      FROM motoposada_requests r
      JOIN motoposadas m ON m.id = r.motoposada_id
     WHERE r.id = p_request_id
       FOR UPDATE OF r;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'request_not_found';
    END IF;
    IF v_req.host_id <> v_uid THEN
        RAISE EXCEPTION 'not_host';
    END IF;
    IF v_req.status <> 'approved' THEN
        RAISE EXCEPTION 'invalid_status';
    END IF;
    IF v_req.check_in > current_date THEN
        RAISE EXCEPTION 'stay_not_started';
    END IF;

    UPDATE motoposada_requests
       SET status = 'completed',
           host_response_at = now()
     WHERE id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_motoposada_request(BIGINT) FROM public;
GRANT EXECUTE ON FUNCTION public.complete_motoposada_request(BIGINT) TO authenticated;

-- ============================================================
-- 7. RPC cancel_motoposada_request — cancelar (guest, pre-check-in)
-- ============================================================
-- Solo el guest. Estados cancelables: pending/approved. ÚNICAMENTE antes
-- del check-in (current_date < check_in): una vez iniciada la estancia el
-- anfitrión decide (complete); el guest no puede borrar el historial.
CREATE OR REPLACE FUNCTION public.cancel_motoposada_request(
    p_request_id BIGINT
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_req RECORD;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT r.*
      INTO v_req
      FROM motoposada_requests r
     WHERE r.id = p_request_id
       FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'request_not_found';
    END IF;
    IF v_req.guest_id <> v_uid THEN
        RAISE EXCEPTION 'not_guest';
    END IF;
    IF v_req.status NOT IN ('pending', 'approved') THEN
        RAISE EXCEPTION 'invalid_status';
    END IF;
    IF v_req.check_in <= current_date THEN
        RAISE EXCEPTION 'too_late_to_cancel';
    END IF;

    UPDATE motoposada_requests
       SET status = 'cancelled'
     WHERE id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_motoposada_request(BIGINT) FROM public;
GRANT EXECUTE ON FUNCTION public.cancel_motoposada_request(BIGINT) TO authenticated;

-- ============================================================
-- 8. RPC submit_motoposada_review — reseña post-completado + trust_score
-- ============================================================
-- SOLO después de estancia completada (status = 'completed'). Participante
-- según tipo: guest_review (guest → host) o host_review (host → guest).
-- Una sola reseña por (request, from, type) — UNIQUE de 009 como backstop.
-- trust_score se actualiza AQUÍ (mismo UPDATE clamp 0..100 de 030), con el
-- delta derivado del rating en el servidor: rating >= 4 → +2, <= 2 → -2,
-- resto 0. Todo en una sola llamada = transacción implícita (si el UPDATE
-- falla, la reseña no queda huérfana).
CREATE OR REPLACE FUNCTION public.submit_motoposada_review(
    p_request_id BIGINT,
    p_to_user_id UUID,
    p_type       TEXT,
    p_rating     INT,
    p_comment    TEXT DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid    UUID := auth.uid();
    v_req    RECORD;
    v_delta  INT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'invalid_rating';
    END IF;

    SELECT r.*, m.user_id AS host_id
      INTO v_req
      FROM motoposada_requests r
      JOIN motoposadas m ON m.id = r.motoposada_id
     WHERE r.id = p_request_id
       FOR UPDATE OF r;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'request_not_found';
    END IF;
    IF v_req.status <> 'completed' THEN
        RAISE EXCEPTION 'stay_not_completed';
    END IF;

    IF p_type = 'guest_review' THEN
        IF v_uid <> v_req.guest_id OR p_to_user_id <> v_req.host_id THEN
            RAISE EXCEPTION 'not_participant';
        END IF;
    ELSIF p_type = 'host_review' THEN
        IF v_uid <> v_req.host_id OR p_to_user_id <> v_req.guest_id THEN
            RAISE EXCEPTION 'not_participant';
        END IF;
    ELSE
        RAISE EXCEPTION 'invalid_review_type';
    END IF;

    IF EXISTS (
        SELECT 1 FROM motoposada_reviews
        WHERE request_id = p_request_id
          AND from_user_id = v_uid
          AND type = p_type
    ) THEN
        RAISE EXCEPTION 'review_already_exists';
    END IF;

    INSERT INTO motoposada_reviews (
        motoposada_id, request_id, from_user_id, to_user_id,
        type, rating, comment, behavior_flags
    ) VALUES (
        v_req.motoposada_id, p_request_id, v_uid, p_to_user_id,
        p_type, p_rating, p_comment, 0
    );

    v_delta := CASE WHEN p_rating >= 4 THEN 2
                    WHEN p_rating <= 2 THEN -2
                    ELSE 0 END;
    IF v_delta <> 0 THEN
        UPDATE user_xp
           SET trust_score = GREATEST(0, LEAST(100, COALESCE(trust_score, 50) + v_delta))
         WHERE user_id = p_to_user_id;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_motoposada_review(
    BIGINT, UUID, TEXT, INT, TEXT
) FROM public;
GRANT EXECUTE ON FUNCTION public.submit_motoposada_review(
    BIGINT, UUID, TEXT, INT, TEXT
) TO authenticated;

COMMIT;
