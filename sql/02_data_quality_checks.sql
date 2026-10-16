-- Return a violation count per invariant; every count must be zero after cleaning.
SET search_path TO gaming_activation;
CREATE OR REPLACE VIEW dq_checks AS
SELECT 'event_before_signup' AS check_name, count(*) AS violations FROM events e JOIN users u USING(user_id) WHERE e.event_timestamp<u.signup_at
UNION ALL SELECT 'event_outside_observation',count(*) FROM events,analysis_config WHERE event_timestamp>=observation_end
UNION ALL SELECT 'event_session_owner',count(*) FROM events e JOIN sessions s USING(session_id) WHERE e.user_id<>s.user_id
UNION ALL SELECT 'event_outside_session',count(*) FROM events e JOIN sessions s USING(session_id) WHERE e.event_timestamp<s.session_start OR e.event_timestamp>s.session_end
UNION ALL SELECT 'attempt_session_owner',count(*) FROM matchmaking_attempts a JOIN sessions s USING(session_id) WHERE a.user_id<>s.user_id
UNION ALL SELECT 'game_attempt_mismatch',count(*) FROM game_participation g JOIN matchmaking_attempts a USING(attempt_id) WHERE g.user_id<>a.user_id OR g.game_id IS DISTINCT FROM a.game_id
UNION ALL SELECT 'event_attempt_owner',count(*) FROM events e JOIN matchmaking_attempts a USING(attempt_id) WHERE e.user_id<>a.user_id
UNION ALL SELECT 'completed_game_missing_event',count(*) FROM game_participation g WHERE completion_status='completed' AND NOT EXISTS(SELECT 1 FROM events e WHERE e.user_id=g.user_id AND e.game_id=g.game_id AND e.event_name='game_completed' AND e.event_timestamp=g.ended_at)
UNION ALL SELECT 'invalid_game_event_order',count(*) FROM events c WHERE c.event_name='game_completed' AND NOT EXISTS(SELECT 1 FROM events s JOIN events j ON j.user_id=s.user_id AND j.game_id=s.game_id WHERE s.user_id=c.user_id AND s.game_id=c.game_id AND s.event_name='game_started' AND j.event_name='game_joined' AND j.event_timestamp<=s.event_timestamp AND s.event_timestamp<=c.event_timestamp)
UNION ALL SELECT 'missing_signup_event',count(*) FROM users u WHERE NOT EXISTS(SELECT 1 FROM events e WHERE e.user_id=u.user_id AND e.event_name='sign_up' AND e.event_timestamp=u.signup_at);
SELECT * FROM dq_checks ORDER BY check_name;
