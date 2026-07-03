-- 005_routes_alerts.sql
-- Route tracking + community road alerts

CREATE TABLE IF NOT EXISTS saved_routes (
    id              SERIAL PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(255),
    total_distance_m DOUBLE PRECISION DEFAULT 0,
    duration_seconds INT DEFAULT 0,
    avg_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    max_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    points_count    INT DEFAULT 0,
    polyline_json   TEXT,  -- JSON array of [lat, lng] points
    start_lat       DOUBLE PRECISION,
    start_lng       DOUBLE PRECISION,
    end_lat         DOUBLE PRECISION,
    end_lng         DOUBLE PRECISION,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS road_alerts (
    id              SERIAL PRIMARY KEY,
    user_id         INT REFERENCES users(id) ON DELETE SET NULL,
    type            VARCHAR(50) NOT NULL,  -- closure, accident, police, hazard, weather
    title           VARCHAR(255),
    description     TEXT,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    severity        VARCHAR(20) DEFAULT 'info',  -- info, warning, danger
    active          BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    upvotes         INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_saved_routes_user ON saved_routes(user_id);
CREATE INDEX IF NOT EXISTS idx_road_alerts_location ON road_alerts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_road_alerts_active ON road_alerts(active);
