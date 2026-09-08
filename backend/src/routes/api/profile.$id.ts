import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json } from "~/lib/http";
import { ageBucket, ageYears } from "~/lib/privacy";

/**
 * GET /api/profile/:id  (protected)
 *
 * A sanitised PUBLIC view of another user's profile. The privacy invariants are
 * the whole point of this route:
 *
 *   - NEVER returns the remote's birthdate (only `is_adult` + `age_bucket`).
 *   - NEVER returns any location (precise or coarse).
 *   - Excludes deleted/suspended/banned users, hidden-from-grid profiles, and
 *     either direction of a block (same rules as the grid).
 */
export const Route = createFileRoute("/api/profile/$id")({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        try {
          const userId = await requireAuth(request);
          const targetId = params.id;

          const rows = await sql()`SELECT u.id, u.birthdate::text AS birthdate, p.display_name, p.bio, p.intent_tags::text[] AS intent_tags,
                                          p.photo_verification_status
                                   FROM users u
                                   JOIN profiles p ON p.user_id = u.id
                                   WHERE u.id = ${targetId}
                                     AND u.id <> ${userId}
                                     AND u.status = 'active'
                                     AND p.moderation_status IN ('pending', 'approved')
                                     AND NOT EXISTS (
                                       SELECT 1 FROM blocks b WHERE b.blocker_id = ${userId} AND b.blocked_id = u.id
                                     )
                                     AND NOT EXISTS (
                                       SELECT 1 FROM blocks b WHERE b.blocker_id = u.id AND b.blocked_id = ${userId}
                                     )
                                   LIMIT 1`;
          const row = rows[0] as
            | {
                id: string;
                birthdate: string;
                display_name: string | null;
                bio: string | null;
                intent_tags: string[];
                photo_verification_status: string;
              }
            | undefined;
          if (!row) {
            return json({ error: "not_found", message: "Profile not found." }, { status: 404 });
          }

          const interests = await sql()`SELECT i.slug, i.label
                                       FROM profile_interests pi
                                       JOIN interests i ON i.id = pi.interest_id
                                       WHERE pi.profile_id = (
                                         SELECT id FROM profiles WHERE user_id = ${targetId}
                                       )
                                       ORDER BY i.label`;

          const birthdate = String(row.birthdate);
          const age = ageYears(birthdate);

          return json({
            user: {
              id: row.id,
              display_name: row.display_name,
              bio: row.bio,
              intent_tags: Array.isArray(row.intent_tags) ? row.intent_tags : [],
              photo_verification_status: row.photo_verification_status,
              is_adult: age >= 18,
              age_bucket: ageBucket(birthdate),
              interests: (interests as unknown as { slug: string; label: string }[]).map((i) => ({
                slug: i.slug,
                label: i.label,
              })),
            },
          });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
