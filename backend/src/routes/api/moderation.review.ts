import { createFileRoute } from "@tanstack/react-router";
import { isUuid } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";
import {
  applyReviewDecision,
  requireModerationAdmin,
  type ReviewDecision,
} from "~/lib/moderation";

const DECISIONS: readonly string[] = ["approve", "reject", "blur", "ban"];

/**
 * POST /api/moderation/review  (internal admin — X-Moderation-Key header)
 *
 * Apply a human review decision to a queued item. "The Sauce Check" tone: blur
 * is the friendly "keep it but prompt a re-do" outcome, and ban is the explicit
 * last resort — nothing is auto-banned.
 *
 * Body:
 *   { queue_id: uuid, decision: 'approve' | 'reject' | 'blur' | 'ban' }
 *
 * The effect is applied to the right table by target type (profiles,
 * profile_photos, chat_messages), then the queue item is marked reviewed.
 */
export const Route = createFileRoute("/api/moderation/review")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          requireModerationAdmin(request);

          const queueId = body.queue_id;
          if (!isUuid(queueId)) {
            return json(
              { error: "invalid_queue_id", message: "queue_id is required and must be a UUID." },
              { status: 400 }
            );
          }

          const decision = body.decision;
          if (typeof decision !== "string" || !DECISIONS.includes(decision)) {
            return json(
              { error: "invalid_decision", message: `decision must be one of: ${DECISIONS.join(", ")}.` },
              { status: 400 }
            );
          }

          const result = await applyReviewDecision(queueId, decision as ReviewDecision);
          return json({ ok: true, decision, ...result });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
