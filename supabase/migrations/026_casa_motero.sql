-- MIGRATION 026: casa_motero (F-M9/F-M10/F-M11)
-- Additiva e idempotente. Depende de haversine_distance (001).
-- ⚠ DEPLOY-SIDE APPLY: esta migración debe aplicarse a Supabase ANTES del
--   release de la app (el create RPC y el select de details dependen de ella).
BEGIN;

-- is_approved es una columna ad-hoc en prod (la escribe _onCreateTouristPoi,
-- ninguna migración la declara — precedente igual a bike_model/phone en 025).
-- Se declara aquí para que el trail coincida con la realidad. Casa_motero no
-- la usa.
ALTER TABLE motoposadas
    ADD COLUMN IF NOT EXISTS is_approved BOOLEAN;

-- ── 1. Invariante max-1 (M-CRUD-1): un solo casa_motero por usuario ──
CREATE UNIQUE INDEX IF NOT EXISTS uq_motoposadas_casa_motero_user
    ON motoposadas(user_id)
    WHERE poi_type = 'casa_motero';

-- Reviewer fix (2026-08-05): mp_insert_own (009) es WITH CHECK sin
-- restricción de poi_type → un POST directo podía crear casa_motero con
-- coords exactas, eludiendo disclaimer + blur floor. Se re-crea con la
-- exclusión; el RPC (SECURITY DEFINER, BYPASSRLS como 025) queda como
-- ÚNICO path de INSERT de casa_motero.
DROP POLICY IF EXISTS mp_insert_own ON motoposadas;
CREATE POLICY "mp_insert_own" ON motoposadas
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND poi_type IS DISTINCT FROM 'casa_motero'
    );

