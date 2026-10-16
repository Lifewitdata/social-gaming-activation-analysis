SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW first_day_attempts AS
SELECT a.*,s.app_version,s.network_type,u.device_tier,u.acquisition_channel,
 extract(epoch FROM queue_exited_at-queue_entered_at) AS wait_seconds,
 row_number() OVER(PARTITION BY a.user_id ORDER BY queue_entered_at,attempt_id) AS attempt_number,
 CASE WHEN queue_exited_at IS NULL THEN 'Pending'
 WHEN extract(epoch FROM queue_exited_at-queue_entered_at)<15 THEN '01. <15s'
 WHEN extract(epoch FROM queue_exited_at-queue_entered_at)<30 THEN '02. 15-29s'
 WHEN extract(epoch FROM queue_exited_at-queue_entered_at)<60 THEN '03. 30-59s'
 ELSE '04. 60s+' END AS wait_band
FROM matchmaking_attempts a JOIN user_activation u USING(user_id) JOIN sessions s USING(session_id)
WHERE u.activation_eligible AND queue_entered_at>=u.signup_at AND queue_entered_at<u.signup_at+interval '24 hours';
CREATE OR REPLACE VIEW matchmaking_summary AS
SELECT app_version,device_tier,network_type,count(*) AS attempts,count(DISTINCT user_id) AS users,
 count(*) FILTER(WHERE outcome='joined') AS joined_attempts,
 count(*) FILTER(WHERE outcome='failed') AS failed_attempts,
 count(*) FILTER(WHERE outcome='abandoned') AS abandoned_attempts,
 avg((outcome='failed')::int) AS failure_rate,
 avg((outcome='abandoned')::int) AS abandonment_rate,
 percentile_cont(.5) WITHIN GROUP(ORDER BY wait_seconds) AS median_wait_seconds
FROM first_day_attempts GROUP BY 1,2,3;
CREATE OR REPLACE VIEW wait_outcomes AS
SELECT wait_band,count(*) AS attempts,count(DISTINCT user_id) AS users,
 avg((outcome='joined')::int) AS join_rate,avg((outcome='abandoned')::int) AS abandonment_rate,
 avg((outcome='failed')::int) AS failure_rate FROM first_day_attempts GROUP BY 1;
CREATE OR REPLACE VIEW retry_recovery AS
SELECT a.outcome AS first_outcome,count(*) AS users,
 count(*) FILTER(WHERE u.attempts_24h>1) AS retry_users,
 count(*) FILTER(WHERE u.activated) AS activated_users,
 avg(u.activated::int) AS activation_rate
FROM first_day_attempts a JOIN user_activation u USING(user_id) WHERE attempt_number=1 GROUP BY 1;
SELECT * FROM matchmaking_summary ORDER BY attempts DESC;
