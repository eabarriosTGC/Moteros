-- SEED: Temporada 1 del Battle Pass + misiones iniciales
-- ============================================================
-- Ejecutar DESPUÉS de migration 011
-- ============================================================

BEGIN;

-- Temporada 1: "Ruta del Asfalto"
INSERT INTO battle_passes (season_name, season_number, start_date, end_date, cosmetic_rewards, is_active)
SELECT 'Ruta del Asfalto', 1, CURRENT_DATE, CURRENT_DATE + INTERVAL '60 days',
    jsonb_build_object(
        'free_tiers', jsonb_build_array(
            jsonb_build_object('tier', 5, 'reward', '100 coins'),
            jsonb_build_object('tier', 10, 'reward', 'Parche "Asfalto"'),
            jsonb_build_object('tier', 15, 'reward', '200 coins'),
            jsonb_build_object('tier', 20, 'reward', 'Título "Ruta del Asfalto"'),
            jsonb_build_object('tier', 25, 'reward', '300 coins'),
            jsonb_build_object('tier', 30, 'reward', 'Banner Temporada 1'),
            jsonb_build_object('tier', 35, 'reward', '400 coins'),
            jsonb_build_object('tier', 40, 'reward', 'Marco avatar "Asfalto"'),
            jsonb_build_object('tier', 45, 'reward', '500 coins'),
            jsonb_build_object('tier', 50, 'reward', 'Parche legendario "Rey del Asfalto"')
        ),
        'premium_tiers', jsonb_build_array(
            jsonb_build_object('tier', 1, 'reward', '50 coins'),
            jsonb_build_object('tier', 2, 'reward', 'XP Boost x2 (1 uso)'),
            jsonb_build_object('tier', 3, 'reward', '75 coins'),
            jsonb_build_object('tier', 4, 'reward', 'Parche premium "Fuego"'),
            jsonb_build_object('tier', 5, 'reward', '100 coins + Banner'),
            jsonb_build_object('tier', 6, 'reward', 'Estela checkpoint "Ámbar"'),
            jsonb_build_object('tier', 7, 'reward', '100 coins'),
            jsonb_build_object('tier', 8, 'reward', 'Skin avatar "Casco Carbono"'),
            jsonb_build_object('tier', 9, 'reward', '125 coins'),
            jsonb_build_object('tier', 10, 'reward', '150 coins + Parche "Velocidad"'),
            jsonb_build_object('tier', 11, 'reward', '100 coins'),
            jsonb_build_object('tier', 12, 'reward', 'XP Boost x3 (1 uso)'),
            jsonb_build_object('tier', 13, 'reward', '125 coins'),
            jsonb_build_object('tier', 14, 'reward', 'Título premium "Velocista Élite"'),
            jsonb_build_object('tier', 15, 'reward', '150 coins + Banner premium'),
            jsonb_build_object('tier', 16, 'reward', 'Estela checkpoint "Oro"'),
            jsonb_build_object('tier', 17, 'reward', '150 coins'),
            jsonb_build_object('tier', 18, 'reward', 'Skin moto "Deportiva Edición BP"'),
            jsonb_build_object('tier', 19, 'reward', '175 coins'),
            jsonb_build_object('tier', 20, 'reward', '200 coins + Marco avatar premium'),
            jsonb_build_object('tier', 21, 'reward', '150 coins'),
            jsonb_build_object('tier', 22, 'reward', 'XP Boost x5 (1 uso)'),
            jsonb_build_object('tier', 23, 'reward', '175 coins'),
            jsonb_build_object('tier', 24, 'reward', 'Parche premium "Leyenda"'),
            jsonb_build_object('tier', 25, 'reward', '200 coins + Banner "Rey del Asfalto"'),
            jsonb_build_object('tier', 26, 'reward', '200 coins'),
            jsonb_build_object('tier', 27, 'reward', 'Estela checkpoint "Diamante"'),
            jsonb_build_object('tier', 28, 'reward', '225 coins'),
            jsonb_build_object('tier', 29, 'reward', 'Skin avatar "Casco Legendario"'),
            jsonb_build_object('tier', 30, 'reward', '250 coins + Skin moto "Custom BP"'),
            jsonb_build_object('tier', 31, 'reward', '200 coins'),
            jsonb_build_object('tier', 32, 'reward', 'XP Boost x5 (2 usos)'),
            jsonb_build_object('tier', 33, 'reward', '225 coins'),
            jsonb_build_object('tier', 34, 'reward', 'Título premium "Leyenda del Asfalto"'),
            jsonb_build_object('tier', 35, 'reward', '250 coins + Marco premium diamante'),
            jsonb_build_object('tier', 36, 'reward', '250 coins'),
            jsonb_build_object('tier', 37, 'reward', 'Estela checkpoint "Fuego Azul"'),
            jsonb_build_object('tier', 38, 'reward', '275 coins'),
            jsonb_build_object('tier', 39, 'reward', 'XP Boost x10 (1 uso)'),
            jsonb_build_object('tier', 40, 'reward', '300 coins + Parche "Inmortal"'),
            jsonb_build_object('tier', 41, 'reward', '250 coins'),
            jsonb_build_object('tier', 42, 'reward', 'Banner animado premium'),
            jsonb_build_object('tier', 43, 'reward', '275 coins'),
            jsonb_build_object('tier', 44, 'reward', 'Marco avatar "Fuego Eterno"'),
            jsonb_build_object('tier', 45, 'reward', '300 coins + Skin moto legendaria'),
            jsonb_build_object('tier', 46, 'reward', '300 coins'),
            jsonb_build_object('tier', 47, 'reward', 'XP Boost x10 (2 usos)'),
            jsonb_build_object('tier', 48, 'reward', '350 coins'),
            jsonb_build_object('tier', 49, 'reward', 'Estela checkpoint "Arcoíris"'),
            jsonb_build_object('tier', 50, 'reward', '500 coins + Parche legendario "Emperador del Asfalto" + Marco exclusivo')
        )
    ), true
