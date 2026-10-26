-- Synthetic SQL-level boundary/abuse tests. No real content or online tracking.
\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
  RAISE NOTICE 'PASS: %', label;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION pg_temp.reject_rating(command text, label text) RETURNS void AS $$
BEGIN
  BEGIN
    EXECUTE command;
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'PASS: %', label;
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL: %', label;
END;
$$ LANGUAGE plpgsql;

INSERT INTO users (id,email,password_hash,birthdate,signup_source) VALUES
 ('00000000-0000-4000-8000-000000000001','rating-a@example.test','test-only','1990-01-01','synthetic_demo'),
 ('00000000-0000-4000-8000-000000000002','rating-b@example.test','test-only','1990-01-01','synthetic_demo'),
 ('00000000-0000-4000-8000-000000000003','rating-c@example.test','test-only','1990-01-01','synthetic_demo');
INSERT INTO chat_threads (id,participant_low,participant_high,created_at) VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',now()-interval '1 day');
INSERT INTO thread_participants(thread_id,user_id) VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002');
CREATE FUNCTION pg_temp.eligible() RETURNS boolean LANGUAGE sql AS $$
 SELECT rating_chat_eligible('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002');
$$;
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'old open thread without messages does not qualify');
SELECT pg_temp.reject_rating($q$INSERT INTO profile_ratings(rater_id,ratee_id,stars) VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',5)$q$, 'direct rating write cannot bypass chat gate');
INSERT INTO chat_messages(thread_id,sender_id,client_message_id,body,created_at) VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','one','Hello',now()-interval '10 minutes'),
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','two','Hello again',now()-interval '5 minutes');
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'one-sided messages spanning five minutes do not qualify');
INSERT INTO chat_messages(thread_id,sender_id,client_message_id,body,created_at) VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003','outsider','Synthetic outsider',now());
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'third-party message cannot supply the missing participant');
DELETE FROM chat_messages WHERE client_message_id='outsider';
UPDATE chat_messages SET sender_id = '00000000-0000-4000-8000-000000000002', created_at=now()-interval '301 seconds' WHERE client_message_id='two';
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'mutual exchange spanning 299 seconds stays locked despite idle time');
UPDATE chat_messages SET created_at=now()-interval '300 seconds' WHERE client_message_id='two';
SELECT pg_temp.assert_true(pg_temp.eligible(), 'mutual exchange spanning exactly 300 seconds qualifies');
SELECT pg_temp.assert_true(rating_chat_eligible('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001'), 'eligibility works in both directions');
UPDATE chat_messages SET created_at=now()-interval '299 seconds' WHERE client_message_id='two';
SELECT pg_temp.assert_true(pg_temp.eligible(), 'mutual exchange spanning 301 seconds qualifies');
SELECT pg_temp.assert_true(NOT rating_chat_eligible('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003'), 'unrelated pair cannot borrow another conversation');
SELECT pg_temp.assert_true(NOT rating_chat_eligible('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001'), 'self rating is never eligible');
UPDATE chat_messages SET created_at=now()+interval '1 minute' WHERE client_message_id='two';
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'future timestamp is not eligibility evidence');
UPDATE chat_messages SET created_at=now()-interval '300 seconds' WHERE client_message_id='two';
DELETE FROM thread_participants WHERE user_id='00000000-0000-4000-8000-000000000002';
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'missing participant membership prevents eligibility');
INSERT INTO thread_participants(thread_id,user_id) VALUES ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002');
INSERT INTO profile_ratings(rater_id,ratee_id,stars) VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',1);
INSERT INTO profile_ratings(rater_id,ratee_id,stars) VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',5)
 ON CONFLICT (rater_id,ratee_id) DO UPDATE SET stars=EXCLUDED.stars;
SELECT pg_temp.assert_true((SELECT count(*)=1 AND max(stars)=5 FROM profile_ratings), 're-rating replaces the existing vote');
SELECT pg_temp.reject_rating('UPDATE profile_ratings SET stars=0', 'zero stars rejected');
SELECT pg_temp.reject_rating('UPDATE profile_ratings SET stars=6', 'six stars rejected');
INSERT INTO blocks(blocker_id,blocked_id) VALUES ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001');
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'reverse-direction block revokes eligibility');
SELECT pg_temp.reject_rating('UPDATE profile_ratings SET stars=2', 'blocked re-rating rejected at database layer');
UPDATE blocks SET blocker_id='00000000-0000-4000-8000-000000000001',blocked_id='00000000-0000-4000-8000-000000000002';
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'forward-direction block revokes eligibility');
DELETE FROM blocks;
UPDATE users SET status='suspended' WHERE id='00000000-0000-4000-8000-000000000001';
SELECT pg_temp.reject_rating('UPDATE profile_ratings SET stars=2', 'suspended rater cannot re-rate');
UPDATE users SET status='active' WHERE id='00000000-0000-4000-8000-000000000001';
UPDATE users SET status='banned' WHERE id='00000000-0000-4000-8000-000000000002';
SELECT pg_temp.reject_rating('UPDATE profile_ratings SET stars=2', 'banned recipient cannot be rated');
UPDATE users SET status='deleted' WHERE id='00000000-0000-4000-8000-000000000002';
SELECT pg_temp.assert_true(NOT pg_temp.eligible(), 'deleted recipient is ineligible');
ROLLBACK;
