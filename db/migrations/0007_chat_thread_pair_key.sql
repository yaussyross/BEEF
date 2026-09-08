-- =============================================================================
-- BEEF — Migration 0007: fix the 1:1 thread dedupe key
-- Idempotent (DROP ... IF EXISTS + CREATE ... IF NOT EXISTS).
--
-- Why: 0003 declared the sorted-pair dedupe as
--     thread_participants UNIQUE (participant_low, participant_high)
-- but thread_participants is a *membership* table — one row per user per
-- thread (PRIMARY KEY (thread_id, user_id)). Both membership rows of a single
-- thread store the SAME sorted pair, so inserting the second participant always
-- violates that UNIQUE constraint. The correct home for "one thread per
-- unordered pair" is chat_threads, which has exactly one row per thread.
--
-- This migration moves the pair key onto chat_threads and drops it from
-- thread_participants (which becomes pure membership). Pre-launch the chat
-- tables are empty, so no backfill is needed.
-- =============================================================================

-- 1. Drop the two broken constraints from thread_participants.
ALTER TABLE thread_participants DROP CONSTRAINT IF EXISTS thread_participants_sorted_pair;
ALTER TABLE thread_participants DROP CONSTRAINT IF EXISTS thread_participants_pair_ordered;

-- 2. Drop the now-redundant pair columns from the membership rows.
ALTER TABLE thread_participants
  DROP COLUMN IF EXISTS participant_low,
  DROP COLUMN IF EXISTS participant_high;

-- 3. Add the sorted-pair key to chat_threads (one row per thread).
ALTER TABLE chat_threads
  ADD COLUMN IF NOT EXISTS participant_low  uuid,
  ADD COLUMN IF NOT EXISTS participant_high uuid;

-- Backfill is intentionally a no-op: this runs pre-launch while chat_threads is
-- empty. If applied against a non-empty table, the columns would be NULL and the
-- CHECK below would be added only after backfilling — see the migration README.

-- 4. Enforce one-thread-per-pair and the stable ordering invariant.
CREATE UNIQUE INDEX IF NOT EXISTS chat_threads_pair_uniq
  ON chat_threads (participant_low, participant_high);

ALTER TABLE chat_threads DROP CONSTRAINT IF EXISTS chat_threads_pair_ordered;
ALTER TABLE chat_threads
  ADD CONSTRAINT chat_threads_pair_ordered
  CHECK (participant_low IS NOT NULL
         AND participant_high IS NOT NULL
         AND participant_low < participant_high);
