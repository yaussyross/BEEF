import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { isUuid, requireAuth } from "~/lib/auth";
import { otherParticipant } from "~/lib/chat";
import { errorResponse, json, readJson } from "~/lib/http";
import { submitNcmecReport } from "~/lib/ncmec";
import { dropSocketsForUser } from "~/ws/registry";

/**
 * /api/report  (protected)
 *
 * Report intake. Atomically records a report, review queue entry and existing
 * CSAM evidence/suspension effects. Replays return the original receipt without
 * repeating those effects. No AI classifier or external NCMEC transmission runs.
 * Automatic suspension on an allegation remains an unresolved release-blocking
 * moderation/false-report risk; this retry fix does not approve that policy.
 *
 * Body:
 *   {
 *     client_report_id: uuid,    // stable per submission, reused on retries
 *     report_type: 'harassment' | 'impersonation' | 'underage'
 *                | 'commercial_solicitation' | 'explicit_content' | 'csam' | 'other',
 *     reason?: string,
 *     reported_user_id?: uuid,   // in-profile report
 *     message_id?: uuid,         // in-message report (also sets reported_user + thread)
 *     thread_id?: uuid,          // in-thread report (resolves the other participant)
 *     is_csam?: boolean          // set true (or report_type 'csam') to flag CSAM
 *   }
 *
 * At least one of reported_user_id / message_id / thread_id is required. A
 * message/thread report only resolves if the reporter is actually a participant
 * of that thread (you can't report a conversation you can't see).
 */
export const Route = createFileRoute("/api/report")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          const userId = await requireAuth(request);

          const clientReportId = body.client_report_id;
          if (!isUuid(clientReportId)) {
            return json({ error: "invalid_report_id", message: "A stable client_report_id UUID is required." }, { status: 400 });
          }

          const reportType = body.report_type;
          if (typeof reportType !== "string" || !REPORT_TYPES.includes(reportType)) {
            return json(
              {
                error: "invalid_report_type",
                message: `report_type must be one of: ${REPORT_TYPES.join(", ")}.`,
              },
              { status: 400 }
            );
          }

          const reason =
            typeof body.reason === "string" ? body.reason.trim().slice(0, 1000) : null;

          const isCsam = body.is_csam === true || reportType === "csam";
          // Hash effective request fields, not client identity or a resolved target
          // which could change after deletion. No additional copy of report text.
          const canonical = JSON.stringify({ report_type: reportType, reason, is_csam: isCsam,
            reported_user_id: isUuid(body.reported_user_id) ? body.reported_user_id.toLowerCase() : null,
            message_id: isUuid(body.message_id) ? body.message_id.toLowerCase() : null,
            thread_id: isUuid(body.thread_id) ? body.thread_id.toLowerCase() : null });
          const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(canonical));
          const requestHash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
          const existing = await sql()`SELECT id, request_hash, is_csam FROM reports
            WHERE reporter_id = ${userId} AND client_report_id = ${clientReportId}`;
          if (existing[0]) {
            if (existing[0].request_hash !== requestHash) return conflict();
            return receipt(String(existing[0].id), existing[0].is_csam === true);
          }

          // Resolve the report target (who is being reported and, for
          // message/thread reports, which thread/message).
          const resolved = await resolveTarget(userId, body);
          if (!resolved) {
            return json(
              {
                error: "missing_target",
                message: "Provide reported_user_id, message_id, or thread_id.",
              },
              { status: 400 }
            );
          }

          if (resolved.reportedUserId === userId) {
            return json({ error: "self_report", message: "You can't report yourself." }, { status: 400 });
          }

          // A single PostgreSQL call commits the report, queue, evidence and
          // existing suspension policy together. Unique reporter/key scope also
          // serializes concurrent retries; a rollback leaves no partial claim.
          const rows = await sql()`SELECT * FROM submit_report_once(
            ${userId}::uuid, ${clientReportId}::uuid, ${requestHash}::text,
            ${resolved.reportedUserId}::uuid, ${resolved.threadId}::uuid,
            ${resolved.messageId}::uuid, ${resolved.profileId}::uuid,
            ${reportType}::report_type, ${reason}::text, ${isCsam}::boolean)`;
          const saved = rows[0];
          if (!saved) throw new Error("Report transaction returned no receipt");
          if (saved.created && isCsam) {
            dropSocketsForUser(resolved.reportedUserId);
            // Nontransmitting stub only. Future external delivery requires a
            // durable outbox/provider idempotency, not this post-commit call.
            await submitNcmecReport(String(saved.report_id));
          }
          return receipt(String(saved.report_id), isCsam);
        } catch (err) {
          if ((err as { constraint?: string })?.constraint === "report_request_conflict") return conflict();
          return errorResponse(err);
        }
      },
    },
  },
});

