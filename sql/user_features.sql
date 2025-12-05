DROP VIEW IF EXISTS mart_user_features;

CREATE VIEW mart_user_features AS WITH events_7d AS (
    SELECT e.user_id,
        e.event_type,
        e."timestamp",
        DATE_TRUNC('day', e."timestamp")::date AS event_date
    FROM events e
        JOIN users u ON u.user_id = e.user_id
    WHERE e."timestamp" >= u.signup_date::timestamp
        AND e."timestamp" < (u.signup_date::timestamp + INTERVAL '7 days')
),
agg AS (
    SELECT u.user_id,
        -- counts by type in first 7 days
        COUNT(*) AS events_7d_total,
        COUNT(*) FILTER (
            WHERE e.event_type = 'login'
        ) AS events_7d_login,
        COUNT(*) FILTER (
            WHERE e.event_type = 'connect_device'
        ) AS events_7d_connect,
        COUNT(*) FILTER (
            WHERE e.event_type = 'submit_reading'
        ) AS events_7d_reading,
        COUNT(*) FILTER (
            WHERE e.event_type = 'care_team_contact'
        ) AS events_7d_care,
        COUNT(DISTINCT e.event_date) AS active_days_7d,
        MIN(e."timestamp") FILTER (
            WHERE e.event_type = 'login'
        ) AS first_login_ts_7d
    FROM users u
        LEFT JOIN events_7d e ON e.user_id = u.user_id
    GROUP BY u.user_id
),
features AS (
    SELECT u.user_id,
        -- target
        u.dropoff AS label_dropoff,
        -- demographics & static attributes
        u.signup_date,
        u.age,
        u.gender,
        u.location,
        u.location_type,
        u.device_type,
        u.device_os_version,
        u.baseline_severity,
        u.treatment_plan,
        u.adherence_flag,
        -- behavior features
        COALESCE(a.events_7d_total, 0) AS events_7d_total,
        COALESCE(a.events_7d_login, 0) AS events_7d_login,
        COALESCE(a.events_7d_connect, 0) AS events_7d_connect,
        COALESCE(a.events_7d_reading, 0) AS events_7d_reading,
        COALESCE(a.events_7d_care, 0) AS events_7d_care,
        COALESCE(a.active_days_7d, 0) AS active_days_7d,
        -- binary flags
        (COALESCE(a.events_7d_login, 0) > 0)::int AS has_login_7d,
        (COALESCE(a.events_7d_connect, 0) > 0)::int AS has_connect_7d,
        (COALESCE(a.events_7d_reading, 0) > 0)::int AS has_reading_7d,
        (COALESCE(a.events_7d_care, 0) > 0)::int AS has_care_7d,
        -- time-to-first-login in days (within 7 days)
        CASE
            WHEN a.first_login_ts_7d IS NULL THEN NULL
            ELSE EXTRACT(
                EPOCH
                FROM (a.first_login_ts_7d - u.signup_date::timestamp)
            ) / 86400.0
        END AS ttf_login_days_7d
    FROM users u
        LEFT JOIN agg a ON a.user_id = u.user_id
)
SELECT *
FROM features;