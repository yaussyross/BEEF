/**
 * BEEF — privacy & geolocation primitives (server-only).
 *
 * The anti-Grindr architecture has one hard rule: precise lat/lng never leaves
 * the server. This module centralises the two transformations that enforce it:
 *
 *   1. coarseCentroid() — blurs a precise point into a coarse centroid. The
 *      proximity grid ALWAYS queries the coarse centroid (locations.coarse_geog).
 *      "exact" mode stores the precise point as the coarse centroid (the user
 *      explicitly opts into exact placement); "city"/"region" quantise the point
 *      to a fixed grid so neighbours in the same cell collapse to one centroid.
 *
 *   2. distanceLabel() — converts a computed distance (miles) into a string that
 *      is safe to return to another user: a bucket, or (only when the remote has
 *      opted to reveal exact via coarse_location='exact' AND not hidden) a
 *      rounded figure. It NEVER returns raw coordinates.
 */

export const INTENT_TAGS = ["friends", "chat", "date", "hookup"] as const;
export type IntentTag = (typeof INTENT_TAGS)[number];

export const COARSE_MODES = ["exact", "city", "region"] as const;
export type CoarseMode = (typeof COARSE_MODES)[number];

export function isIntentTag(value: unknown): value is IntentTag {
  return typeof value === "string" && (INTENT_TAGS as readonly string[]).includes(value);
}

export function isCoarseMode(value: unknown): value is CoarseMode {
  return typeof value === "string" && (COARSE_MODES as readonly string[]).includes(value);
}

/** Latitude must be within [-90, 90]. */
export function isValidLat(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= -90 && value <= 90;
}

/** Longitude must be within [-180, 180]. */
export function isValidLng(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= -180 && value <= 180;
}

/**
 * Quantisation cell size (in degrees of lat/lng) for coarse modes. These are
 * approximations without a server-side gazetteer — deliberately dependency-free
 * and privacy-safe (no third-party geocoder ever receives a location). Swap in
 * a real city/region centroid lookup later; keep the "no location leaves the
 * server" invariant.
 */
const CITY_STEP_DEG = 0.1; // ~7 mi / 11 km — city scale
const REGION_STEP_DEG = 0.5; // ~35 mi / 55 km — regional scale

function quantizeCenter(value: number, step: number): number {
  return (Math.floor(value / step) + 0.5) * step;
}

function round6(value: number): number {
  return Math.round(value * 1e6) / 1e6;
}

/**
 * Compute the coarse centroid for a precise point given the chosen mode.
 * - exact  → the precise point itself (user opted into exact grid placement)
 * - city   → quantised to a city-scale cell centre
 * - region → quantised to a regional-scale cell centre
 */
export function coarseCentroid(
  mode: CoarseMode,
  lat: number,
  lng: number
): { lat: number; lng: number } {
  if (mode === "exact") {
    return { lat: round6(lat), lng: round6(lng) };
  }
  const step = mode === "city" ? CITY_STEP_DEG : REGION_STEP_DEG;
  return {
    lat: round6(quantizeCenter(lat, step)),
    lng: round6(quantizeCenter(lng, step)),
  };
}

/**
 * Convert a computed distance (miles) into the only representation a *viewer*
 * may receive about the *remote* user.
 *
 * - hide_distance → "nearby" (no numeric distance at all)
 * - coarse_location === "exact" → the remote opted to reveal exact distance,
 *   returned rounded to 0.1 mi (~160 m) so no precise figure leaks
 * - otherwise → a coarse bucket (anti-triangulation: sort order inside a bucket
 *   is freshness, not sub-bucket distance)
 *
 * The bucket boundaries MUST stay in sync with the `bucket_rank` CASE expression
 * in src/routes/api/grid.ts (used only for ordering, not returned).
 */
export function distanceLabel(distanceMi: number, coarseLocation: string, hideDistance: boolean): string {
  if (hideDistance) return "nearby";
  if (coarseLocation === "exact") {
    return `${Math.max(0, distanceMi).toFixed(1)} mi`;
  }
  if (distanceMi < 1) return "<1 mi";
  if (distanceMi < 5) return "1–5 mi";
  if (distanceMi < 20) return "5–20 mi";
  if (distanceMi < 50) return "20–50 mi";
  return "50+ mi";
}

/** Whole-year age from an ISO `YYYY-MM-DD` birthdate (returns -1 if invalid). */
export function ageYears(birthdate: string): number {
  const bd = new Date(`${birthdate}T00:00:00Z`);
  if (Number.isNaN(bd.getTime())) return -1;
  const today = new Date();
  let age = today.getUTCFullYear() - bd.getUTCFullYear();
  const m = today.getUTCMonth() - bd.getUTCMonth();
  if (m < 0 || (m === 0 && today.getUTCDate() < bd.getUTCDate())) age -= 1;
  return age;
}

/**
 * Coarse age bucket for a birthdate. The DB 18+ gate guarantees every active
 * user is an adult, but the bucket is still derived (not asserted) so a
 * sanitised public profile never needs to carry the raw birthdate.
 */
export function ageBucket(birthdate: string): string {
  const age = ageYears(birthdate);
  if (age < 0) return "unknown";
  if (age < 25) return "18–24";
  if (age < 30) return "25–29";
  if (age < 40) return "30–39";
  if (age < 50) return "40–49";
  return "50+";
}
