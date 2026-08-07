-- MIGRATION 033: alinear los roles de club_members
--
-- La migracion 010 renombro clan_members a club_members, pero PostgreSQL
-- conservo el nombre de la constraint original (clan_members_role_check).
-- Luego 010 intento eliminar club_members_role_check, agrego una segunda
-- constraint con el vocabulario nuevo y dejo el DEFAULT antiguo 'recruit'.
-- Como ambos CHECK aceptaban conjuntos disjuntos, ninguna insercion podia
-- satisfacerlos simultaneamente.
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

ALTER TABLE public.club_members
    DROP CONSTRAINT IF EXISTS clan_members_role_check;

ALTER TABLE public.club_members
    ALTER COLUMN role SET DEFAULT 'aspirante';

-- Reemplazarla evita depender del estado previo del entorno y deja una sola
-- definicion canonica, incluso donde 010 se aplico de forma parcial.
ALTER TABLE public.club_members
    DROP CONSTRAINT IF EXISTS club_members_role_check;

ALTER TABLE public.club_members
    ADD CONSTRAINT club_members_role_check
    CHECK (role IN ('presidente', 'oficial', 'honorable', 'aspirante'))
    NOT VALID;

ALTER TABLE public.club_members
    VALIDATE CONSTRAINT club_members_role_check;

COMMIT;
