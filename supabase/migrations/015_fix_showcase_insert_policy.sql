-- FIX: Add missing INSERT policy for user_showcase
-- El único INSERT que se hace desde la app es ensureShowcase(),
-- que inserta SOLO user_id (el resto son updates posteriores).
-- WITH CHECK (auth.uid() = user_id) impide que un usuario
-- cree una fila que no le pertenezca.

BEGIN;

CREATE POLICY "usc_insert_own" ON user_showcase
  FOR INSERT WITH CHECK (auth.uid() = user_id);

COMMIT;
