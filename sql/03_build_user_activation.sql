SET search_path TO gaming_activation;
SET TIME ZONE 'UTC';
DROP MATERIALIZED VIEW IF EXISTS user_activation CASCADE;
CREATE MATERIALIZED VIEW user_activation AS
WITH early AS (
 SELECT u.*,c.observation_end,
  u.signup_at+interval '24 hours'<=c.observation_end AS activation_eligible,
  (u.signup_at AT TIME ZONE 'UTC')::date+8 <= (c.observation_end AT TIME ZONE 'UTC')::date AS d7_eligible,
  o.onboarding_at,l.lobby_at
 FROM users u CROSS JOIN analysis_config c
 LEFT JOIN LATERAL (
  SELECT min(event_timestamp) AS onboarding_at FROM events
  WHERE user_id=u.user_id AND event_name='onboarding_completed'
   AND event_timestamp>=u.signup_at AND event_timestamp<u.signup_at+interval '24 hours'
 ) o ON true
 LEFT JOIN LATERAL (
  SELECT min(event_timestamp) AS lobby_at FROM events
  WHERE user_id=u.user_id AND event_name='lobby_viewed'
   AND event_timestamp>=o.onboarding_at AND event_timestamp<u.signup_at+interval '24 hours'
 ) l ON true
), game_paths AS (
 -- Every candidate is evaluated. The first joined game may fail while a retry succeeds.
 SELECT e.user_id,e.game_id,e.event_timestamp AS joined_at,
        s.started_at,c.completed_at
 FROM early u JOIN events e ON e.user_id=u.user_id
  AND e.event_name='game_joined' AND e.event_timestamp>=u.lobby_at
  AND e.event_timestamp<u.signup_at+interval '24 hours'
 LEFT JOIN LATERAL (
  SELECT min(event_timestamp) AS started_at FROM events
  WHERE user_id=e.user_id AND game_id=e.game_id AND event_name='game_started'
  AND event_timestamp>=e.event_timestamp AND event_timestamp<u.signup_at+interval '24 hours'
 ) s ON true
 LEFT JOIN LATERAL (
  SELECT min(event_timestamp) AS completed_at FROM events
  WHERE user_id=e.user_id AND game_id=e.game_id AND event_name='game_completed'
  AND event_timestamp>=s.started_at AND event_timestamp<u.signup_at+interval '24 hours'
 ) c ON true
), stages AS (
 SELECT user_id,min(joined_at) AS first_joined_at,min(started_at) AS first_started_at,
 min(completed_at) AS first_completed_at FROM game_paths GROUP BY user_id
)
SELECT u.*,s.first_joined_at,s.first_started_at,s.first_completed_at,
 s.first_completed_at IS NOT NULL AS activated,
 extract(epoch FROM s.first_completed_at-u.signup_at)/60.0 AS time_to_activation_minutes,
 CASE WHEN s.first_completed_at IS NOT NULL THEN 6 WHEN s.first_started_at IS NOT NULL THEN 5
 WHEN s.first_joined_at IS NOT NULL THEN 4 WHEN u.lobby_at IS NOT NULL THEN 3
 WHEN u.onboarding_at IS NOT NULL THEN 2 ELSE 1 END AS furthest_stage,
 first_attempt.outcome AS first_attempt_outcome,
 first_attempt.wait_seconds AS first_attempt_wait_seconds,
 first_attempt.network_type AS first_attempt_network,
 attempts.attempts_24h,attempts.attempts_before_activation,
 CASE WHEN u.d7_eligible THEN EXISTS (
  SELECT 1 FROM events e WHERE e.user_id=u.user_id
   AND e.event_name IN ('lobby_viewed','game_started','game_completed')
   AND e.event_timestamp>=(((u.signup_at AT TIME ZONE 'UTC')::date+7)::timestamp AT TIME ZONE 'UTC')
   AND e.event_timestamp<(((u.signup_at AT TIME ZONE 'UTC')::date+8)::timestamp AT TIME ZONE 'UTC')
 ) ELSE NULL END AS d7_returned
FROM early u LEFT JOIN stages s USING(user_id)
LEFT JOIN LATERAL (
 SELECT a.outcome,extract(epoch FROM a.queue_exited_at-a.queue_entered_at) AS wait_seconds,ss.network_type
 FROM matchmaking_attempts a JOIN sessions ss USING(session_id)
 WHERE a.user_id=u.user_id AND a.queue_entered_at>=u.signup_at AND a.queue_entered_at<u.signup_at+interval '24 hours'
 ORDER BY a.queue_entered_at,a.attempt_id LIMIT 1
) first_attempt ON true
LEFT JOIN LATERAL (
 SELECT count(*) AS attempts_24h,
 count(*) FILTER(WHERE a.queue_entered_at<=s.first_completed_at) AS attempts_before_activation
 FROM matchmaking_attempts a WHERE a.user_id=u.user_id
 AND a.queue_entered_at>=u.signup_at AND a.queue_entered_at<u.signup_at+interval '24 hours'
) attempts ON true;
CREATE UNIQUE INDEX user_activation_pk ON user_activation(user_id);
-- Stage timestamps are first valid reach per stage, not necessarily one common game.
-- Each candidate completed path above DOES require the same game_id for join/start/end.
SELECT count(*) AS users,count(*) FILTER(WHERE activation_eligible) AS eligible,
 count(*) FILTER(WHERE activation_eligible AND activated) AS activated FROM user_activation;
