import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { isUuid, requireAuth } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";
import { dropSocketsForPair } from "~/ws/chat";

/**
 * /api/block  (protected)
 *
 *   POST   — block another user.  Body: { blocked_user_id }
 *   DELETE — unblock another user. Body: { blocked_user_id }
 *
 * A block is enforced in BOTH directions everywhere it matters:
 *   - Grid and public-profile reads already exclude either direction of a block.
 *   - Chat read/send paths (src/lib/chat.ts) refuse when either direction is
 *     blocked, so a blocked user can neither read nor send, and the blocker is
 *     equally cut off (no data leaks in either direction).
 *   - On block, every live socket for both users is force-closed immediately
 *     (dropSocketsForPair) so the block takes effect without waiting for the
 *     next message.
 */
export const Route = createFileRoute("/api/block")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          const userId = await requireAuth(request);
          const blockedUserId = body.blocked_user_id;
          if (!isUuid(blockedUserId)) {
            return json(
              { error: "invalid_user", message: "blocked_user_id is required and must be a UUID." },
              { status: 400 }
            );
          }
          if (blockedUserId === userId) {
            return json({ error: "self_block", message: "You can't block yourself." }, { status: 400 });
          }

          // Idempotent: re-blocking an already-blocked user is a no-op.
          await sql()`INSERT INTO blocks (blocker_id, blocked_id)
                       VALUES (${userId}, ${blockedUserId})
                       ON CONFLICT (blocker_id, blocked_id) DO NOTHING`;

          // Immediate effect: drop any live sockets for both parties.
          dropSocketsForPair(userId, blockedUserId);

          return json({ ok: true, blocked: true });
        } catch (err) {
          return errorResponse(err);
        }
      },

      DELETE: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          const userId = await requireAuth(request);
          const blockedUserId = body.blocked_user_id;
          if (!isUuid(blockedUserId)) {
            return json(
              { error: "invalid_user", message: "blocked_user_id is required and must be a UUID." },
              { status: 400 }
            );
          }

          await sql()`DELETE FROM blocks
                       WHERE blocker_id = ${userId} AND blocked_id = ${blockedUserId}`;

          return json({ ok: true, blocked: false });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
