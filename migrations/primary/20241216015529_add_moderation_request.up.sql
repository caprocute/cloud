-- moderation_request

CREATE TABLE moderation_request (
    id SERIAL PRIMARY KEY,
    post_id INT NOT NULL,
    post_type VARCHAR(50) NOT NULL, -- "discussion_post" or "data_event"
    reported_by INT NOT NULL,
    acknowledged_by INT NULL,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMP NULL
);

CREATE INDEX idx_moderation_request_post ON moderation_request(post_id, post_type);

ALTER TABLE moderation_request
ADD CONSTRAINT fk_moderation_request_reported_by FOREIGN KEY (reported_by) REFERENCES "user"(id) ON DELETE CASCADE;

ALTER TABLE moderation_request
ADD CONSTRAINT fk_moderation_request_acknowledged_by FOREIGN KEY (acknowledged_by) REFERENCES "user"(id) ON DELETE SET NULL;
