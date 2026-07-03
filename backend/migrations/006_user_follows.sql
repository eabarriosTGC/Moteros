-- 006_user_follows.sql
CREATE TABLE IF NOT EXISTS user_follows (
    id          SERIAL PRIMARY KEY,
    follower_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, followed_id),
    CHECK (follower_id != followed_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed ON user_follows(followed_id);
