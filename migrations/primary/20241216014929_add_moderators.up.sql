-- moderators

CREATE TABLE fieldkit.moderators (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_moderators_user_id ON fieldkit.moderators(user_id);
