import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { isUuid, requireAuth } from "~/lib/auth";
import { otherParticipant } from "~/lib/chat";
import { errorResponse, json, readJson } from "~/lib/http";
import {
  disableAccountForCsam,
  preserveEvidence,
  submitNcmecReport,
} from "~/lib/ncmec";

/**
 * /api/report  (protected)
 *
 * Report intake. Writes to `reports` and enqueues a `moderation_queue` row so
 * the (later-phase) moderation pipeline has a single place to consume. This is
 * the ONLY thing this route does — it does NOT run the AI/vision classifier and
 * it does NOT submit to NCMEC. Those are wired in a later phase at the marker
 * below.
 *
 * Body:
 *   {
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

          // CSAM flag: explicit is_csam=true, or report_type 'csam'. In the live
          // pipeline this routes to evidence preservation + NCMEC CyberTipline.
          const isCsam = body.is_csam === true || reportType === "csam";

          const reportRows = await sql()`INSERT INTO reports
              (reporter_id, reported_user_id, thread_id, message_id, report_type, reason,
               is_csam, ncmec_status, status)
            VALUES
              (${userId}, ${resolved.reportedUserId}, ${resolved.threadId ?? null},
               ${resolved.messageId ?? null}, ${reportType}, ${reason},
               ${isCsam}, ${isCsam ? "pending_submission" : null}, 'open')
            RETURNING id, reported_user_id, message_id`;

          const report = reportRows[0] as
            | { id: string; reported_user_id: string | null; message_id: string | null }
            | undefined;
          if (!report) {
            return json({ error: "report_failed", message: "Could not record the report." }, { status: 500 });
          }

          // Enqueue for review. A message report targets the message; otherwise
          // it targets the reported user's profile.
          const targetType = report.message_id ? "message" : "profile";
          const targetId = report.message_id ?? resolved.profileId;
          await sql()`INSERT INTO moderation_queue (target_type, target_id, source, reason, status)
                       VALUES (${targetType}, ${targetId}, 'user_report', ${reason}, 'pending')`;

          // ─────────────────────────────────────────────────────────────────────
          // CSAM → NCMEC CyberTipline flow (live before launch). The report insert
          // already set reports.ncmec_status = 'pending_submission'. Here we (1)
          // preserve evidence so a deleting source can't destroy it, (2) freeze
          // the reported account, and (3) queue the submission. The submission
          // itself is a STUB (src/lib/ncmec.ts) — no credentials yet, and it must
          // be human-reviewed before anything is transmitted.
          // ─────────────────────────────────────────────────────────────────────
          if (isCsam && report.reported_user_id) {
            const messageBody = report.message_id ? await messageBodyFor(report.message_id) : null;
            await preserveEvidence(report.id, {
              messageBody,
              reason,
              reportedUserId: report.reported_user_id,
            });
            await disableAccountForCsam(report.reported_user_id);
            await submitNcmecReport(report.id);
          }

          return json(
            {
              ok: true,
              report_id: report.id,
              moderation_queued: true,
              is_csam: isCsam,
            },
            { status: 201 }
          );
        } catch (err) {
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

/** Fetch a message body for evidence preservation (returns null if gone). */
async function messageBodyFor(messageId: string): Promise<string | null> {
  const rows = await sql()`SELECT body FROM chat_messages WHERE id = ${messageId} LIMIT 1`;
  const row = rows[0] as { body: string } | undefined;
  return row?.body ?? null;
}
