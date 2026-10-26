-- Owner-approved eligibility: messages from BOTH participants spanning >= 5
-- minutes. Thread age, open-window time and client timestamps are not evidence.
CREATE OR REPLACE FUNCTION rating_chat_eligible(rater uuid, ratee uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT rater <> ratee
    AND EXISTS (SELECT 1 FROM users WHERE id = rater AND status = 'active')
    AND EXISTS (SELECT 1 FROM users WHERE id = ratee AND status = 'active')
    AND NOT EXISTS (
      SELECT 1 FROM blocks
      WHERE (blocker_id = rater AND blocked_id = ratee)
         OR (blocker_id = ratee AND blocked_id = rater)
    )
    AND EXISTS (
      SELECT 1
      FROM chat_threads t
      JOIN chat_messages m ON m.thread_id = t.id
      WHERE t.participant_low = LEAST(rater, ratee)
        AND t.participant_high = GREATEST(rater, ratee)
        AND m.sender_id IN (rater, ratee)
        AND m.created_at <= CURRENT_TIMESTAMP
        AND EXISTS (SELECT 1 FROM thread_participants WHERE thread_id = t.id AND user_id = rater)
        AND EXISTS (SELECT 1 FROM thread_participants WHERE thread_id = t.id AND user_id = ratee)
      GROUP BY t.id
      HAVING count(DISTINCT m.sender_id) = 2
         AND max(m.created_at) - min(m.created_at) >= INTERVAL '5 minutes'
    );
$$;

CREATE TABLE IF NOT EXISTS profile_ratings (
  rater_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ratee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stars smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (rater_id, ratee_id),
  CONSTRAINT profile_ratings_no_self CHECK (rater_id <> ratee_id)
);
CREATE INDEX IF NOT EXISTS profile_ratings_ratee_idx ON profile_ratings (ratee_id);

-- Enforce again at the write, including re-rating. A UI eligibility response
-- never grants a lasting permission; block/status/history may change later.
CREATE OR REPLACE FUNCTION profile_ratings_assert_eligible() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF rating_chat_eligible(NEW.rater_id, NEW.ratee_id) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'A mutual chat spanning five minutes is required'
      USING ERRCODE = '23514', CONSTRAINT = 'profile_ratings_eligible';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_profile_ratings_eligible ON profile_ratings;
CREATE TRIGGER trg_profile_ratings_eligible
  BEFORE INSERT OR UPDATE ON profile_ratings
  FOR EACH ROW EXECUTE FUNCTION profile_ratings_assert_eligible();
DROP TRIGGER IF EXISTS trg_profile_ratings_updated_at ON profile_ratings;
CREATE TRIGGER trg_profile_ratings_updated_at
  BEFORE UPDATE ON profile_ratings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
