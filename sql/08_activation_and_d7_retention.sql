SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW retention_comparison AS
SELECT activated,count(*) AS eligible_users,sum(d7_returned::int) AS returning_users,
 avg(d7_returned::int) AS d7_retention FROM user_activation
WHERE activation_eligible AND d7_eligible GROUP BY activated;
CREATE OR REPLACE VIEW retention_cohorts AS
SELECT date_trunc('week',signup_at AT TIME ZONE 'UTC')::date AS signup_week,
 activated,count(*) AS eligible_users,sum(d7_returned::int) AS returning_users,
 avg(d7_returned::int) AS d7_retention FROM user_activation
WHERE activation_eligible AND d7_eligible GROUP BY 1,2;
CREATE OR REPLACE VIEW retention_segments AS
SELECT acquisition_channel,device_tier,activated,count(*) AS eligible_users,
 sum(d7_returned::int) AS returning_users,avg(d7_returned::int) AS d7_retention
FROM user_activation WHERE activation_eligible AND d7_eligible GROUP BY 1,2,3;
SELECT * FROM retention_comparison ORDER BY activated;
