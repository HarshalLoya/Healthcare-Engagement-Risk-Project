WITH care_first AS (
    SELECT e.user_id,
        MIN(e."timestamp") AS first_care_ts
    FROM events e
    WHERE e.event_type = 'care_team_contact'
    GROUP BY 1
),
labels AS (
    SELECT u.*,
        c.first_care_ts,
        CASE
            WHEN c.first_care_ts IS NULL THEN 1
            WHEN c.first_care_ts >= (u.signup_date::timestamp + INTERVAL '30 days') THEN 1
            ELSE 0
        END AS dropoff_recomputed
    FROM users u
        LEFT JOIN care_first c ON c.user_id = u.user_id
) -- 1) label agreement summary
SELECT COUNT(*) AS users_total,
    SUM(
        CASE
            WHEN dropoff = dropoff_recomputed THEN 1
            ELSE 0
        END
    ) AS label_matches,
    ROUND(
        AVG(
            CASE
                WHEN dropoff = dropoff_recomputed THEN 1
                ELSE 0
            END
        )::numeric,
        4
    ) AS match_rate
FROM labels;
-- 2) dropoff rate by key segments (run this block separately if your SQL client doesn't allow multi statements)
-- SELECT
--   baseline_severity,
--   treatment_plan,
--   location_type,
--   device_type,
--   COUNT(*) AS users,
--   ROUND(AVG(dropoff_recomputed)::numeric, 4) AS dropoff_rate
-- FROM labels
-- GROUP BY 1,2,3,4
-- ORDER BY dropoff_rate DESC, users DESC;