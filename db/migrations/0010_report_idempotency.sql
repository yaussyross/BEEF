-- Historical reports remain unchanged. New API submissions require a UUID key
-- scoped to the authenticated reporter; receipts live with their report.
ALTER TABLE reports ADD COLUMN IF NOT EXISTS client_report_id uuid;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS request_hash text;
CREATE UNIQUE INDEX IF NOT EXISTS reports_reporter_request_idx
  ON reports (reporter_id, client_report_id);

-- SECURITY INVOKER: no privilege escalation. All existing database side effects
-- are committed together, including the existing (unresolved-policy) immediate
-- CSAM suspension. Replays never rerun moderation or overwrite review decisions.
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
  INSERT INTO moderation_queue (target_type, target_id, source, reason, status)
    VALUES (CASE WHEN target_message IS NULL THEN 'profile'::moderation_target
      ELSE 'message'::moderation_target END,
      COALESCE(target_message, target_profile), 'user_report', details, 'pending');
  IF csam THEN
    INSERT INTO report_evidence (report_id, kind, content_hash, payload)
    SELECT saved.id, part.kind, encode(sha256(convert_to(part.payload, 'UTF8')), 'hex'), part.payload
    FROM (VALUES
      ('message_body', (SELECT body FROM chat_messages WHERE id = target_message)),
      ('report_reason', details),
      ('reported_user_id', target_user::text)
    ) AS part(kind, payload)
    WHERE part.payload IS NOT NULL AND part.payload <> '';
    UPDATE users SET status = 'suspended' WHERE id = target_user;
    UPDATE profiles SET moderation_status = 'suspended' WHERE user_id = target_user;
  END IF;
  RETURN QUERY SELECT saved.id, true;
END;
$$;
