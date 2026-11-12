import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";
import {
  isCoarseMode,
  isValidLat,
  isValidLng,
} from "~/lib/privacy";

/**
 * POST /api/location  (protected)
 *
 * Upserts the authenticated user's precise lat/lng into `locations` — the only
 * place precise coordinates exist, server-side. Derives and stores the coarse
 * centroid the grid will actually query, plus travel-mode and hide-distance.
 *
 * Body:
 *   { lat, lng,                       // required precise point
 *     coarse_location?,               // 'exact' | 'city' | 'region'
 *     travel_mode?, travel_lat?, travel_lng?,
 *     hide_distance? }
 *
 * Privacy invariants:
 *   - precise_* is written to `locations` and NEVER returned to the client
 *     (the owner already has their own coordinates; nothing else needs them).
 *   - coarse_* is derived from the precise point but never sent back either.
 *   - travel_mode makes the grid use travel_geog instead of coarse_geog, so the
 *     live precise GPS is ignored while travelling.
 */
export const Route = createFileRoute("/api/location")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const body = await readJson(request);
        if (!body) {
          return json({ error: "invalid_body", message: "Expected a JSON body." }, { status: 400 });
        }

        try {
          const userId = await requireAuth(request);

          const lat = body.lat;
          const lng = body.lng;
          if (!isValidLat(lat) || !isValidLng(lng)) {
            return json(
              { error: "invalid_coordinates", message: "lat and lng are required and must be valid." },
              { status: 400 }
            );
          }

          if ((Object.hasOwn(body, "coarse_location") && !isCoarseMode(body.coarse_location)) ||
              (Object.hasOwn(body, "hide_distance") && typeof body.hide_distance !== "boolean") ||
              (Object.hasOwn(body, "travel_mode") && typeof body.travel_mode !== "boolean")) {
            return json({ error: "invalid_preferences", message: "Invalid location preferences." }, { status: 400 });
          }
          const travelMode = body.travel_mode === true;
          let travelLat: number | null = null;
          let travelLng: number | null = null;
          if (travelMode) {
            if (!isValidLat(body.travel_lat) || !isValidLng(body.travel_lng)) {
              return json(
                {
                  error: "invalid_travel",
                  message: "travel_lat and travel_lng are required when travel_mode is true.",
                },
                { status: 400 }
              );
            }
            travelLat = body.travel_lat;
            travelLng = body.travel_lng;
          }

          // Update preferences and geometry atomically under the same profile
          // row lock used by profile edits. Missing preferences stay unchanged.
          const rows = await sql()`WITH chosen AS (
            UPDATE profiles SET
              coarse_location = CASE WHEN ${Object.hasOwn(body, "coarse_location")} THEN ${body.coarse_location ?? "city"}::coarse_location_mode ELSE coarse_location END,
              hide_distance = CASE WHEN ${Object.hasOwn(body, "hide_distance")} THEN ${body.hide_distance ?? false}::boolean ELSE hide_distance END
              WHERE user_id = ${userId} RETURNING coarse_location, hide_distance
          ), saved AS (
            INSERT INTO locations (user_id, precise_lat, precise_lng, coarse_lat, coarse_lng, coarse_mode, travel_mode, travel_lat, travel_lng)
            SELECT ${userId}, ${lat}, ${lng},
              CASE coarse_location WHEN 'exact' THEN round(${lat}::numeric, 6)
                ELSE round(((floor(${lat}::numeric / CASE coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END) + 0.5) * CASE coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END)::numeric, 6) END,
              CASE coarse_location WHEN 'exact' THEN round(${lng}::numeric, 6)
                ELSE round(((floor(${lng}::numeric / CASE coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END) + 0.5) * CASE coarse_location WHEN 'city' THEN 0.1 ELSE 0.5 END)::numeric, 6) END,
              coarse_location, ${travelMode}, ${travelLat}, ${travelLng} FROM chosen
            ON CONFLICT (user_id) DO UPDATE SET precise_lat = EXCLUDED.precise_lat, precise_lng = EXCLUDED.precise_lng,
              coarse_lat = EXCLUDED.coarse_lat, coarse_lng = EXCLUDED.coarse_lng, coarse_mode = EXCLUDED.coarse_mode,
              travel_mode = EXCLUDED.travel_mode, travel_lat = EXCLUDED.travel_lat, travel_lng = EXCLUDED.travel_lng
            RETURNING user_id
          ) SELECT chosen.coarse_location, chosen.hide_distance FROM chosen CROSS JOIN saved`;
          if (!rows[0]) return json({ error: "not_found", message: "Profile not found." }, { status: 404 });
          return json({ ok: true, ...rows[0], travel_mode: travelMode });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
