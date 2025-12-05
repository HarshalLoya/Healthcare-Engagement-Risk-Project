WITH events_30d AS (
    SELECT e.user_id,
        e.event_type,
        MIN(e."timestamp") AS first_ts
    FROM events e
        JOIN users u ON u.user_id = e.user_id
        AND e."timestamp" >= u.signup_date::timestamp
        AND e."timestamp" < (u.signup_date::timestamp + INTERVAL '30 days')
    GROUP BY 1,
        2
),
per_user AS (
    SELECT u.user_id,
        MIN(first_ts) FILTER (
            WHERE event_type = 'login'
        ) AS first_login_ts,
        MIN(first_ts) FILTER (
            WHERE event_type = 'connect_device'
        ) AS first_connect_ts,
        MIN(first_ts) FILTER (
            WHERE event_type = 'submit_reading'
        ) AS first_reading_ts,
        MIN(first_ts) FILTER (
            WHERE event_type = 'care_team_contact'
        ) AS first_care_ts
    FROM users u
        LEFT JOIN events_30d e30 ON e30.user_id = u.user_id
    GROUP BY 1
),
flags AS (
    SELECT user_id,
        (first_login_ts IS NOT NULL) AS has_login,
        (first_connect_ts IS NOT NULL) AS has_connect,
        (first_reading_ts IS NOT NULL) AS has_reading,
        (first_care_ts IS NOT NULL) AS has_care
    FROM per_user
),
counts AS (
    SELECT COUNT(*) AS signup_users,
        -- "Reached step" counts (not enforcing order)
        COUNT(*) FILTER (
            WHERE has_login
        ) AS reached_login,
        COUNT(*) FILTER (
            WHERE has_connect
        ) AS reached_connect,
        COUNT(*) FILTER (
            WHERE has_reading
        ) AS reached_reading,
        COUNT(*) FILTER (
            WHERE has_care
        ) AS reached_care,
        -- Ordered/cumulative funnel counts
        COUNT(*) FILTER (
            WHERE has_login
        ) AS funnel_login,
        COUNT(*) FILTER (
            WHERE has_login
                AND has_connect
        ) AS funnel_connect,
        COUNT(*) FILTER (
            WHERE has_login
                AND has_connect
                AND has_reading
        ) AS funnel_reading,
        COUNT(*) FILTER (
            WHERE has_login
                AND has_connect
                AND has_reading
                AND has_care
        ) AS funnel_care
    FROM flags
)
SELECT signup_users,
    reached_login,
    reached_connect,
    reached_reading,
    reached_care,
    funnel_login,
    funnel_connect,
    funnel_reading,
    funnel_care,
    -- conversion rates (ordered funnel)
    ROUND(
        funnel_login::numeric / NULLIF(signup_users, 0),
        4
    ) AS conv_signup_to_login,
    ROUND(
        funnel_connect::numeric / NULLIF(funnel_login, 0),
        4
    ) AS conv_login_to_connect,
    ROUND(
        funnel_reading::numeric / NULLIF(funnel_connect, 0),
        4
    ) AS conv_connect_to_reading,
    ROUND(
        funnel_care::numeric / NULLIF(funnel_reading, 0),
        4
    ) AS conv_reading_to_care,
    ROUND(
        funnel_care::numeric / NULLIF(signup_users, 0),
        4
    ) AS conv_signup_to_care
FROM counts;