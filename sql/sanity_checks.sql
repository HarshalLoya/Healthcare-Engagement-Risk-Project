\set ON_ERROR_STOP on 

\echo '--- Row counts ---'
SELECT COUNT(*) AS users
FROM users;
SELECT COUNT(*) AS events
FROM events;

\echo '--- Stored dropoff rate (users.dropoff) ---'
SELECT ROUND(AVG(dropoff)::numeric, 4) AS dropoff_rate
FROM users;

\echo '--- Recomputed dropoff rate from events (care_team_contact within 30d) ---' 
WITH first_care AS (
    SELECT user_id,
        MIN("timestamp") AS first_care_ts
    FROM events
    WHERE event_type = 'care_team_contact'
    GROUP BY 1
),
labeled AS (
    SELECT u.user_id,
        CASE
            WHEN fc.first_care_ts IS NULL THEN 1
            WHEN fc.first_care_ts >= (u.signup_date::timestamp + INTERVAL '30 days') THEN 1
            ELSE 0
        END AS dropoff_recomputed
    FROM users u
        LEFT JOIN first_care fc USING (user_id)
)
SELECT ROUND(AVG(dropoff_recomputed)::numeric, 4) AS dropoff_rate_recomputed
FROM labeled;

\echo '--- Events per user summary ---' 
WITH per_user AS (
    SELECT user_id,
        COUNT(*) AS evt_cnt
    FROM events
    GROUP BY 1
)
SELECT ROUND(AVG(evt_cnt)::numeric, 2) AS avg_events_per_user,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY evt_cnt
    ) AS median_events_per_user,
    MAX(evt_cnt) AS max_events_per_user
FROM per_user;