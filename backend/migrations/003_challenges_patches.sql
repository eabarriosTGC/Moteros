-- 003_challenges_patches.sql
-- New tables for challenges and patches features

-- Challenges catalog
CREATE TABLE IF NOT EXISTS challenges (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    icon        VARCHAR(50) DEFAULT '🏁',
    ruta        VARCHAR(255),
    sort_order  INT DEFAULT 0
);

-- User challenges progress
CREATE TABLE IF NOT EXISTS user_challenges (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id INT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    completed   BOOLEAN DEFAULT FALSE,
    submitted_at TIMESTAMPTZ,
    UNIQUE(user_id, challenge_id)
);

-- Patches catalog
CREATE TABLE IF NOT EXISTS patches (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    icon        VARCHAR(50) DEFAULT '🏍️',
    place       VARCHAR(255),
    requirement TEXT
);

-- User patches collection
CREATE TABLE IF NOT EXISTS user_patches (
    id          SERIAL PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    patch_id    INT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
    earned      BOOLEAN DEFAULT FALSE,
    earned_at   TIMESTAMPTZ,
    UNIQUE(user_id, patch_id)
);

-- Seed challenges
INSERT INTO challenges (title, description, icon, ruta, sort_order) VALUES
('Ruta de la Sabana', 'Visita 2 pueblos de la Sabana de Bogotá en un día', '🏞️', 'Bogotá → Chía → Cajicá → Tabio → Neusa', 1),
('Curvas del Alto del Vino', 'Llega al mirador del Alto del Vino y tómate una foto con tu moto', '🏔️', 'Bogotá → Alto del Vino → La Vega', 2),
('El Reto del Páramo', 'Sube hasta el Parque Nacional Chingaza en moto', '❄️', 'Bogotá → La Calera → Chingaza', 3),
('Ruta Colonial', 'Viaja a Villa de Leyva y visita la Plaza Mayor', '🏛️', 'Bogotá → Tunja → Villa de Leyva', 4),
('La Cascada Oculta', 'Encuentra la Cascada La Chorrera en Choachí', '🌊', 'Bogotá → Choachí → La Chorrera', 5),
('Ruta Termal', 'Llega a las termales de Paipa y relájate', '♨️', 'Bogotá → Tunja → Paipa', 6),
('El Embalse', 'Rodea el Embalse del Neusa en moto', '🌅', 'Bogotá → Zipaquirá → Neusa', 7),
('Noche en la Posada', 'Pasa una noche en una Moto Posada del club', '🏠', 'Cualquier Moto Posada afiliada', 8),
('Soporte en Ruta', 'Ayuda a otro motero varado en carretera', '🤝', 'En cualquier ruta', 9),
('Corona de los Andes', 'Completa todas las rutas del club', '👑', 'Todas las rutas', 10)
ON CONFLICT DO NOTHING;

-- Seed patches
INSERT INTO patches (name, icon, place, requirement) VALUES
('Sabana Explorer', '🏞️', 'Sabana de Bogotá', 'Completa la Ruta de la Sabana'),
('Alto del Vino', '🏔️', 'Alto del Vino', 'Llega al mirador del Alto del Vino'),
('Páramo Rider', '❄️', 'Chingaza', 'Sube al Parque Chingaza'),
('Colonial Master', '🏛️', 'Villa de Leyva', 'Viaja a Villa de Leyva'),
('Cascada Legend', '🌊', 'La Chorrera', 'Encuentra la Cascada La Chorrera'),
('Termal King', '♨️', 'Paipa', 'Llega a las termales de Paipa'),
('Embalse Hero', '🌅', 'Embalse del Neusa', 'Rodea el Embalse del Neusa'),
('Moto Posada', '🏠', 'Red de Refugios', 'Pasa la noche en una Moto Posada'),
('Ángel Guardián', '🤝', 'Carreteras', 'Ayuda a otro motero en ruta'),
('Rey de la Ruta', '👑', 'Todas las rutas', 'Completa todos los parches')
ON CONFLICT DO NOTHING;
