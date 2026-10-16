SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW activation_timing AS
SELECT acquisition_channel,count(*) AS activated_users,
 percentile_cont(.5) WITHIN GROUP(ORDER BY time_to_activation_minutes) AS median_minutes,
 percentile_cont(.9) WITHIN GROUP(ORDER BY time_to_activation_minutes) AS p90_minutes,
 avg(time_to_activation_minutes) AS mean_minutes
FROM user_activation WHERE activation_eligible AND activated GROUP BY 1;
-- Cumulative incidence among ALL eligible registrations: avoids survivor-only interpretation.
CREATE OR REPLACE VIEW activation_horizons AS
SELECT h.minutes,count(*) AS eligible_users,
 count(*) FILTER(WHERE activated AND time_to_activation_minutes<h.minutes) AS activated_by_horizon,
 avg((activated AND time_to_activation_minutes<h.minutes)::int) AS activation_rate
FROM user_activation CROSS JOIN (VALUES(15),(60),(360),(1440)) h(minutes)
WHERE activation_eligible GROUP BY h.minutes;
SELECT * FROM activation_timing ORDER BY acquisition_channel;
