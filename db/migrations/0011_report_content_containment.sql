-- Owner approved urgent review + specific-content containment on 2026-10-26.
-- No automatic account suspension or historical account reinstatement.
ALTER TABLE moderation_queue ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal'
  CHECK (priority IN ('normal', 'urgent'));
ALTER TABLE moderation_queue ADD COLUMN IF NOT EXISTS report_id uuid REFERENCES reports(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS moderation_queue_priority_idx ON moderation_queue (priority, created_at);
CREATE TABLE IF NOT EXISTS report_content_holds (
  report_id uuid PRIMARY KEY REFERENCES reports(id) ON DELETE CASCADE,
  message_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS report_content_holds_message_idx ON report_content_holds (message_id);
-- Retain target identity even if the source is deleted; evidence remains separate.
-- No API exposes raw evidence or releases a hold until specialized review is specified.
INSERT INTO report_content_holds (report_id, message_id)
  SELECT id, message_id FROM reports WHERE is_csam AND message_id IS NOT NULL
  ON CONFLICT DO NOTHING;
UPDATE chat_messages SET moderation_status = 'pending'
  WHERE moderation_status = 'approved'
    AND EXISTS (SELECT 1 FROM report_content_holds h WHERE h.message_id = chat_messages.id);
UPDATE moderation_queue q SET priority = 'urgent'
  WHERE EXISTS (SELECT 1 FROM reports r LEFT JOIN profiles p ON p.user_id = r.reported_user_id
    WHERE r.is_csam AND ((q.target_type = 'message' AND q.target_id = r.message_id)
      OR (q.target_type = 'profile' AND q.target_id = p.id)));

CREATE OR REPLACE FUNCTION guard_held_message_approval() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.moderation_status = 'approved' AND EXISTS
    (SELECT 1 FROM report_content_holds WHERE message_id = NEW.id) THEN
    RAISE EXCEPTION 'Specialized review is required before releasing held content'
      USING ERRCODE = '23514', CONSTRAINT = 'message_safety_hold';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_message_safety_hold ON chat_messages;
CREATE TRIGGER trg_message_safety_hold BEFORE UPDATE ON chat_messages
  FOR EACH ROW EXECUTE FUNCTION guard_held_message_approval();

CREATE OR REPLACE FUNCTION submit_report_once(
  actor uuid, request_id uuid, fingerprint text, target_user uuid,
  target_thread uuid, target_message uuid, target_profile uuid,
  category report_type, details text, csam boolean
) RETURNS TABLE (report_id uuid, created boolean) LANGUAGE plpgsql AS $$
DECLARE saved reports%ROWTYPE;
BEGIN
  IF request_id IS NULL OR fingerprint IS NULL THEN
    RAISE EXCEPTION 'Missing report request identity';
  END IF;
  INSERT INTO reports (reporter_id, client_report_id, request_hash,
    reported_user_id, thread_id, message_id, report_type, reason, is_csam,
    ncmec_status, status)
  VALUES (actor, request_id, fingerprint, target_user, target_thread,
    target_message, category, details, csam,
    CASE WHEN csam THEN 'pending_submission'::ncmec_status ELSE NULL END, 'open')
  ON CONFLICT (reporter_id, client_report_id) DO NOTHING
  RETURNING * INTO saved;
  IF saved.id IS NULL THEN
    SELECT * INTO STRICT saved FROM reports
      WHERE reporter_id = actor AND client_report_id = request_id;
    IF saved.request_hash IS DISTINCT FROM fingerprint THEN
      RAISE EXCEPTION 'Report request key conflict'
        USING ERRCODE = '23505', CONSTRAINT = 'report_request_conflict';
    END IF;
    RETURN QUERY SELECT saved.id, false;
    RETURN;
  END IF;
  INSERT INTO moderation_queue (target_type, target_id, source, reason, status, priority, report_id)
    VALUES (CASE WHEN target_message IS NULL THEN 'profile'::moderation_target
      ELSE 'message'::moderation_target END,
      COALESCE(target_message, target_profile), 'user_report', details, 'pending',
      CASE WHEN csam THEN 'urgent' ELSE 'normal' END, saved.id);
  IF csam THEN
    INSERT INTO report_evidence (report_id, kind, content_hash, payload)
    SELECT saved.id, part.kind, encode(sha256(convert_to(part.payload, 'UTF8')), 'hex'), part.payload
    FROM (VALUES
      ('message_body', (SELECT body FROM chat_messages WHERE id = target_message)),
      ('report_reason', details),
      ('reported_user_id', target_user::text)
    ) AS part(kind, payload)
    WHERE part.payload IS NOT NULL AND part.payload <> '';
    IF target_message IS NOT NULL THEN
      INSERT INTO report_content_holds (report_id, message_id) VALUES (saved.id, target_message);
      UPDATE chat_messages SET moderation_status = 'pending'
        WHERE id = target_message AND moderation_status = 'approved';
    END IF;
  END IF;
  RETURN QUERY SELECT saved.id, true;
END;
$$;
