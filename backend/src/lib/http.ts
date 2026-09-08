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

/** Parse a JSON request body, returning null when absent/invalid. */
export async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const text = await request.text();
    if (!text) return null;
    const parsed: unknown = JSON.parse(text);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

/** Turn a thrown error into a JSON response (AuthError carries status/code). */
export function errorResponse(err: unknown): Response {
  if (err instanceof AuthError) {
    return json({ error: err.code, message: err.message }, { status: err.status });
  }
  if (err instanceof ChatError) {
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
  // Don't leak internal error details.
  console.error("[api] unhandled error:", err);
  return json({ error: "internal", message: "Something went wrong." }, { status: 500 });
}
