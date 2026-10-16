SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW segment_funnels AS
WITH expanded AS (
 SELECT a.*,x.dimension,x.segment FROM user_activation a
 CROSS JOIN LATERAL (VALUES('channel',a.acquisition_channel),('device',a.device_tier),('version',a.signup_app_version),('version_device',a.signup_app_version||' / '||a.device_tier)) x(dimension,segment)
 WHERE activation_eligible
), agg AS (
 SELECT dimension,segment,count(*) AS eligible_users,
 count(*) FILTER(WHERE furthest_stage>=2) AS onboarded_users,
 count(*) FILTER(WHERE furthest_stage>=3) AS lobby_users,
 count(*) FILTER(WHERE furthest_stage>=4) AS joined_users,
 count(*) FILTER(WHERE furthest_stage>=5) AS started_users,
 count(*) FILTER(WHERE activated) AS activated_users
 FROM expanded GROUP BY dimension,segment
)
SELECT *,activated_users::numeric/eligible_users AS activation_rate,
 joined_users::numeric/nullif(lobby_users,0) AS lobby_to_join_rate,
 activated_users::numeric/nullif(started_users,0) AS start_to_complete_rate,
 eligible_users>=100 AS meets_reporting_threshold FROM agg;
-- Comparable-period table: both versions within weeks, devices, and channels.
CREATE OR REPLACE VIEW version_strata AS
SELECT date_trunc('week',signup_at AT TIME ZONE 'UTC')::date AS signup_week,
 device_tier,acquisition_channel,signup_app_version,count(*) AS eligible_users,
 sum(activated::int) AS activated_users,avg(activated::int) AS activation_rate
FROM user_activation WHERE activation_eligible AND signup_at>='2026-02-15T00:00:00Z'
GROUP BY 1,2,3,4;
SELECT * FROM segment_funnels ORDER BY dimension,eligible_users DESC;
