import { sql } from "~/db";

/**
 * BEEF — "Sauce Check" moderation pipeline (server-only).
 *
 * The store-approval story in one module: UGC is screened the moment it arrives,
 * anything saucy-not-smutty is auto-blurred and queued for human review with a
 * friendly re-do prompt — never ban-by-default. Two layers, as planned:
 *
 *   1. Text screening (`screenText`) — cheap, always-on, zero network. A
 *      keyword/pattern classifier over three buckets:
 *        - commercial_solicitation (FOSTA / paid sex)  → BLOCK the write
 *        - hate_or_abuse (slurs / abuse)               → BLOCK the write
 *        - suggestive (explicit / suggestive terms)    → FLAG (blur + review)
 *      Verdicts are allow | flag | block. This is a heuristic first pass; human
 *      review + user reporting are the real enforcement, and the keyword lists
 *      should be reviewed for store policy before launch.
 *
 *   2. Image screening (`moderateImage`) — server-side hook that calls a cloud
 *      vision API (Google Cloud Vision SafeSearch) for adult/racy/violence
 *      scoring. PRIVACY-FIRST: it sends ONLY the image bytes plus an opaque
 *      content id (a photo uuid) — never a user id, never any location. When
 *      `IMAGE_MODERATION_API_KEY` is absent (or the call fails) the verdict is
 *      `pending_human`: the upload is NOT blocked, the photo stays blurred and
 *      is queued for human review.
 *
 *   3. Queue consumption + review actions (`listModerationQueue`,
 *      `applyReviewDecision`) — the human reviewer approves / rejects / blurs /
 *      bans, and the effect is applied to the right table (profiles,
 *      profile_photos, chat_messages) while the queue item is marked reviewed.
 */

// ---------------------------------------------------------------------------
// Text screening
// ---------------------------------------------------------------------------

export type TextVerdict = "allow" | "flag" | "block";

export interface TextScreenResult {
  verdict: TextVerdict;
  /** Stable machine codes: commercial_solicitation | hate_or_abuse | suggestive. */
  reasons: string[];
}

const REASON_COMMERCIAL = "commercial_solicitation";
const REASON_ABUSE = "hate_or_abuse";
const REASON_SUGGESTIVE = "suggestive";

/**
 * Commercial sexual solicitation / paid sex — a FOSTA flag and a terms
 * violation. BLOCK on arrival. (Terms prohibit commercial solicitation.)
 */
const COMMERCIAL_TERMS = [
  "escort",
  "escorts",
  "escorting",
  "pay for play",
  "pay to play",
  "pay for sex",
  "ppm",
  "pay per meet",
  "incall",
  "outcall",
  "in call",
  "out call",
  "sugar daddy",
  "sugar baby",
  "sugar daddies",
  "roses",
  "donation",
  "donations",
  "generous",
  "generosity",
  "cashapp",
  "cash app",
  "venmo",
  "zelle",
  "book me",
  "hire me",
  "selling",
  "for sale",
  "rate sheet",
  "full service",
  "gfe",
  "pse",
];

/** Slurs / hate / abuse — BLOCK on arrival (store rules treat these as hate). */
const ABUSE_TERMS = [
  "faggot",
  "fag",
  "fags",
  "tranny",
  "trannies",
  "shemale",
  "nigger",
  "nigga",
  "niggas",
  "spic",
  "chink",
  "kike",
  "wetback",
  "coon",
  "gook",
  "raghead",
  "retard",
  "retarded",
  "kill yourself",
  "kys",
  "go kill yourself",
  "end yourself",
];

/**
 * Explicit / suggestive terms — the "saucy, not smutty" line. FLAG (auto-blur +
 * human review), NOT block: the user gets a friendly re-do prompt. Role /
 * identity vocabulary (top, bottom, vers, hung, daddy, twink, bear, …) is
 * deliberately ABSENT — that is ordinary gay-dating language, not explicit.
 */
