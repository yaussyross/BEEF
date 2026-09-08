import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json } from "~/lib/http";
import { INTENT_TAGS, distanceLabel, isIntentTag } from "~/lib/privacy";

const METERS_PER_MILE = 1609.344;
const DEFAULT_RADIUS_MI = 50;
const MAX_RADIUS_MI = 1000;
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

interface GridRow {
  user_id: string;
  display_name: string | null;
  bio: string | null;
  intent_tags: string[];
  photo_verification_status: string;
  coarse_location: string;
  hide_distance: boolean;
  updated_at: Date | string;
  distance_mi: number;
  overlap_count: number;
}

/**
 * GET /api/grid  (protected)
 *
 * The proximity grid. Radius query via PostGIS `ST_DWithin` on the locations
 * geography (GIST index from 0004). Privacy-first by construction:
 *
 *   - EXCLUDES: self, blocks in both directions, suspended/banned/deleted users,
 *     hidden-from-grid profiles (moderation_status rejected/suspended/banned),
 *     and profiles whose intent_tags don't match the viewer's `intent` filter.
 *   - Distance is computed server-side against the coarse centroid and returned
 *     as a BUCKET ONLY ("<1 mi", "1–5 mi", …), "nearby" when the remote hides
 *     distance, or a rounded figure when the remote opted into exact mode.
 *   - NEVER returns raw lat/lng.
 *
 * Ordering: distance bucket → freshness (updated_at) → interest-overlap jitter
 * → user_id (stable). Paginated with limit/offset.
 *
 * Query params: limit, offset, radius_mi, intent (friends|chat|date|hookup).
 */
export const Route = createFileRoute("/api/grid")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        try {
          const userId = await requireAuth(request);

          const url = new URL(request.url);
          const limit = clamp(
            parseInt(url.searchParams.get("limit") ?? "", 10) || DEFAULT_LIMIT,
            1,
            MAX_LIMIT
          );
          const offset = Math.max(0, parseInt(url.searchParams.get("offset") ?? "", 10) || 0);
          const radiusMi = clamp(
            parseFloat(url.searchParams.get("radius_mi") ?? "") || DEFAULT_RADIUS_MI,
            1,
            MAX_RADIUS_MI
          );
          const intentParam = url.searchParams.get("intent");
          if (intentParam !== null && !isIntentTag(intentParam)) {
            return json(
              { error: "invalid_intent", message: `intent must be one of: ${INTENT_TAGS.join(", ")}.` },
              { status: 400 }
            );
          }
          const intent: string | null = intentParam;

          // The viewer's own effective origin: travel point while travelling,
          // otherwise the coarse centroid. precise_* is never read here.
          const originRows = await sql()`SELECT coarse_lat, coarse_lng, travel_mode, travel_lat, travel_lng
                                        FROM locations
                                        WHERE user_id = ${userId}
                                        LIMIT 1`;
          const originRow = originRows[0] as
            | {
                coarse_lat: number | null;
                coarse_lng: number | null;
                travel_mode: boolean;
                travel_lat: number | null;
                travel_lng: number | null;
              }
            | undefined;

          const useTravel = originRow?.travel_mode === true && originRow.travel_lat != null && originRow.travel_lng != null;
          const originLat = useTravel ? originRow!.travel_lat! : originRow?.coarse_lat ?? null;
          const originLng = useTravel ? originRow!.travel_lng! : originRow?.coarse_lng ?? null;

          // No location yet → the viewer can't be placed on a grid.
          if (originLat == null || originLng == null) {
            return json({ items: [], next_offset: null, has_more: false });
          }

          const radiusMeters = radiusMi * METERS_PER_MILE;

          const rows = await sql()`WITH origin AS (
              SELECT ST_SetSRID(ST_MakePoint(${originLng}, ${originLat}), 4326)::geography AS geog
            ),
            candidates AS (
              SELECT
                u.id AS user_id,
                p.display_name,
                p.bio,
                p.intent_tags::text[] AS intent_tags,
                p.photo_verification_status,
                p.coarse_location,
                p.hide_distance,
                loc.updated_at,
                ST_Distance(
                  (SELECT geog FROM origin),
                  CASE
                    WHEN loc.travel_mode AND loc.travel_geog IS NOT NULL THEN loc.travel_geog
                    ELSE loc.coarse_geog
                  END
                ) / ${METERS_PER_MILE} AS distance_mi,
                (
                  SELECT count(*)
                  FROM profile_interests pi
                  WHERE pi.profile_id = p.id
                    AND pi.interest_id IN (
                      SELECT pi2.interest_id
                      FROM profile_interests pi2
                      WHERE pi2.profile_id = (SELECT id FROM profiles WHERE user_id = ${userId})
                    )
                ) AS overlap_count
              FROM users u
              JOIN profiles p ON p.user_id = u.id
              JOIN locations loc ON loc.user_id = u.id
              WHERE u.id <> ${userId}
                AND u.status = 'active'
                AND p.moderation_status IN ('pending', 'approved')
                AND NOT EXISTS (
                  SELECT 1 FROM blocks b WHERE b.blocker_id = ${userId} AND b.blocked_id = u.id
                )
                AND NOT EXISTS (
                  SELECT 1 FROM blocks b WHERE b.blocker_id = u.id AND b.blocked_id = ${userId}
                )
                AND (${intent}::text IS NULL OR p.intent_tags @> ARRAY[${intent}]::intent_tag[])
                AND ST_DWithin(
                  (SELECT geog FROM origin),
                  CASE
                    WHEN loc.travel_mode AND loc.travel_geog IS NOT NULL THEN loc.travel_geog
                    ELSE loc.coarse_geog
                  END,
                  ${radiusMeters}
                )
            )
            SELECT
              user_id,
              display_name,
              bio,
              intent_tags,
              photo_verification_status,
              coarse_location,
              hide_distance,
              updated_at,
              distance_mi,
              overlap_count,
              CASE
                WHEN distance_mi < 1 THEN 0
                WHEN distance_mi < 5 THEN 1
                WHEN distance_mi < 20 THEN 2
                WHEN distance_mi < 50 THEN 3
                ELSE 4
              END AS bucket_rank
            FROM candidates
            ORDER BY bucket_rank ASC, updated_at DESC, overlap_count DESC, user_id ASC
            LIMIT ${limit + 1} OFFSET ${offset}`;

          const results = (rows as unknown as GridRow[]).slice(0, limit);
          const hasMore = (rows as unknown as GridRow[]).length > limit;

          const items = results.map((row) => ({
            user_id: row.user_id,
            display_name: row.display_name,
            bio: row.bio,
            intent_tags: Array.isArray(row.intent_tags) ? row.intent_tags : [],
            photo_verification_status: row.photo_verification_status,
            distance: distanceLabel(
              Number(row.distance_mi),
              String(row.coarse_location),
              Boolean(row.hide_distance)
            ),
            shared_interests: Number(row.overlap_count) || 0,
            last_active_at: String(row.updated_at),
          }));

          return json({
            items,
            next_offset: hasMore ? offset + limit : null,
            has_more: hasMore,
          });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, value));
}
