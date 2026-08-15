-- 046: fix bloque 6 — private.manages_club sin EXECUTE para authenticated.
-- La migración 044 crea la policy club_join_requests_select que llama
-- private.manages_club(club_id) en su USING, pero la misma 044 ejecuta
-- REVOKE ALL ON FUNCTION private.manages_club FROM PUBLIC, anon, authenticated
-- sin volver a grantear EXECUTE. Las policies RLS se evalúan con los permisos
-- del rol de sesión, así que cualquier SELECT sobre club_join_requests
-- fallaba con 42501 "permission denied for function manages_club" y la app
-- mostraba el error genérico de carga de Clanes.
BEGIN;

GRANT EXECUTE ON FUNCTION private.manages_club(BIGINT) TO authenticated;

COMMIT;