const SUGGESTIVE_TERMS = [
  "cock",
  "cocks",
  "dick",
  "dicks",
  "pussy",
  "cunt",
  "penis",
  "vagina",
  "anus",
  "fuck",
  "fucking",
  "fucks",
  "fucked",
  "fucker",
  "cum",
  "cumming",
  "jizz",
  "sperm",
  "load",
  "loads",
  "blowjob",
  "blow job",
  "blowjobs",
  "rimjob",
  "rim job",
  "handjob",
  "hand job",
  "bareback",
  "raw dog",
  "rawdog",
  "creampie",
  "cream pie",
  "breeding",
  "breed",
  "suck my",
  "sucking",
  "suck dick",
  "eat ass",
  "eating ass",
  "dildo",
  "dildos",
  "vibrator",
  "strap-on",
  "strapon",
  "threesome",
  "orgy",
  "gangbang",
  "gang bang",
];

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Word-boundary alternation over a term list (whole-word / whole-phrase). */
function wordPattern(terms: readonly string[]): RegExp {
  const alt = terms.map(escapeRegex).join("|");
  return new RegExp(`\\b(?:${alt})\\b`, "i");
}

const COMMERCIAL_RE = wordPattern(COMMERCIAL_TERMS);
const ABUSE_RE = wordPattern(ABUSE_TERMS);
const SUGGESTIVE_RE = wordPattern(SUGGESTIVE_TERMS);
// "$100", "$ 100", "$50" — an explicit money ask is the strongest paid-sex signal.
const MONEY_RE = /\$\s?\d+/;

/**
 * Classify a piece of UGC text. Pure + synchronous (no DB, no network) so it can
 * run on every write without adding latency. Verdict priority: block > flag >
 * allow. The reasons list explains the verdict for the audit trail.
 */
export function screenText(text: string): TextScreenResult {
  const reasons: string[] = [];
  if (typeof text !== "string" || text.trim().length === 0) {
    return { verdict: "allow", reasons };
  }

  const normalized = text.trim().toLowerCase();

  if (MONEY_RE.test(normalized) || COMMERCIAL_RE.test(normalized)) {
    reasons.push(REASON_COMMERCIAL);
  }
  if (ABUSE_RE.test(normalized)) {
    reasons.push(REASON_ABUSE);
  }
  if (reasons.length > 0) {
    return { verdict: "block", reasons };
  }

  if (SUGGESTIVE_RE.test(normalized)) {
    return { verdict: "flag", reasons: [REASON_SUGGESTIVE] };
  }

  return { verdict: "allow", reasons };
}

// ---------------------------------------------------------------------------
// Image screening (cloud vision hook — env-gated, privacy-first)
// ---------------------------------------------------------------------------

export type ImageVerdict = "approved" | "rejected" | "pending_human";

export interface ImageModerationInput {
  /** Opaque content identifier (a photo uuid). Never a user id, never location. */
  contentId: string;
  imageBytes: Uint8Array;
  mimeType?: string;
}

export interface ImageModerationResult {
  verdict: ImageVerdict;
  reasons: string[];
  requiresHumanReview: boolean;
  adultLikelihood?: string;
  racyLikelihood?: string;
  violenceLikelihood?: string;
  /** 0..1 numeric score (max likelihood) for profile_photos.moderation_score. */
  score: number | null;
  error?: string;
}

/** Google Cloud Vision SafeSearch likelihood values (highest-first). */
const LIKELIHOOD_SCORE: Record<string, number | null> = {
  VERY_LIKELY: 1,
  LIKELY: 0.8,
  POSSIBLE: 0.5,
  UNLIKELY: 0.2,
  VERY_UNLIKELY: 0,
  UNKNOWN: null,
};

const VISION_ENDPOINT = "https://vision.googleapis.com/v1/images:annotate";

