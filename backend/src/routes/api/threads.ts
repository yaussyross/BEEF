import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { isUuid, requireAuth } from "~/lib/auth";
import {
  getOrCreateThread,
  isActiveUser,
  isBlockedEither,
  listThreads,
} from "~/lib/chat";
import { errorResponse, json, readJson } from "~/lib/http";

/**
 * /api/threads  (protected)
 *
 *   GET  — list the caller's 1:1 threads (inbox), newest-activity first, with
 *          the other participant's public summary, last message, and unread
 *          count. Blocked threads (either direction) are excluded. No location
 *          data is ever included.
 *
 *   POST — create (or fetch) the 1:1 thread with another user.
 *          Body: { other_user_id }.
 */
export const Route = createFileRoute("/api/threads")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const userId = await requireAuth(request);
          const threads = await listThreads(userId);
          return json({ threads });
        } catch (err) {
          return errorResponse(err);
        }
      },

      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          const userId = await requireAuth(request);

          const otherUserId = body.other_user_id;
          if (!isUuid(otherUserId)) {
            return json(
              { error: "invalid_user", message: "other_user_id is required and must be a UUID." },
              { status: 400 }
            );
          }
          if (otherUserId === userId) {
            return json(
              { error: "self_thread", message: "You can't start a thread with yourself." },
              { status: 400 }
            );
          }
          if (!(await isActiveUser(otherUserId))) {
            return json(
              { error: "user_not_found", message: "That user doesn't exist." },
              { status: 404 }
            );
          }
          if (await isBlockedEither(userId, otherUserId)) {
            return json(
              { error: "blocked", message: "You can't start a conversation with this user." },
              { status: 403 }
            );
          }

          const thread = await getOrCreateThread(userId, otherUserId);

          // Pull the other participant's public summary for the response (the
          // same fields the inbox exposes; no birthdate, no location).
          const other = await sql()`SELECT p.display_name, p.photo_verification_status
                                    FROM profiles p
                                    WHERE p.user_id = ${otherUserId}
                                    LIMIT 1`;
          const otherRow = other[0] as
            | { display_name: string | null; photo_verification_status: string }
            | undefined;

          return json(
            {
              thread: {
                id: thread.id,
                other_user_id: otherUserId,
                other_display_name: otherRow?.display_name ?? null,
                other_photo_verification_status: otherRow?.photo_verification_status ?? "unverified",
                participant_low: thread.participant_low,
                participant_high: thread.participant_high,
                last_message_at: thread.last_message_at,
              },
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

