-- MIGRATION 030: update_trust_score RPC (fix del catch silencioso de trust_score)
-- =============================================================================
-- Contexto (2026-08-06, cambio beta-prioridades, hallazgo del catch audit):
--   motoposadas_bloc.dart:302 tenía `catch (_) {}` alrededor del UPDATE de
--   user_xp.trust_score tras una review. El update directo cross-user FALLA
--   SIEMPRE por RLS: user_xp solo define xp_select_all/xp_insert_own
--   (007_rls.sql:260-261) — NO hay policy de UPDATE. El catch vacío tragaba
--   el fallo sistemático: la reputación de los anfitriones NUNCA se
--   actualizó desde que existe motoposada_reviews.
--
-- Fix: RPC SECURITY DEFINER (patrón increment_checkpoints, 001_functions.sql:
-- 66-80) — bypass RLS para el update del owner, con dos guardas server-side:
--   1. auth.uid() autenticado.
--   2. Anti-abuso: solo se puede ajustar el trust_score de quien te reviewó
--      en las últimas 2 horas (motoposada_reviews.from_user_id = auth.uid()).
--      El flujo del cliente inserta la review y llama el RPC justo después —
--      el guard pasa en el uso legítimo y bloquea llamadas directas abusivas.
--   3. Delta acotado: |delta| <= 2 (el cliente solo pasa -2/0/2 por rating).
--      clamp 0..100 con default 50 para filas legacy sin trust_score.
-- Additiva e idempotente (CREATE OR REPLACE).
BEGIN;

CREATE OR REPLACE FUNCTION public.update_trust_score(p_user_id uuid, p_delta int)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Anti-abuso: solo el destinatario de una review RECIENTE del invocador.
  IF NOT EXISTS (
    SELECT 1 FROM motoposada_reviews
    WHERE from_user_id = auth.uid()
      AND to_user_id = p_user_id
      AND created_at >= now() - interval '2 hours'
  ) THEN
    RAISE EXCEPTION 'no recent review from this user';
  END IF;

  -- Delta acotado (rating >= 4 → +2, <= 2 → -2).
  IF abs(p_delta) > 2 THEN
    RAISE EXCEPTION 'trust delta out of range';
  END IF;

  UPDATE user_xp
  SET trust_score = GREATEST(0, LEAST(100, COALESCE(trust_score, 50) + p_delta))
  WHERE user_id = p_user_id;
END;
$$;

COMMIT;