-- ── 2. Tabla privada: coords exactas + WhatsApp + disclaimer ──
CREATE TABLE IF NOT EXISTS casa_motero_details (
    id                      BIGSERIAL PRIMARY KEY,
    motoposada_id           BIGINT NOT NULL UNIQUE
                            REFERENCES motoposadas(id) ON DELETE CASCADE,
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lat_exact               DOUBLE PRECISION NOT NULL,
    lng_exact               DOUBLE PRECISION NOT NULL,
    whatsapp_phone          TEXT NOT NULL
                            CHECK (whatsapp_phone ~ '^\+?[0-9]{7,15}$'),
    disclaimer_accepted_at  TIMESTAMPTZ NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cmd_user ON casa_motero_details(user_id);

ALTER TABLE casa_motero_details ENABLE ROW LEVEL SECURITY;

-- Owner-only (M-CRUD-2). Columna directa user_id: sin subqueries cruzadas
-- (precedente de recursión RLS 012/013).
CREATE POLICY "cmd_select_own" ON casa_motero_details
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "cmd_update_own" ON casa_motero_details
    FOR UPDATE USING (user_id = auth.uid());
-- Reviewer fix: SIN cmd_delete_own — un DELETE directo de details dejaría
-- un casa_motero público huérfano (marker renderiza, Contactar=NULL, edits
-- futuros mueren con casa_motero_details_missing). El borrado legítimo es
-- vía mp_delete_own en motoposadas + FK CASCADE (atómico, §1.4).
-- Sin policy de INSERT: el único path de creación es create_casa_motero()
-- (SECURITY DEFINER). Un INSERT directo del owner podría eludir el floor
-- de blur y el disclaimer — se bloquea por ausencia de policy.

-- ── 3. RPC create (M-CRUD-3/M-CRUD-5, M-MAPA-1) ──
-- SECURITY DEFINER con firma fija estrecha: el server deriva user_id de
-- auth.uid() (no se acepta como parámetro), valida disclaimer, teléfono,
-- capacidad y el floor de >=300 m entre approx y exact (anti-defeat del blur).
CREATE OR REPLACE FUNCTION public.create_casa_motero(
    p_title                 TEXT,
    p_description           TEXT,
    p_max_guests            INT,
    p_lat                   DOUBLE PRECISION,  -- approx (público, difuminado)
    p_lng                   DOUBLE PRECISION,
    p_lat_exact             DOUBLE PRECISION,  -- exacto (privado)
    p_lng_exact             DOUBLE PRECISION,
    p_whatsapp_phone        TEXT,
    p_disclaimer_accepted_at TIMESTAMPTZ
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_id  BIGINT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_disclaimer_accepted_at IS NULL THEN
        RAISE EXCEPTION 'disclaimer_not_accepted';
    END IF;
    IF p_whatsapp_phone IS NULL OR p_whatsapp_phone !~ '^\+?[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'invalid_whatsapp_phone';
    END IF;
    IF p_max_guests < 1 THEN
        RAISE EXCEPTION 'invalid_max_guests';
    END IF;
    -- Floor de blur: frontera de seguridad SERVER-side (M-MAPA-1).
    IF haversine_distance(p_lat, p_lng, p_lat_exact, p_lng_exact) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;

    -- Fila pública: coords difuminadas; address NULL (nunca se recolecta);
    -- is_active = disponible (TRUE); visibility forzada 'public'; poi_type
    -- 'casa_motero' sobre type='casa' (CHECK 009 intacto).
    INSERT INTO motoposadas (
        user_id, type, title, description, lat, lng,
        address, max_guests, is_active, visibility, poi_type
    ) VALUES (
        v_uid, 'casa', p_title, p_description, p_lat, p_lng,
        NULL, p_max_guests, TRUE, 'public', 'casa_motero'
    ) RETURNING id INTO v_id;

    -- Fila privada. Dos INSERTs en una sola llamada = transacción implícita:
    -- si el segundo falla, el primero se revierte (sin escritura parcial,
    -- M-CRUD-2). El 23505 del índice parcial revierte todo también.
    INSERT INTO casa_motero_details (
        motoposada_id, user_id, lat_exact, lng_exact,
        whatsapp_phone, disclaimer_accepted_at
    ) VALUES (
        v_id, v_uid, p_lat_exact, p_lng_exact,
        p_whatsapp_phone, p_disclaimer_accepted_at
    );

    RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_casa_motero(
    TEXT, TEXT, INT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    DOUBLE PRECISION, TEXT, TIMESTAMPTZ) FROM public;
GRANT EXECUTE ON FUNCTION public.create_casa_motero(
    TEXT, TEXT, INT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    DOUBLE PRECISION, TEXT, TIMESTAMPTZ) TO authenticated;

-- ── 4. RPC contacto (F-M11): teléfono ON DEMAND ──
-- SECURITY DEFINER tradeoff documentado: bypasea RLS por diseño (lee la tabla
-- privada sin policy SELECT para el caller). Mitigación: firma de un solo id,
-- guard activo + tipo, retorna SOLO whatsapp_phone (nunca coords exactas).
-- Devuelve NULL para inexistente / inactivo / no-casa_motero (sin oráculo de
-- existencia: mismo resultado que un id inválido).
CREATE OR REPLACE FUNCTION public.get_motoposada_whatsapp(p_id BIGINT)
RETURNS TEXT
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
    SELECT d.whatsapp_phone
    FROM motoposadas m
    JOIN casa_motero_details d ON d.motoposada_id = m.id
    WHERE m.id = p_id
      AND m.poi_type = 'casa_motero'
      AND m.is_active = TRUE
$$;

REVOKE ALL ON FUNCTION public.get_motoposada_whatsapp(BIGINT) FROM public;
GRANT EXECUTE ON FUNCTION public.get_motoposada_whatsapp(BIGINT) TO authenticated;

-- ── 5. Triggers blur floor en edit paths (M-MAPA-1) ──
-- Disparan sobre UPDATE de coords públicas (motoposadas) y sobre
-- INSERT/UPDATE de coords exactas (details). SECURITY DEFINER: el chequeo
-- no puede eludirse vía RLS del invocador.
CREATE OR REPLACE FUNCTION public.enforce_casa_motero_blur_floor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exact_lat DOUBLE PRECISION;
    v_exact_lng DOUBLE PRECISION;
BEGIN
    SELECT lat_exact, lng_exact INTO v_exact_lat, v_exact_lng
    FROM casa_motero_details WHERE motoposada_id = NEW.id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'casa_motero_details_missing';
    END IF;
    IF haversine_distance(NEW.lat, NEW.lng, v_exact_lat, v_exact_lng) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_casa_motero_blur_floor ON motoposadas;
-- No dispara en INSERT: en create el RPC ya validó y la fila details aún no
-- existe (evita el orden circular motoposadas→details).
-- Reviewer fix: incluye poi_type en la columna lista — sin esto, un UPDATE
-- podía FLIPEAR una fila existente a casa_motero (el trigger con column-list
-- lat,lng no disparaba) y desenmascarar coords exactas vía marker público.
-- El flip-in ahora muere con 'casa_motero_details_missing' (no hay details
-- row). Caso residual aceptable y documentado: flip-out de casa_motero queda
-- permitido (huérfana details y libera el slot max-1).
CREATE TRIGGER trg_casa_motero_blur_floor
    BEFORE UPDATE OF lat, lng, poi_type ON motoposadas
    FOR EACH ROW
    WHEN (NEW.poi_type = 'casa_motero')
    EXECUTE FUNCTION public.enforce_casa_motero_blur_floor();

CREATE OR REPLACE FUNCTION public.enforce_casa_motero_details_blur_floor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_public_lat DOUBLE PRECISION;
    v_public_lng DOUBLE PRECISION;
BEGIN
    SELECT lat, lng INTO v_public_lat, v_public_lng
    FROM motoposadas WHERE id = NEW.motoposada_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'motoposada_missing';
    END IF;
    IF haversine_distance(NEW.lat_exact, NEW.lng_exact, v_public_lat, v_public_lng) < 300 THEN
        RAISE EXCEPTION 'blur_floor_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_casa_motero_details_blur_floor ON casa_motero_details;
CREATE TRIGGER trg_casa_motero_details_blur_floor
    BEFORE INSERT OR UPDATE OF lat_exact, lng_exact ON casa_motero_details
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_casa_motero_details_blur_floor();

COMMIT;
