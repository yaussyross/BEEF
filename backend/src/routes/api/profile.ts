import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";
import { screenText } from "~/lib/moderation";
import {
  INTENT_TAGS,
  isCoarseMode,
  isIntentTag,
  type CoarseMode,
} from "~/lib/privacy";

interface OwnProfileRow {
  id: string;
  email: string;
  birthdate: string;
  display_name: string | null;
  bio: string | null;
  intent_tags: string[];
  photo_verification_status: string;
  coarse_location: string;
  hide_distance: boolean;
}

function has(body: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(body, key);
}

/**
 * GET /api/profile  → the caller's own full profile (includes own birthdate).
 * PUT /api/profile  → update own bio, intent_tags, interests, coarse_location,
 *                     hide_distance.
 *
 * Privacy invariants:
 *   - Own birthdate is returned ONLY to the owner. Other users' views (grid +
 *     /api/profile/$id) never receive a birthdate — only an age bucket / adult
 *     flag. This file only ever returns the OWN profile, so it is the one place
 *     the owner can see their own birthdate.
 *   - No location (precise or coarse) is returned here.
 */
export const Route = createFileRoute("/api/profile")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const userId = await requireAuth(request);

          const rows = await sql()`SELECT u.id, u.email, u.birthdate::text AS birthdate,
                                          p.display_name, p.bio, p.intent_tags::text[] AS intent_tags,
                                          p.photo_verification_status, p.coarse_location, p.hide_distance
                                   FROM users u
                                   JOIN profiles p ON p.user_id = u.id
                                   WHERE u.id = ${userId}
                                   LIMIT 1`;
          const row = rows[0] as OwnProfileRow | undefined;
          if (!row) {
            return json({ error: "not_found", message: "Profile not found." }, { status: 404 });
          }

          const interests = await sql()`SELECT i.slug, i.label
                                       FROM profile_interests pi
                                       JOIN interests i ON i.id = pi.interest_id
                                       WHERE pi.profile_id = (
                                         SELECT id FROM profiles WHERE user_id = ${userId}
                                       )
                                       ORDER BY i.label`;

          return json({
            user: {
              id: row.id,
              email: row.email,
              birthdate: String(row.birthdate), // own only
              display_name: row.display_name,
              bio: row.bio,
              intent_tags: Array.isArray(row.intent_tags) ? row.intent_tags : [],
              photo_verification_status: row.photo_verification_status,
              coarse_location: row.coarse_location,
              hide_distance: Boolean(row.hide_distance),
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

      PUT: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }

        try {
          const userId = await requireAuth(request);

          // Validate all fields before any writes or moderation side effects.
          if (has(body, "interests") && (!Array.isArray(body.interests) || !body.interests.every(s => typeof s === "string"))) {
            return json({ error: "invalid_interests", message: "interests must be an array of slugs." }, { status: 400 });
          }
          if (has(body, "bio") && body.bio !== null && (typeof body.bio !== "string" || body.bio.length > 2000)) {
            return json({ error: "invalid_bio", message: "Bio must be text up to 2000 characters." }, { status: 400 });
          }
          if (has(body, "display_name") && (typeof body.display_name !== "string" || body.display_name.trim().length > 80)) {
            return json({ error: "invalid_display_name", message: "Display name must be text up to 80 characters." }, { status: 400 });
          }
          const rows = await sql()`SELECT id, bio, intent_tags::text[] AS intent_tags, coarse_location, hide_distance
                                   FROM profiles
                                   WHERE user_id = ${userId}
                                   LIMIT 1`;
          const current = rows[0] as
            | {
                id: string;
                bio: string | null;
                intent_tags: string[];
                coarse_location: string;
                hide_distance: boolean;
              }
            | undefined;
          if (!current) {
            return json({ error: "not_found", message: "Profile not found." }, { status: 404 });
          }

          // Resolve each editable field to its new value (unchanged when absent).
          const bio = has(body, "bio")
            ? (typeof body.bio === "string" ? body.bio : null)
            : current.bio;

          let reviewReason: string | null = null;
          // Sauce Check (text screen) on the bio at write time. Blocked content
          // (paid sex / slurs) is refused with a friendly prompt; flagged
          // (suggestive) content is allowed but queued for human review.
          if (has(body, "bio") || has(body, "display_name")) {
            const screen = screenText([has(body, "bio") ? bio : null, body.display_name].filter(x => typeof x === "string").join(" "));
            if (screen.verdict === "block") {
              return json(
                { error: "bio_blocked", message: "That bio can't be saved. Keep it saucy, not smutty." },
                { status: 403 }
              );
            }
            if (screen.verdict === "flag") {
              reviewReason = screen.reasons.join(",");
            }
          }

          let intentTags: string[] = Array.isArray(current.intent_tags) ? current.intent_tags : [];
          if (has(body, "intent_tags")) {
            const incoming = body.intent_tags;
            if (!Array.isArray(incoming) || !incoming.every(isIntentTag)) {
              return json(
                {
                  error: "invalid_intent_tags",
                  message: `intent_tags must be an array of: ${INTENT_TAGS.join(", ")}.`,
                },
                { status: 400 }
              );
            }
            intentTags = incoming;
          }

          let coarseLocation: CoarseMode = isCoarseMode(current.coarse_location)
            ? current.coarse_location
            : "city";
          if (has(body, "coarse_location")) {
            if (!isCoarseMode(body.coarse_location)) {
              return json(
                { error: "invalid_coarse_location", message: "coarse_location must be exact | city | region." },
                { status: 400 }
              );
            }
            coarseLocation = body.coarse_location;
          }

          let hideDistance = Boolean(current.hide_distance);
          if (has(body, "hide_distance")) {
            if (typeof body.hide_distance !== "boolean") {
              return json(
                { error: "invalid_hide_distance", message: "hide_distance must be a boolean." },
                { status: 400 }
              );
            }
            hideDistance = body.hide_distance;
          }

          const db = sql();
          const writes = [db`SELECT id FROM profiles WHERE user_id = ${userId} FOR UPDATE`];
          writes.push(db`UPDATE profiles
                     SET display_name = CASE WHEN ${has(body, "display_name")} THEN ${typeof body.display_name === "string" ? body.display_name.trim() : null} ELSE display_name END,
                         bio = CASE WHEN ${has(body, "bio")} THEN ${bio} ELSE bio END,
                         intent_tags = CASE WHEN ${has(body, "intent_tags")} THEN ${intentTags}::intent_tag[] ELSE intent_tags END,
                         coarse_location = CASE WHEN ${has(body, "coarse_location")} THEN ${coarseLocation}::coarse_location_mode ELSE coarse_location END,
                         hide_distance = CASE WHEN ${has(body, "hide_distance")} THEN ${hideDistance} ELSE hide_distance END
                     WHERE user_id = ${userId}
                     RETURNING user_id AS id, display_name, bio, intent_tags::text[] AS intent_tags,
                       coarse_location, hide_distance`);

          // Recompute after acquiring the profile row lock, from the current
          // database mode/point. Never decide from the earlier unlocked read.
          if (has(body, "coarse_location")) {
            writes.push(db`UPDATE locations l SET
              coarse_mode = p.coarse_location,
              coarse_lat = CASE p.coarse_location WHEN 'exact' THEN round(l.precise_lat::numeric, 6)
                ELSE round(((floor(l.precise_lat / CASE p.coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END) + 0.5) * CASE p.coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END)::numeric, 6) END,
              coarse_lng = CASE p.coarse_location WHEN 'exact' THEN round(l.precise_lng::numeric, 6)
                ELSE round(((floor(l.precise_lng / CASE p.coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END) + 0.5) * CASE p.coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END)::numeric, 6) END
              FROM profiles p WHERE p.user_id = ${userId} AND l.user_id = p.user_id
              AND l.precise_lat IS NOT NULL AND l.precise_lng IS NOT NULL`);
          }

          // Replace interests (slugs) when provided. Unknown slugs are ignored
          // (they simply match no seeded interest row).
          if (has(body, "interests")) {
            const incoming = body.interests;
            if (!Array.isArray(incoming) || !incoming.every((s): s is string => typeof s === "string")) {
              return json(
                { error: "invalid_interests", message: "interests must be an array of slugs." },
                { status: 400 }
              );
            }
            const slugs = incoming as string[];
            writes.push(db`DELETE FROM profile_interests WHERE profile_id = ${current.id}`);
            writes.push(db`INSERT INTO profile_interests (profile_id, interest_id)
              SELECT ${current.id}, i.id
              FROM interests i
              WHERE i.slug = ANY(${slugs}::text[])
              ON CONFLICT (profile_id, interest_id) DO NOTHING`);
          }

          if (reviewReason !== null) writes.push(db`INSERT INTO moderation_queue (target_type, target_id, source, reason, status)
            VALUES ('profile', ${current.id}, 'auto', ${reviewReason}, 'pending')`);
          writes.push(db`SELECT i.slug, i.label
                                       FROM profile_interests pi
                                       JOIN interests i ON i.id = pi.interest_id
                                       WHERE pi.profile_id = ${current.id}
                                       ORDER BY i.label`);
          const results = await db.transaction(writes);
          const interests = results[results.length - 1];
          return json({
            user: {
              ...results[1][0],
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