WHERE NOT EXISTS (SELECT 1 FROM battle_passes WHERE season_number = 1);

-- Misiones diarias (se asignan por temporada)
DO $$
DECLARE
    v_bp_id UUID;
BEGIN
    SELECT id INTO v_bp_id FROM battle_passes WHERE season_number = 1 LIMIT 1;

    IF v_bp_id IS NOT NULL THEN
        INSERT INTO battle_pass_missions (battle_pass_id, title, description, requirement, xp_reward, tier_unlock, is_daily)
        VALUES
            (v_bp_id, 'Rider Diario', 'Completá 1 raid',           '{"type": "raids_completed", "count": 1}',   100, 1, true),
            (v_bp_id, 'Checkpoint Hunter', 'Capturá 3 checkpoints', '{"type": "checkpoints_captured", "count": 3}', 80, 1, true),
            (v_bp_id, 'Kilometraje Diario', 'Recorré 5 km',        '{"type": "km_traveled", "count": 5}',       120, 1, true),
            (v_bp_id, 'Velocidad', 'Ganá 1 raid en modo Rally',    '{"type": "mode_wins", "mode": "rally", "count": 1}', 150, 5, true),
            (v_bp_id, 'Social', 'Enviale un ping a otro rider',     '{"type": "pings_sent", "count": 1}',         50, 1, true)
        ON CONFLICT DO NOTHING;

        -- Misiones semanales
        INSERT INTO battle_pass_missions (battle_pass_id, title, description, requirement, xp_reward, tier_unlock, is_daily)
        VALUES
            (v_bp_id, 'Semana del Asfalto', 'Completá 10 raids',              '{"type": "raids_completed", "count": 10}',   400, 1, false),
            (v_bp_id, 'Conquistador', 'Capturá 20 checkpoints',               '{"type": "checkpoints_captured", "count": 20}', 350, 1, false),
            (v_bp_id, 'Larga Distancia', 'Recorré 50 km',                     '{"type": "km_traveled", "count": 50}',      500, 1, false),
            (v_bp_id, 'Modo Leyenda', 'Ganá 3 raids en modo Sobrevivencia',   '{"type": "mode_wins", "mode": "sobrevivencia", "count": 3}', 400, 10, false),
            (v_bp_id, 'Clan Unido', 'Completá 3 raids en clan',               '{"type": "clan_raids_completed", "count": 3}', 300, 1, false),
            (v_bp_id, 'Racha', 'Mantené racha de 3 días',                     '{"type": "streak_days", "count": 3}',        450, 15, false),
            (v_bp_id, 'Ruta Extrema', 'Completá una ruta de +20 km',           '{"type": "route_completed_min_km", "count": 20}', 350, 1, false)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

COMMIT;
