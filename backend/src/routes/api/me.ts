import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json } from "~/lib/http";

/**
 * GET /api/me  (protected)
 *
 * Reference implementation of a protected route: parses
 * `Authorization: Bearer <jwt>`, verifies the access token, and returns the
 * caller's own non-sensitive profile. Birthdate is deliberately NOT selected.
 */
export const Route = createFileRoute("/api/me")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const userId = await requireAuth(request);

          const rows = await sql()`SELECT u.id, u.email, u.status,
                                        p.display_name, p.bio, p.intent_tags::text[] AS intent_tags,
                                        p.photo_verification_status, p.hide_distance
                                 FROM users u
                                 JOIN profiles p ON p.user_id = u.id
                                 WHERE u.id = ${userId}
                                 LIMIT 1`;
          const me = rows[0];
          if (!me) {
            return json({ error: "not_found", message: "Profile not found." }, { status: 404 });
          }

          return json({ user: me });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
