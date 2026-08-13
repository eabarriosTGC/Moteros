-- 045: fix clase 038 — funciones de clubes con refs sin calificar que
-- reventaban (42P01) bajo el search_path='' de las RPC SECURITY DEFINER del
-- bloque 6. Se fija search_path y se califican todas las referencias.
BEGIN;

CREATE OR REPLACE FUNCTION public.auto_create_default_ranks()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.club_ranks (club_id, name, level, max_slots, is_leader, requirements)
    VALUES
        (NEW.id, 'presidente', 3, 1, TRUE, '{}'),
        (NEW.id, 'oficial', 2, 5, FALSE, '{"min_km": 500}'),
        (NEW.id, 'honorable', 1, NULL, FALSE, '{"min_km": 100}'),
        (NEW.id, 'aspirante', 0, NULL, FALSE, '{}');
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_create_default_ranks() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_single_presidente()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.role = 'presidente' AND EXISTS (
        SELECT 1 FROM public.club_members
        WHERE club_id = NEW.club_id AND role = 'presidente' AND id != NEW.id
    ) THEN
        RAISE EXCEPTION 'Ya existe un presidente en este club';
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_single_presidente() FROM PUBLIC, anon, authenticated;

COMMIT;