interface SafeSearchAnnotation {
  adult?: string;
  racy?: string;
  violence?: string;
}
interface VisionResponse {
  responses?: { safeSearchAnnotation?: SafeSearchAnnotation }[];
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function scoreSafeSearch(ann: SafeSearchAnnotation): ImageModerationResult {
  const adult = ann.adult ?? "UNKNOWN";
  const racy = ann.racy ?? "UNKNOWN";
  const violence = ann.violence ?? "UNKNOWN";

  const reasons: string[] = [];
  let verdict: ImageVerdict = "approved";
  for (const { label, value } of [
    { label: "adult", value: adult },
    { label: "racy", value: racy },
    { label: "violence", value: violence },
  ]) {
    if (value === "LIKELY" || value === "VERY_LIKELY") {
      verdict = "rejected";
      reasons.push(`${label}_${value.toLowerCase()}`);
    } else if (value === "POSSIBLE" && verdict === "approved") {
      verdict = "pending_human";
      reasons.push(`${label}_possible`);
    }
  }

  const scores = [adult, racy, violence]
    .map((v) => LIKELIHOOD_SCORE[v] ?? null)
    .filter((s): s is number => s !== null);
  const score = scores.length > 0 ? Math.max(...scores) : null;

  return {
    verdict,
    reasons,
    requiresHumanReview: verdict !== "approved",
    adultLikelihood: adult,
    racyLikelihood: racy,
    violenceLikelihood: violence,
    score,
  };
}

/**
 * Screen an image against the cloud vision API (SafeSearch adult/racy/violence).
 *
 * Privacy-first invariant: the ONLY data that leaves the server is the image
 * bytes and the opaque `contentId`. No user id, no profile data, and — the hard
 * rule — no location of any kind.
 *
 * Env-gated: when `IMAGE_MODERATION_API_KEY` is unset (or the call fails) this
 * returns `pending_human` rather than rejecting — uploads are never blocked by
 * a missing key; they stay blurred and queue for human review.
 */
export async function moderateImage(input: ImageModerationInput): Promise<ImageModerationResult> {
  const apiKey = process.env.IMAGE_MODERATION_API_KEY;
  if (!apiKey) {
    return {
      verdict: "pending_human",
      reasons: ["image_moderation_key_unset"],
      requiresHumanReview: true,
      score: null,
    };
  }

  try {
    const resp = await fetch(`${VISION_ENDPOINT}?key=${encodeURIComponent(apiKey)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        requests: [
          {
            image: { content: bytesToBase64(input.imageBytes) },
            features: [{ type: "SAFE_SEARCH_DETECTION" }],
          },
        ],
      }),
    });

    if (!resp.ok) {
      return {
        verdict: "pending_human",
        reasons: ["vision_api_error"],
        requiresHumanReview: true,
        score: null,
        error: `vision_api_status_${resp.status}`,
      };
    }

    const data = (await resp.json()) as VisionResponse;
    const ann = data.responses?.[0]?.safeSearchAnnotation;
    if (!ann) {
      return {
        verdict: "pending_human",
        reasons: ["vision_api_no_annotation"],
        requiresHumanReview: true,
        score: null,
      };
    }
    return scoreSafeSearch(ann);
  } catch (err) {
    return {
      verdict: "pending_human",
      reasons: ["vision_api_error"],
      requiresHumanReview: true,
      score: null,
      error: err instanceof Error ? err.message : "unknown",
    };
  }
}

// ---------------------------------------------------------------------------
// Moderation queue + review actions (shared by routes)
// ---------------------------------------------------------------------------

export type ModerationTargetType = "profile" | "photo" | "message";
export type ModerationSource = "auto" | "user_report";
export type ReviewDecision = "approve" | "reject" | "blur" | "ban";

/** Domain error carrying an HTTP status + stable machine code. */
export class ModerationError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/**
 * Internal admin gate for the moderation routes. Uses a shared secret header
 * (`X-Moderation-Key`) checked against `MODERATION_ADMIN_KEY` — deliberately NOT
 * a user-JWT role, since the schema has no role column yet. 503 when the key is
 * unconfigured (the route must not accidentally be open), 401 when it's missing
 * or wrong.
 */
export function requireModerationAdmin(request: Request): void {
  const key = process.env.MODERATION_ADMIN_KEY;
  if (!key || key.length < 16) {
    throw new ModerationError(
      503,
      "moderation_not_configured",
      "MODERATION_ADMIN_KEY is not set — moderation routes are disabled."
    );
  }
  const provided = request.headers.get("x-moderation-key") ?? "";
  if (provided !== key) {
    throw new ModerationError(401, "forbidden", "Invalid or missing moderation key.");
  }
}

/** Insert one pending item into the moderation queue. */
export async function enqueueModeration(
  targetType: ModerationTargetType,
  targetId: string,
  source: ModerationSource,
  reason: string
): Promise<void> {
  await sql()`INSERT INTO moderation_queue (target_type, target_id, source, reason, status)
             VALUES (${targetType}, ${targetId}, ${source}, ${reason}, 'pending')`;
}

/**
 * Apply an image verdict to a profile photo. Approved photos go live; rejected
 * photos are removed; anything uncertain (or no-key) stays pending + blurred and
 * queues for human review — never ban-by-default.
 */
export async function applyPhotoVerdict(
  photoId: string,
  result: ImageModerationResult
): Promise<void> {
  const score = result.score ?? null;
  if (result.verdict === "approved") {
    await sql()`UPDATE profile_photos
               SET status = 'approved', moderation_score = ${score}
               WHERE id = ${photoId}`;
    return;
  }
  if (result.verdict === "rejected") {
    await sql()`UPDATE profile_photos
               SET status = 'rejected', moderation_score = ${score}
               WHERE id = ${photoId}`;
    await enqueueModeration("photo", photoId, "auto", `image_${result.reasons.join("_")}`);
    return;
  }
  // pending_human — keep it blurred (pending) and queue for a human.
  await sql()`UPDATE profile_photos
             SET status = 'pending', moderation_score = ${score}
             WHERE id = ${photoId}`;
  await enqueueModeration("photo", photoId, "auto", "image_needs_human_review");
}

/** Convenience: screen a photo and immediately persist its verdict. */
export async function moderatePhoto(
  photoId: string,
  imageBytes: Uint8Array,
  mimeType?: string
): Promise<ImageModerationResult> {
  const result = await moderateImage({ contentId: photoId, imageBytes, mimeType });
  await applyPhotoVerdict(photoId, result);
  return result;
}

export interface QueueItem {
  id: string;
  target_type: string;
  target_id: string;
  source: string;
  reason: string | null;
  status: string;
  created_at: string;
  /** Human-readable snapshot of the offending content (never any location). */
  target_detail: string | null;
  /** Owning user id where resolvable — lets the reviewer ban. */
  target_user_id: string | null;
}

function truncate(value: string, max = 240): string {
  return value.length > max ? `${value.slice(0, max)}…` : value;
}

/** List the moderation queue, enriched with a snapshot of the flagged content. */
export async function listModerationQueue(options: {
  status?: string;
  targetType?: ModerationTargetType;
  limit?: number;
  offset?: number;
}): Promise<QueueItem[]> {
  const status = options.status ?? "pending";
  const limit = Math.min(Math.max(1, options.limit ?? 50), 100);
  const offset = Math.max(0, options.offset ?? 0);
  const targetType = options.targetType ?? null;

  const rows = (await sql()`SELECT id, target_type, target_id, source, reason, status,
                                created_at::text AS created_at
                         FROM moderation_queue
                         WHERE status = ${status}
                           AND (${targetType}::moderation_target IS NULL OR target_type = ${targetType})
                         ORDER BY created_at ASC
                         LIMIT ${limit} OFFSET ${offset}`) as unknown as {
    id: string;
    target_type: string;
    target_id: string;
    source: string;
    reason: string | null;
    status: string;
    created_at: string;
  }[];

  if (rows.length === 0) return [];

  const profileIds = rows.filter((r) => r.target_type === "profile").map((r) => r.target_id);
  const photoIds = rows.filter((r) => r.target_type === "photo").map((r) => r.target_id);
  const messageIds = rows.filter((r) => r.target_type === "message").map((r) => r.target_id);

  const profileDetail = new Map<string, { detail: string; userId: string | null }>();
  if (profileIds.length > 0) {
    const pr = (await sql()`SELECT id, user_id::text AS user_id,
                                   COALESCE(display_name, '') AS display_name,
                                   COALESCE(bio, '') AS bio
                            FROM profiles
                            WHERE id = ANY(${profileIds}::uuid[])`) as unknown as {
      id: string;
      user_id: string;
      display_name: string;
      bio: string;
    }[];
    for (const p of pr) {
      profileDetail.set(p.id, {
        detail: truncate([p.display_name, p.bio].filter(Boolean).join(" — ") || "(no bio)"),
        userId: p.user_id,
      });
    }
  }

  const photoDetail = new Map<string, { detail: string; userId: string | null }>();
  if (photoIds.length > 0) {
    const phr = (await sql()`SELECT pp.id, pp.storage_key, pp.status,
                                    p.user_id::text AS user_id
                             FROM profile_photos pp
                             JOIN profiles p ON p.id = pp.profile_id
                             WHERE pp.id = ANY(${photoIds}::uuid[])`) as unknown as {
      id: string;
      storage_key: string;
      status: string;
      user_id: string;
    }[];
    for (const ph of phr) {
      photoDetail.set(ph.id, { detail: `photo ${ph.storage_key} (status: ${ph.status})`, userId: ph.user_id });
    }
  }

  const messageDetail = new Map<string, { detail: string; userId: string | null }>();
  if (messageIds.length > 0) {
    const mr = (await sql()`SELECT id, sender_id::text AS sender_id, body
                           FROM chat_messages
                           WHERE id = ANY(${messageIds}::uuid[])`) as unknown as {
      id: string;
      sender_id: string;
      body: string;
    }[];
    for (const m of mr) {
      messageDetail.set(m.id, { detail: truncate(m.body), userId: m.sender_id });
    }
  }

  return rows.map((r) => {
    const lookup =
      r.target_type === "profile"
        ? profileDetail.get(r.target_id)
        : r.target_type === "photo"
          ? photoDetail.get(r.target_id)
          : messageDetail.get(r.target_id);
    return {
      id: r.id,
      target_type: r.target_type,
      target_id: r.target_id,
      source: r.source,
      reason: r.reason,
      status: r.status,
      created_at: r.created_at,
      target_detail: lookup?.detail ?? null,
      target_user_id: lookup?.userId ?? null,
    };
  });
}

/** Resolve the owning user id for a moderation target (for the ban action). */
async function resolveTargetUser(targetType: string, targetId: string): Promise<string | null> {
  if (targetType === "profile") {
    const r = (await sql()`SELECT user_id::text AS user_id FROM profiles WHERE id = ${targetId} LIMIT 1`) as
      { user_id: string }[];
    return r[0]?.user_id ?? null;
  }
  if (targetType === "photo") {
    const r = (await sql()`SELECT p.user_id::text AS user_id
                          FROM profile_photos pp
                          JOIN profiles p ON p.id = pp.profile_id
                          WHERE pp.id = ${targetId} LIMIT 1`) as { user_id: string }[];
    return r[0]?.user_id ?? null;
  }
  if (targetType === "message") {
    const r = (await sql()`SELECT sender_id::text AS sender_id FROM chat_messages WHERE id = ${targetId} LIMIT 1`) as
      { sender_id: string }[];
    return r[0]?.sender_id ?? null;
  }
  return null;
}

async function banUser(userId: string): Promise<void> {
  await sql()`UPDATE users SET status = 'banned' WHERE id = ${userId}`;
  await sql()`UPDATE profiles SET moderation_status = 'banned' WHERE user_id = ${userId}`;
}

/**
 * Apply a human review decision to the queued target, then mark the queue item
 * reviewed. "Blur" is the Sauce Check default tone: keep the content but behind
 * a blur + re-do prompt, never an automatic ban.
 */
export async function applyReviewDecision(
  queueId: string,
  decision: ReviewDecision,
  reviewerId: string | null = null
): Promise<{ target_type: string; target_id: string; applied: string }> {
  const rows = (await sql()`SELECT id, target_type, target_id, status
                           FROM moderation_queue
                           WHERE id = ${queueId}
                           LIMIT 1`) as {
    id: string;
    target_type: string;
    target_id: string;
    status: string;
  }[];
  const item = rows[0];
  if (!item) {
    throw new ModerationError(404, "not_found", "Moderation queue item not found.");
  }
  if (item.status === "approved" || item.status === "rejected") {
    throw new ModerationError(409, "already_reviewed", "This queue item has already been reviewed.");
  }

  const applied = await applyToTarget(item.target_type, item.target_id, decision);

  const finalStatus = decision === "approve" ? "approved" : "rejected";
  await sql()`UPDATE moderation_queue
             SET status = ${finalStatus},
                 reviewed_at = now(),
                 assigned_reviewer_id = ${reviewerId}
             WHERE id = ${queueId}`;

  return { target_type: item.target_type, target_id: item.target_id, applied };
}

async function applyToTarget(
  targetType: string,
  targetId: string,
  decision: ReviewDecision
): Promise<string> {
  if (targetType === "profile") {
    switch (decision) {
      case "approve":
        await sql()`UPDATE profiles SET moderation_status = 'approved' WHERE id = ${targetId}`;
        return "approved";
      case "reject":
        await sql()`UPDATE profiles SET moderation_status = 'rejected' WHERE id = ${targetId}`;
        return "rejected";
      case "blur":
        // A flagged bio has no per-field blur state — keep the profile visible
        // and prompt the owner to rewrite (Sauce Check, not a ban).
        await sql()`UPDATE profiles SET moderation_status = 'pending' WHERE id = ${targetId}`;
        return "blurred_pending_redo";
      case "ban": {
        const userId = await resolveTargetUser(targetType, targetId);
        if (userId) await banUser(userId);
        return "banned";
      }
    }
  }

  if (targetType === "photo") {
    switch (decision) {
      case "approve":
        await sql()`UPDATE profile_photos SET status = 'approved' WHERE id = ${targetId}`;
        return "approved";
      case "reject":
        await sql()`UPDATE profile_photos SET status = 'rejected' WHERE id = ${targetId}`;
        return "rejected";
      case "blur":
        await sql()`UPDATE profile_photos SET status = 'blurred' WHERE id = ${targetId}`;
        return "blurred";
      case "ban": {
        await sql()`UPDATE profile_photos SET status = 'rejected' WHERE id = ${targetId}`;
        const userId = await resolveTargetUser(targetType, targetId);
        if (userId) await banUser(userId);
        return "banned";
      }
    }
  }

  if (targetType === "message") {
    switch (decision) {
      case "approve":
        await sql()`UPDATE chat_messages SET moderation_status = 'approved' WHERE id = ${targetId}`;
        return "approved";
      case "reject":
        await sql()`UPDATE chat_messages SET moderation_status = 'rejected' WHERE id = ${targetId}`;
        return "rejected";
      case "blur":
        await sql()`UPDATE chat_messages SET moderation_status = 'blurred' WHERE id = ${targetId}`;
        return "blurred";
      case "ban": {
        await sql()`UPDATE chat_messages SET moderation_status = 'rejected' WHERE id = ${targetId}`;
        const userId = await resolveTargetUser(targetType, targetId);
        if (userId) await banUser(userId);
        return "banned";
      }
    }
  }

  throw new ModerationError(400, "invalid_target", `Unknown moderation target type: ${targetType}.`);
}
