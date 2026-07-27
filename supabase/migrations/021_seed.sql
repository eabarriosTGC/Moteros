-- MIGRATION 006: SEED DATA
-- ============================================================
-- Datos iniciales: achievements, shop items, leaderboard placeholder,
-- challenges legacy, patches legacy
-- ============================================================

BEGIN;

-- 3.1 Achievements (17 del SDD)
INSERT INTO achievements (name, icon, description, xp_reward, criteria, category, sort_order) VALUES
    ('Primer Raid',          '🏁', 'Completá tu primer raid',                 100,  '{"type": "raids_completed", "count": 1}',    'raids', 1),
    ('Corredor Nocturno',    '🌙', 'Completá 5 raids',                         250,  '{"type": "raids_completed", "count": 5}',    'raids', 2),
    ('Leyenda del Asfalto',  '👑', 'Completá 25 raids',                        1000, '{"type": "raids_completed", "count": 25}',   'raids', 3),
    ('Velocista',            '⚡', 'Ganá un Rally',                             200,  '{"type": "mode_wins", "mode": "rally", "count": 1}', 'raids', 4),
    ('Ruta Gótica',          '🗺️', 'Completá todos los checkpoints de una Ruta Gótica', 300, '{"type": "full_route_completion", "mode": "ruta_gotica", "count": 1}', 'raids', 5),
    ('Sobreviviente',        '💀', 'Completá un raid en modo Sobrevivencia',   350,  '{"type": "mode_wins", "mode": "sobrevivencia", "count": 1}', 'raids', 6),
    ('Guerrero de Clanes',   '⚔️', 'Ganá una Guerra de Clanes',                500,  '{"type": "mode_wins", "mode": "guerra_clanes", "count": 1}', 'clans', 7),
    ('Fundador',             '🏗️', 'Creá un clan',                              200,  '{"type": "clan_founded", "count": 1}',      'clans', 8),
    ('Clan Unido',           '🤝', 'Tu clan llega a 10 miembros',               300,  '{"type": "clan_members", "count": 10}',     'clans', 9),
    ('Explorador',           '📍', 'Visitá 10 checkpoints diferentes',         250,  '{"type": "checkpoints_captured", "count": 10}', 'checkpoints', 10),
    ('Checkpoint Master',    '🎯', 'Capturá 50 checkpoints',                    500,  '{"type": "checkpoints_captured", "count": 50}', 'checkpoints', 11),
    ('1000km Club',          '🏍️', 'Recorré 1,000 km en raids',                 500,  '{"type": "km_traveled", "count": 1000}',    'general', 12),
    ('Host Experto',         '🎪', 'Organizá 10 raids como host',               400,  '{"type": "raids_as_host", "count": 10}',    'raids', 13),
    ('Social Rider',         '👥', 'Seguí a 20 moteros',                        150,  '{"type": "following_count", "count": 20}',  'social', 14),
    ('Premium',              '💎', 'Activá membresía premium',                  500,  '{"type": "membership_activated", "count": 1}', 'membership', 15),
    ('Racha de 7 días',      '🔥', 'Completá raids 7 días consecutivos',       750,  '{"type": "streak_days", "count": 7}',       'raids', 16),
    ('Ping Pong',            '📌', 'Enviá 50 pings en raids',                   100,  '{"type": "pings_sent", "count": 50}',       'raids', 17);

-- 3.2 Shop items iniciales
INSERT INTO shop_items (name, description, type, subtype, icon_url, coins_cost, battle_pass_only, is_active) VALUES
    ('Casco Clásico',        'Skin de avatar: casco negro clásico',            'cosmetic', 'avatar_skin', NULL, 200,  FALSE, TRUE),
    ('Casco Carbono',        'Skin de avatar: casco de fibra de carbono',      'cosmetic', 'avatar_skin', NULL, 500,  FALSE, TRUE),
    ('Moto Deportiva',       'Skin de moto: estilo deportivo',                 'cosmetic', 'bike_skin',   NULL, 300,  FALSE, TRUE),
    ('Moto Custom',          'Skin de moto: estilo chopper',                   'cosmetic', 'bike_skin',   NULL, 400,  FALSE, TRUE),
    ('Banner Fuego',         'Banner de clan: estilo llama',                   'cosmetic', 'clan_banner', NULL, 250,  FALSE, TRUE),
    ('Marcador Neón',        'Color de marcador en mapa: verde neón',          'cosmetic', 'marker_color',NULL, 150,  FALSE, TRUE),
    ('Estela Laser',         'Efecto de checkpoint: laser verde',              'cosmetic', 'checkpoint_effect', NULL, 350, TRUE, TRUE),
    ('XP Boost x2',          'Multiplica tu XP x2 en tu próximo raid',         'consumable','xp_boost_small', NULL, 100,  FALSE, TRUE),
    ('Leyenda del Asfalto',  'Título cosmético: Leyenda del Asfalto',          'cosmetic', 'title',       NULL, 800,  FALSE, TRUE),
    ('Rider Nocturno',       'Título cosmético: Rider Nocturno',               'cosmetic', 'title',       NULL, 600,  FALSE, TRUE),
    ('Banner Hielo',         'Banner de clan: estilo glacial',                 'cosmetic', 'clan_banner', NULL, 250,  TRUE, TRUE),
    ('Estela Fuego',         'Efecto de checkpoint: fuego',                    'cosmetic', 'checkpoint_effect', NULL, 350, TRUE, TRUE);

-- 3.3 Leaderboard placeholder
INSERT INTO leaderboard_snapshots (category, rank, user_id, metric_value, snapshot_date)
VALUES ('general', 1, NULL, 0, CURRENT_DATE);

-- 3.4 Challenges legacy
INSERT INTO challenges (title, description, icon, sort_order) VALUES
    ('Primera Visita',    'Visitá tu primer lugar',                '📍', 1),
    ('5 Lugares',         'Visitá 5 lugares diferentes',          '📍', 2),
    ('10 Lugares',        'Visitá 10 lugares diferentes',         '📍', 3),
    ('Ruta Larga',        'Grabá una ruta de más de 50 km',       '🏍️', 4),
    ('Madrugador',        'Visitá un lugar antes de las 8 AM',    '🌅', 5),
    ('Noctámbulo',        'Visitá un lugar después de las 10 PM', '🌙', 6);

-- 3.5 Patches legacy
INSERT INTO patches (name, icon, place, requirement) VALUES
    ('Parche Visitante',    '📍', NULL, 'Visitá 1 lugar'),
    ('Parche Explorador',   '🗺️', NULL, 'Visitá 5 lugares'),
    ('Parche Leyenda',      '🏆', NULL, 'Visitá 25 lugares');

COMMIT;
