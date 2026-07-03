-- 004_evidence_photos.sql
-- Photo-based visit verification with GPS metadata

CREATE TABLE IF NOT EXISTS evidence_photos (
    id              SERIAL PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        INT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    accuracy_meters DOUBLE PRECISION,
    verified        BOOLEAN DEFAULT FALSE,
    distance_meters DOUBLE PRECISION,  -- calculated distance from place
    points_awarded  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Points and rewards tracking
CREATE TABLE IF NOT EXISTS user_points (
    id              SERIAL PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_points    INT DEFAULT 0,
    visits_count    INT DEFAULT 0,
    photos_count    INT DEFAULT 0,
    last_visit_at   TIMESTAMPTZ,
    UNIQUE(user_id)
);

-- Insert default points row for test user
INSERT INTO user_points (user_id, total_points) VALUES (1, 0)
ON CONFLICT (user_id) DO NOTHING;

-- Index for proximity queries
CREATE INDEX IF NOT EXISTS idx_evidence_photos_user ON evidence_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_evidence_photos_place ON evidence_photos(place_id);
