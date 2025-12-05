WITH care_first AS (
    SELECT e.user_id,
        MIN(e."timestamp") AS first_care_ts
    FROM events e
    WHERE e.event_type = 'care_team_contact'
    GROUP BY 1
),
recomputed AS (
    SELECT u.user_id,
        CASE
            WHEN c.first_care_ts IS NULL THEN 1
            WHEN c.first_care_ts >= (u.signup_date::timestamp + INTERVAL '30 days') THEN 1
            ELSE 0
        END AS dropoff_new
    FROM users u
        LEFT JOIN care_first c ON c.user_id = u.user_id
)
UPDATE users u
SET dropoff = r.dropoff_new
FROM recomputed r
WHERE u.user_id = r.user_id;