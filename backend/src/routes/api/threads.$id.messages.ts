import { createFileRoute } from "@tanstack/react-router";
import { requireAuth } from "~/lib/auth";
import { getThreadHistory, sendMessage, type StoredMessage } from "~/lib/chat";
import { errorResponse, json, readJson } from "~/lib/http";

/**
 * /api/threads/:id/messages  (protected)
 *
 * REST fallback so the Flutter client can hydrate a conversation on open
 * without holding a socket, and send over HTTP when no socket is available.
 * The WebSocket path shares the exact same domain logic (src/lib/chat.ts).
 *
 *   GET  — history, newest-first, keyset-paginated.
 *          Query: ?limit= (default 50, max 100) & ?cursor=<next_cursor>.
 *   POST — send a message. Body: { client_message_id, body }.
 *          Idempotent on client_message_id (duplicates return the stored row).
 *
 * Both paths enforce: caller is a participant, and neither direction is
 * blocked. No location data is ever included.
 */
export const Route = createFileRoute("/api/threads/$id/messages")({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        try {
          const userId = await requireAuth(request);
          const url = new URL(request.url);
          const limit = parseInt(url.searchParams.get("limit") ?? "", 10) || 50;
          const cursor = url.searchParams.get("cursor") ?? undefined;

          const result = await getThreadHistory(userId, params.id, limit, cursor);
          return json({
            messages: result.messages.map(toWireMessage),
            next_cursor: result.next_cursor,
          });
        } catch (err) {
          return errorResponse(err);
        }
      },

      POST: async ({ request, params }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }
        try {
          const userId = await requireAuth(request);
          const clientMessageId = typeof body.client_message_id === "string" ? body.client_message_id : "";
          const text = typeof body.body === "string" ? body.body : "";

          const result = await sendMessage(userId, {
            threadId: params.id,
            clientMessageId,
            body: text,
          });

          return json(
            { message: toWireMessage(result.message), duplicate: !result.created },
            { status: result.created ? 201 : 200 }
          );
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});

function toWireMessage(m: StoredMessage): Record<string, unknown> {
  return {
    id: m.id,
    thread_id: m.thread_id,
    sender_id: m.sender_id,
    client_message_id: m.client_message_id,
    body: m.body,
    moderation_status: m.moderation_status,
    created_at: m.created_at,
  };
}
