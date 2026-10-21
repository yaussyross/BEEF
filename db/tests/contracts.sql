-- Isolated synthetic fixtures only. The runner creates a disposable database.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
  RAISE NOTICE 'PASS: %', label;
END;
$$ LANGUAGE plpgsql;

SELECT pg_temp.assert_true((SELECT count(*) = 8 FROM schema_migrations), 'all eight migrations tracked');
SELECT pg_temp.assert_true((SELECT count(*) = 0 FROM users), 'fresh database contains no users');
SELECT pg_temp.assert_true((SELECT count(*) > 0 FROM interests), 'interest taxonomy seeded');

DO $$
DECLARE adult_id uuid := '00000000-0000-4000-8000-000000000001';
BEGIN
  INSERT INTO users(id,email,password_hash,birthdate,signup_source)
  VALUES (adult_id,'fictional-adult-a@example.test','not-a-login-hash',(CURRENT_DATE - INTERVAL '18 years')::date,'synthetic_demo');
  PERFORM pg_temp.assert_true(EXISTS(SELECT 1 FROM users WHERE id=adult_id), 'exactly 18 accepted');
  BEGIN
    INSERT INTO users(email,password_hash,birthdate,signup_source)
    VALUES ('rejected-age-fixture@example.test','not-a-login-hash',(CURRENT_DATE - INTERVAL '18 years')::date + 1,'synthetic_demo');
    RAISE EXCEPTION 'FAIL: underage insert accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'user must be at least 18 years old' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: underage insert rejected';
  BEGIN
    UPDATE users SET birthdate=(CURRENT_DATE - INTERVAL '18 years')::date + 1 WHERE id=adult_id;
    RAISE EXCEPTION 'FAIL: underage update accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'user must be at least 18 years old' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: underage update rejected';
  BEGIN
    UPDATE users SET birthdate=NULL WHERE id=adult_id;
    RAISE EXCEPTION 'FAIL: missing birthdate accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'birthdate is required' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'PASS: missing birthdate rejected';
  BEGIN
    INSERT INTO users(email,password_hash,birthdate,signup_source)
    VALUES ('FICTIONAL-ADULT-A@example.test','not-a-login-hash','1990-01-01','synthetic_demo');
    RAISE EXCEPTION 'FAIL: duplicate email accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  RAISE NOTICE 'PASS: case-insensitive email uniqueness';
END $$;

INSERT INTO users(id,email,password_hash,birthdate,signup_source)
VALUES ('00000000-0000-4000-8000-000000000002','fictional-adult-b@example.test','not-a-login-hash','1990-01-01','synthetic_demo');
INSERT INTO profiles(user_id,display_name,intent_tags)
SELECT id,'Fictional adult test fixture',ARRAY['friends','chat']::intent_tag[] FROM users;
SELECT pg_temp.assert_true((SELECT bool_and(intent_tags::text[] = ARRAY['friends','chat']) FROM profiles), 'intent tags preserve text-array contract');
SELECT pg_temp.assert_true((SELECT bool_and(coarse_location='city' AND photo_verification_status='unverified' AND moderation_status='pending') FROM profiles), 'privacy and verification defaults');

INSERT INTO locations(user_id,precise_lat,precise_lng,coarse_lat,coarse_lng,travel_lat,travel_lng)
VALUES ('00000000-0000-4000-8000-000000000001',40.123,-73.456,40.1,-73.5,41,-74);
SELECT pg_temp.assert_true((SELECT ST_X(precise_geog::geometry)=-73.456 AND ST_Y(precise_geog::geometry)=40.123 AND ST_X(coarse_geog::geometry)=-73.5 AND ST_Y(travel_geog::geometry)=41 FROM locations), 'geography trigger uses longitude/latitude order');
UPDATE locations SET precise_lat=NULL,precise_lng=NULL,travel_lat=NULL,travel_lng=NULL;
SELECT pg_temp.assert_true((SELECT precise_geog IS NULL AND travel_geog IS NULL AND coarse_geog IS NOT NULL FROM locations), 'clearing coordinates clears derived geography');

INSERT INTO chat_threads(id,participant_low,participant_high)
VALUES ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002');
INSERT INTO thread_participants(thread_id,user_id)
SELECT '00000000-0000-4000-8000-000000000003',id FROM users;
SELECT pg_temp.assert_true((SELECT count(*)=2 FROM thread_participants), 'both chat participants can join');
INSERT INTO chat_messages(thread_id,sender_id,client_message_id,body)
VALUES ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','synthetic-message-1','Fictional test message');
SELECT pg_temp.assert_true((SELECT last_message_at IS NOT NULL FROM chat_threads), 'message updates thread activity');
DO $$ BEGIN
  BEGIN
    INSERT INTO chat_messages(thread_id,sender_id,client_message_id,body)
    VALUES ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','synthetic-message-1','Duplicate test message');
    RAISE EXCEPTION 'FAIL: duplicate client message accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  RAISE NOTICE 'PASS: message idempotency constraint';
  BEGIN
    INSERT INTO chat_threads(participant_low,participant_high)
    VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002');
    RAISE EXCEPTION 'FAIL: duplicate thread accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  RAISE NOTICE 'PASS: pair deduplication';
  BEGIN
    INSERT INTO chat_threads(participant_low,participant_high)
    VALUES ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'FAIL: reversed pair accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'PASS: ordered pair constraint';
END $$;
ROLLBACK;
SELECT CASE WHEN count(*)=0 THEN 'PASS: all synthetic users rolled back' ELSE 'FAIL: fixtures remain' END FROM users;
