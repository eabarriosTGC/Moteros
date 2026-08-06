-- MIGRATION 027: dedupe achievements catalog + UNIQUE guard (P2-5)
--
-- Prod had 34 rows in `achievements` but only 17 unique names: the seed
-- inserted the catalog twice (ids 1-17 and 18-34 with identical names). The
-- Progreso screen rendered every badge twice. The table had no UNIQUE on
-- name, so the duplication was possible and invisible to the schema.
--
-- Applied to prod on 2026-08-05 (17 rows deleted, constraint added). This
-- file versions the fix so fresh environments get the same shape.
BEGIN;

-- Keep the lowest ids (1-17, the original seed set), drop the duplicates.
-- Safe: no FK referenced achievement_id > 17 at apply time (verified: 0 rows
-- in user_achievements pointing to 18-34). If a fresh environment seeded
-- once, this deletes nothing; if seeded twice, it dedupes.
DELETE FROM achievements a
USING achievements dup
WHERE dup.id > a.id
  AND dup.name = a.name;

-- Prevent recurrence: the catalog is a closed set of named badges.
ALTER TABLE achievements
    ADD CONSTRAINT uq_achievements_name UNIQUE (name);

COMMIT;
