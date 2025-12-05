BEGIN;

DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    signup_date DATE NOT NULL,
    age INT NOT NULL CHECK (
        age BETWEEN 0 AND 120
    ),
    gender TEXT NOT NULL,
    location TEXT NOT NULL,
    location_type TEXT NOT NULL CHECK (location_type IN ('urban', 'rural')),
    device_type TEXT NOT NULL CHECK (device_type IN ('iOS', 'Android', 'Web')),
    device_os_version TEXT NOT NULL,
    baseline_severity INT NOT NULL CHECK (
        baseline_severity BETWEEN 1 AND 5
    ),
    treatment_plan TEXT NOT NULL CHECK (
        treatment_plan IN (
            'lifestyle_only',
            'oral_medication',
            'combo',
            'insulin'
        )
    ),
    adherence_flag INT NOT NULL CHECK (adherence_flag IN (0, 1)),
    first_contact_time TIMESTAMP NULL,
    dropoff INT NOT NULL CHECK (dropoff IN (0, 1))
);

CREATE TABLE events (
    event_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'login',
            'view_tutorial',
            'connect_device',
            'submit_reading',
            'care_team_contact'
        )
    ),
    "timestamp" TIMESTAMP NOT NULL,
    device_type TEXT NOT NULL CHECK (device_type IN ('iOS', 'Android', 'Web')),
    device_os_version TEXT NOT NULL
);

-- Indexes for join + funnel + cohort queries
CREATE INDEX idx_events_user_id ON events(user_id);
CREATE INDEX idx_events_event_type ON events(event_type);
CREATE INDEX idx_events_timestamp ON events("timestamp");
CREATE INDEX idx_events_user_event_time ON events(user_id, event_type, "timestamp");
COMMIT;