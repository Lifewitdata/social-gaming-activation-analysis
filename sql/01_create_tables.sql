-- Dedicated project schema. Re-running replaces ONLY this project's schema.
DROP SCHEMA IF EXISTS gaming_activation CASCADE;
CREATE SCHEMA gaming_activation;
SET search_path TO gaming_activation;
SET TIME ZONE 'UTC';
CREATE TABLE analysis_config (observation_end timestamptz NOT NULL);
INSERT INTO analysis_config VALUES ('2026-04-01T00:00:00Z');
CREATE TABLE users (
 user_id text PRIMARY KEY, signup_at timestamptz NOT NULL,
 acquisition_channel text NOT NULL, device_tier text NOT NULL, signup_app_version text NOT NULL
);
CREATE TABLE sessions (
 session_id text PRIMARY KEY, user_id text NOT NULL REFERENCES users,
 session_start timestamptz NOT NULL, session_end timestamptz NOT NULL,
 app_version text NOT NULL, network_type text NOT NULL,
 CHECK (session_end>=session_start)
);
CREATE TABLE matchmaking_attempts (
 attempt_id text PRIMARY KEY, user_id text NOT NULL REFERENCES users,
 session_id text NOT NULL REFERENCES sessions, queue_entered_at timestamptz NOT NULL,
 queue_exited_at timestamptz, outcome text NOT NULL CHECK (outcome IN ('joined','failed','abandoned','pending')),
 failure_reason text, game_id text,
 CHECK (queue_exited_at>=queue_entered_at),
 CHECK ((outcome='pending')=(queue_exited_at IS NULL))
);
CREATE TABLE game_participation (
 game_id text NOT NULL, user_id text NOT NULL REFERENCES users,
 session_id text NOT NULL REFERENCES sessions, attempt_id text NOT NULL REFERENCES matchmaking_attempts,
 joined_at timestamptz NOT NULL, started_at timestamptz, ended_at timestamptz,
 completion_status text NOT NULL CHECK (completion_status IN ('not_started','in_progress','completed','exited')),
 PRIMARY KEY(game_id,user_id), CHECK(started_at>=joined_at), CHECK(ended_at>=started_at)
);
CREATE TABLE events (
 event_id text PRIMARY KEY, user_id text NOT NULL REFERENCES users,
 session_id text NOT NULL REFERENCES sessions, event_name text NOT NULL,
 event_timestamp timestamptz NOT NULL, attempt_id text REFERENCES matchmaking_attempts,
 game_id text, FOREIGN KEY(game_id,user_id) REFERENCES game_participation(game_id,user_id)
);
CREATE INDEX events_user_time ON events(user_id,event_timestamp);
CREATE INDEX events_game_stage ON events(user_id,game_id,event_name,event_timestamp);
CREATE INDEX attempts_user_time ON matchmaking_attempts(user_id,queue_entered_at);
CREATE INDEX sessions_user_time ON sessions(user_id,session_start);
