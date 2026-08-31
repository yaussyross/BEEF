import { createFileRoute } from "@tanstack/react-router";
import { sql } from "~/db";
import { requireAuth } from "~/lib/auth";
import { errorResponse, json, readJson } from "~/lib/http";
import {
  coarseCentroid,
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

          // Coarse mode: prefer the value in this request; otherwise fall back
          // to the stored profile choice (default 'city' for a brand-new user).
          let coarseLocation = isCoarseMode(body.coarse_location) ? body.coarse_location : null;
          if (!coarseLocation) {
            const existing = await sql()`SELECT coarse_location FROM profiles WHERE user_id = ${userId} LIMIT 1`;
            const row = existing[0] as { coarse_location?: string } | undefined;
            coarseLocation = isCoarseMode(row?.coarse_location) ? row.coarse_location : "city";
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

          const hideDistance = body.hide_distance === true;

          const coarse = coarseCentroid(coarseLocation, lat, lng);

          // Upsert the location row. The 0005 trigger syncs the geography
          // columns from these plain doubles — we only ever write lat/lng.
          await sql()`INSERT INTO locations
              (user_id, precise_lat, precise_lng, coarse_lat, coarse_lng, coarse_mode,
               travel_mode, travel_lat, travel_lng)
            VALUES
              (${userId}, ${lat}, ${lng}, ${coarse.lat}, ${coarse.lng}, ${coarseLocation},
               ${travelMode}, ${travelLat}, ${travelLng})
            ON CONFLICT (user_id) DO UPDATE SET
              precise_lat = EXCLUDED.precise_lat,
              precise_lng = EXCLUDED.precise_lng,
              coarse_lat  = EXCLUDED.coarse_lat,
              coarse_lng  = EXCLUDED.coarse_lng,
              coarse_mode = EXCLUDED.coarse_mode,
              travel_mode = EXCLUDED.travel_mode,
              travel_lat  = EXCLUDED.travel_lat,
              travel_lng  = EXCLUDED.travel_lng`;

          // Keep the profile's privacy toggles in sync (coarse_location +
          // hide_distance). A profile row always exists (created at register).
          await sql()`INSERT INTO profiles (user_id, coarse_location, hide_distance)
            VALUES (${userId}, ${coarseLocation}, ${hideDistance})
            ON CONFLICT (user_id) DO UPDATE SET
              coarse_location = EXCLUDED.coarse_location,
              hide_distance   = EXCLUDED.hide_distance`;

          return json({
            ok: true,
            coarse_location: coarseLocation,
            travel_mode: travelMode,
            hide_distance: hideDistance,
          });
        } catch (err) {
          return errorResponse(err);
        }
      },
    },
  },
});
