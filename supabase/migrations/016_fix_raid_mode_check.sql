-- FIX: Update raids.mode CHECK constraint to match new UI game modes.
-- Antes: free_ride, rally, ruta_gotica, convoy, sobrevivencia, guerra_clanes
-- Ahora: aventura, velocidad, precision, sobrevivencia, exploracion
-- El mapeo UI→DB se hace en raid_bloc.dart via _mapGameMode()

BEGIN;

ALTER TABLE raids DROP CONSTRAINT IF EXISTS raids_mode_check;

ALTER TABLE raids ADD CONSTRAINT raids_mode_check
  CHECK (mode IN ('aventura', 'velocidad', 'precision', 'sobrevivencia', 'exploracion'));

COMMIT;
