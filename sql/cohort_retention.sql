WITH user_cohorts AS (
    SELECT user_id,
        DATE_TRUNC('week', signup_date)::date AS signup_week,
        signup_date
    FROM users
),
event_weeks AS (
    SELECT u.signup_week,
        e.user_id,
        -- week_index = 0 means "signup week", 1 means "week after signup week", etc.
        ((e."timestamp"::date - u.signup_date)::int / 7) AS week_index
    FROM events e
        JOIN user_cohorts u ON u.user_id = e.user_id
    WHERE e."timestamp"::date >= u.signup_date
        AND e."timestamp"::date < (u.signup_date + INTERVAL '90 days')::date
),
cohort_sizes AS (
    SELECT signup_week,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY 1
),
active_by_week AS (
    SELECT signup_week,
        week_index,
        COUNT(DISTINCT user_id) AS active_users
    FROM event_weeks
    WHERE week_index >= 0
    GROUP BY 1,
        2
)
SELECT a.signup_week,
    a.week_index,
    a.active_users,
    c.cohort_size,
    ROUND(
        a.active_users::numeric / NULLIF(c.cohort_size, 0),
        4
    ) AS retention_rate
FROM active_by_week a
    JOIN cohort_sizes c USING (signup_week)
ORDER BY a.signup_week,
    a.week_index;