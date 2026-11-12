import { AccessGateError } from "./closed-test";
import { RatingError } from "~/lib/ratings";
import { AuthError } from "~/lib/auth";
import { ChatError } from "~/lib/chat";
import { ModerationError } from "~/lib/moderation";

/**
 * BEEF — API route response helpers (server-only).
 */

/** JSON response with a fixed Content-Type and no-store (auth payloads). */
export function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...(init.headers ?? {}),
    },
  });
}

export const MAX_JSON_BYTES = 64 * 1024;

/** Bound streamed bytes even when Content-Length is missing or dishonest. */
export async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  const length = request.headers.get("content-length");
  if (length !== null && (!/^\d+$/.test(length) || Number(length) > MAX_JSON_BYTES)) {
    try { await request.body?.cancel(); } catch { /* already closed */ }
    return null;
  }
  if (!request.body) return null;
  const reader = request.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let bytes = 0;
  let text = "";
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_JSON_BYTES) { await reader.cancel(); return null; }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    const parsed: unknown = JSON.parse(text);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown> : null;
  } catch {
    try { await reader.cancel(); } catch { /* already closed */ }
    return null;
  } finally { reader.releaseLock(); }
}

/** Turn a thrown error into a JSON response (AuthError carries status/code). */
export function errorResponse(err: unknown): Response {
  if (err instanceof AuthError || err instanceof AccessGateError) {
    return json({ error: err.code, message: err.message }, { status: err.status });
  }
  if (err instanceof ChatError || err instanceof RatingError) {
    return json({ error: err.code, message: err.message }, { status: err.status });
  }
  if (err instanceof ModerationError) {
    return json({ error: err.code, message: err.message }, { status: err.status });
  }
  if (err instanceof Error && err.message.includes("users_assert_adult")) {
    return json(
      { error: "underage", message: "You must be at least 18 years old to use BEEF." },
      { status: 403 }
    );
  }
  if ((err as { constraint?: string })?.constraint === 'message_safety_hold') {
    return json({ error: 'specialized_review_required', message: 'This content requires specialized safety review.' }, { status: 409 });
  }
  // Don't leak internal error details.
  console.error("[api] unhandled error:", err);
  return json({ error: "internal", message: "Something went wrong." }, { status: 500 });
}
