import { createFileRoute } from "@tanstack/react-router";
import { requireAuth } from "~/lib/auth";
import { markThreadRead } from "~/lib/chat";
import { errorResponse, json } from "~/lib/http";

/** REST equivalent of the WebSocket read frame for socket-unavailable clients. */
export const Route = createFileRoute("/api/threads/$id/read")({
  server: {
    handlers: {
      POST: async ({ request, params }) => {
        try {
          const userId = await requireAuth(request);
          await markThreadRead(userId, params.id);
          return json({ ok: true });
        } catch (error) {
          return errorResponse(error);
        }
      },
    },
  },
});