const REPORT_TYPES: readonly string[] = [
  "harassment",
  "impersonation",
  "underage",
  "commercial_solicitation",
  "explicit_content",
  "csam",
  "other",
];

interface ResolvedTarget {
  reportedUserId: string;
  threadId: string | null;
  messageId: string | null;
  profileId: string;
}

/**
 * Resolve the report target into { reportedUserId, threadId, messageId, profileId }.
 * Returns null when no valid target was provided.
 */
async function resolveTarget(
  reporterId: string,
  body: Record<string, unknown>
): Promise<ResolvedTarget | null> {
  const reportedUserId = isUuid(body.reported_user_id) ? body.reported_user_id : null;
  const messageId = isUuid(body.message_id) ? body.message_id : null;
  const threadId = isUuid(body.thread_id) ? body.thread_id : null;

  // In-message report: the message's sender is the reported user; the reporter
  // must be a participant of that thread (privacy — no reporting what you can't
  // see).
  if (messageId) {
    const rows = await sql()`SELECT cm.sender_id AS reported_user_id, cm.thread_id
                            FROM chat_messages cm
                            JOIN thread_participants tp
                              ON tp.thread_id = cm.thread_id AND tp.user_id = ${reporterId}
                            WHERE cm.id = ${messageId}
                            LIMIT 1`;
    const row = rows[0] as { reported_user_id: string; thread_id: string } | undefined;
    if (!row) return null;
    return {
      reportedUserId: row.reported_user_id,
      threadId: row.thread_id,
      messageId,
      profileId: await profileIdFor(row.reported_user_id),
    };
  }

  // In-thread report: resolve the other participant.
  if (threadId) {
    const rows = await sql()`SELECT ct.participant_low, ct.participant_high
                            FROM chat_threads ct
                            JOIN thread_participants tp
                              ON tp.thread_id = ct.id AND tp.user_id = ${reporterId}
                            WHERE ct.id = ${threadId}
                            LIMIT 1`;
    const row = rows[0] as { participant_low: string; participant_high: string } | undefined;
    if (!row) return null;
    const other = otherParticipant(row, reporterId);
    return { reportedUserId: other, threadId, messageId: null, profileId: await profileIdFor(other) };
  }

  // In-profile report: the target is explicit.
  if (reportedUserId) {
    if (!(await userExists(reportedUserId))) return null;
    return {
      reportedUserId,
      threadId: null,
      messageId: null,
      profileId: await profileIdFor(reportedUserId),
    };
  }

  return null;
}

async function userExists(id: string): Promise<boolean> {
  const rows = await sql()`SELECT 1 AS x FROM users WHERE id = ${id} LIMIT 1`;
  return rows.length > 0;
}

async function profileIdFor(userId: string): Promise<string> {
  const rows = await sql()`SELECT id FROM profiles WHERE user_id = ${userId} LIMIT 1`;
  const row = rows[0] as { id: string } | undefined;
  return row?.id ?? userId;
}

function conflict() {
  return json({ error: "report_id_conflict", message: "This report ID was already used for different details." }, { status: 409 });
}
function receipt(reportId: string, isCsam: boolean) {
  return json({ ok: true, report_id: reportId, moderation_queued: true, is_csam: isCsam }, { status: 201 });
}
