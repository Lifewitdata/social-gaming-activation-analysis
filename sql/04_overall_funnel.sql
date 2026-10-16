SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW overall_funnel AS
WITH counts AS (
 SELECT n.stage_order,n.stage,count(*) FILTER(WHERE a.furthest_stage>=n.stage_order) AS users
 FROM user_activation a CROSS JOIN (VALUES(1,'Sign-up'),(2,'Onboarding completed'),(3,'Lobby viewed'),(4,'Game joined'),(5,'Game started'),(6,'Game completed')) n(stage_order,stage)
 WHERE activation_eligible GROUP BY n.stage_order,n.stage
), lagged AS (
 SELECT *,lag(users) OVER(ORDER BY stage_order) AS previous_users,first_value(users) OVER(ORDER BY stage_order) AS registered_users FROM counts
)
SELECT *,users::numeric/nullif(previous_users,0) AS step_conversion,
 1-users::numeric/nullif(previous_users,0) AS step_dropoff,
 previous_users-users AS lost_users,users::numeric/nullif(registered_users,0) AS cumulative_conversion
FROM lagged;
CREATE OR REPLACE VIEW weekly_activation AS
SELECT date_trunc('week',signup_at AT TIME ZONE 'UTC')::date AS signup_week,
 count(*) AS eligible_users,count(*) FILTER(WHERE activated) AS activated_users,
 avg(activated::int) AS activation_rate
FROM user_activation WHERE activation_eligible GROUP BY 1;
SELECT * FROM overall_funnel ORDER BY stage_order;
