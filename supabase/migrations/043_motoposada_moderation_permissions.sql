-- 043: endurecimiento de permisos del Bloque 4.
-- Supabase Cloud auto-grantea EXECUTE (anon/authenticated/service_role) a funciones
-- nuevas tras cada db push; la 042 revocaba de PUBLIC, pero anon seguía ejecutando
-- (el ACL mostró anon=X/postgres en todas las funciones). Aquí se revoca por rol,
-- de forma explícita e idempotente.
BEGIN;

-- 1) anon pierde EXECUTE sobre TODAS las funciones del Bloque 4
REVOKE ALL ON FUNCTION public.get_motoposada_moderation_queue(TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.decide_motoposada_incident(BIGINT, TEXT, TEXT, TIMESTAMPTZ) FROM anon;
REVOKE ALL ON FUNCTION public.appeal_motoposada_suspension(BIGINT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.review_motoposada_appeal(BIGINT, BOOLEAN, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.is_motoposada_suspended(UUID) FROM anon;
REVOKE ALL ON FUNCTION public.enforce_motoposada_user_block() FROM anon;

-- 2) authenticated conserva únicamente las cuatro RPC públicas del flujo de moderación
GRANT EXECUTE ON FUNCTION public.get_motoposada_moderation_queue(TEXT),
    public.decide_motoposada_incident(BIGINT, TEXT, TEXT, TIMESTAMPTZ),
    public.appeal_motoposada_suspension(BIGINT, TEXT),
    public.review_motoposada_appeal(BIGINT, BOOLEAN, TEXT) TO authenticated;

-- 3) funciones internas: ni anon ni authenticated (solo el owner SECURITY DEFINER)
REVOKE ALL ON FUNCTION public.is_motoposada_suspended(UUID) FROM authenticated;
REVOKE ALL ON FUNCTION public.enforce_motoposada_user_block() FROM authenticated;

COMMIT;
