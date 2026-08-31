-- =============================================================================
-- BEEF — Migration 0008: moderation content states + NCMEC evidence preservation
-- Idempotent (ALTER TYPE ... ADD VALUE IF NOT EXISTS, ADD COLUMN IF NOT EXISTS,
-- CREATE TABLE IF NOT EXISTS). Applies after 0003 (tables) / 0005 (triggers).
--
-- What's genuinely missing that the "Sauce Check" pipeline needs:
--   1. photo_status gains 'blurred' — a flagged-but-kept photo is blurred +
--      prompt-to-redo, NOT removed. 'rejected' stays the "remove" outcome.
--   2. chat_messages gains per-message moderation state so a flagged message can
--      be blurred (kept but hidden behind a blur + re-do prompt) without being
--      deleted, and an approved one is explicitly approved.
--   3. report_evidence snapshots offending content (message body, report reason,
--      reported user id) with a sha256 content hash for chain-of-custody, so a
--      user deleting the source cannot destroy NCMEC evidence.
-- =============================================================================

-- 1. photo_status: add 'blurred' (Sauce Check "keep it saucy, not smutty").
ALTER TYPE photo_status ADD VALUE IF NOT EXISTS 'blurred';

-- 2. Per-message moderation state (chat_messages).
DO $$ BEGIN
  CREATE TYPE content_moderation_status AS ENUM ('approved', 'pending', 'blurred', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE chat_messages
  ADD COLUMN IF NOT EXISTS moderation_status content_moderation_status NOT NULL DEFAULT 'approved';

-- 3. NCMEC / CSAM evidence snapshot (see src/lib/ncmec.ts).
CREATE TABLE IF NOT EXISTS report_evidence (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id    uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  -- 'message_body' | 'report_reason' | 'reported_user_id'
  kind         text NOT NULL,
  -- sha256 hex of `payload` — chain-of-custody marker, never the raw location.
  content_hash text NOT NULL,
  payload      text NOT NULL,
  captured_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS report_evidence_report_idx ON report_evidence (report_id);
