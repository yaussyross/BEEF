import { createFileRoute } from "@tanstack/react-router";
import { errorResponse, json } from "~/lib/http";
import {
  listModerationQueue,
  requireModerationAdmin,
  type ModerationTargetType,
} from "~/lib/moderation";

const TARGET_TYPES: readonly string[] = ["profile", "photo", "message"];

/**
 * GET /api/moderation/queue  (internal admin — X-Moderation-Key header)
 *
 * List the moderation queue for human review. Returns a snapshot of the flagged
 * content (bio / message body / photo storage key) so a reviewer can decide
 * without a second lookup. NEVER returns any location data.
 *
 * Query params:
 *   status       = pending (default) | in_review | approved | rejected
 *   target_type  = profile | photo | message (optional filter)
 *   limit        = 1..100 (default 50)
 *   offset       = 0.. (default 0)
 */
export const Route = createFileRoute("/api/moderation/queue")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          requireModerationAdmin(request);

          const url = new URL(request.url);
          const status = url.searchParams.get("status") ?? "pending";
          const targetTypeParam = url.searchParams.get("target_type") ?? undefined;
          if (targetTypeParam && !TARGET_TYPES.includes(targetTypeParam)) {
            return json(
              { error: "invalid_target_type", message: "target_type must be profile | photo | message." },
              { status: 400 }
            );
          }

          const limit = clamp(parseInt(url.searchParams.get("limit") ?? "", 10) || 50, 1, 100);
          const offset = Math.max(0, parseInt(url.searchParams.get("offset") ?? "", 10) || 0);

          const items = await listModerationQueue({
            status,
            targetType: targetTypeParam as ModerationTargetType | undefined,
            limit,
            offset,
          });

          return json({ items });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});

function clamp(value: number, min: number, max: number): number {
  if (Number.isNaN(value)) return min;
  return Math.min(Math.max(value, min), max);
}
