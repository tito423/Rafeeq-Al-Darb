CREATE TABLE IF NOT EXISTS user_state (
    sub TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (sub, key)
);

CREATE TABLE IF NOT EXISTS user_counters (
    sub TEXT NOT NULL,
    key TEXT NOT NULL,
    event_id TEXT NOT NULL,
    increment_value INTEGER NOT NULL,
    PRIMARY KEY (sub, key, event_id)
);
