import { verifyAccessToken, requireActiveAccount, AuthError } from "../lib/auth";
import { hub, dropSocketsForUser, type ChatSocket } from "./registry";
export type { ChatSocket } from "./registry";
import {
  ChatError,
  markThreadRead,
  sendMessage,
  type StoredMessage,
} from "../lib/chat";

/**
 * BEEF — 1:1 chat WebSocket hub (Bun).
 *
 * The plan calls for a dedicated WebSocket module on the same host (TanStack
 * Start server functions are request/response and can't hold persistent
 * sockets). This module is wired into `serve.ts`'s `Bun.serve({ websocket })`
 * at the `/api/ws` path; TLS is terminated by the host reverse proxy.
 *
 * Protocol (JSON text frames):
 *   client → server
 *     { "type": "send", "thread_id"? | "recipient_id"?, "client_message_id", "body" }
 *     { "type": "read", "thread_id" }
 *   server → client
 *     { "type": "connected", "user_id" }
 *     { "type": "ack",       "message", "duplicate" }
 *     { "type": "message",   "message" }          // delivered to recipient
 *     { "type": "read_ack",  "thread_id" }
 *     { "type": "error",     "code", "message" }
 *     { "type": "blocked",   "blocked_user_id" }  // sent before a block closes the socket
 *
 * Auth: `Authorization: Bearer <jwt>` header (native clients) or `?token=<jwt>`
 * query param (browser WebSocket can't set headers). Verified with the same
 * access-token verifier as every REST route.
 *
 * The live socket registry lives on `globalThis` so the REST block route (which
 * runs inside the *bundled* TanStack handler in dist/server/server.js) reaches
 * the SAME registry that these Bun-level callbacks use. Two module instances,
 * one process, one shared registry — no cross-bundle state fork.
 */

// --- Minimal structural types for Bun's WebSocket surface ---------------------
// Socket handlers use a narrow structural surface; upgrades use Bun's actual
// contract, including the authenticated userId already supplied at the call site.

export type ChatServer = Pick<Bun.Server<{ userId: string }>, "upgrade">;

const OPEN = 1;

// -----------------------------------------------------------------------------
// Live socket registry (process-wide singleton).
// -----------------------------------------------------------------------------

function register(userId: string, ws: ChatSocket): void {
  let set = hub().get(userId);
  if (!set) hub().set(userId, (set = new Set()));
  set.add(ws);
}

function unregister(ws: ChatSocket): void {
  const userId = ws.data?.userId;
  if (!userId) return;
  const set = hub().get(userId);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) hub().delete(userId);
}

async function sendToUser(userId: string, payload: unknown): Promise<void> {
  // Recheck at delivery as well as at send/read: an idle recipient may have
  // been disabled after connecting, including by another server process.
  await requireActiveAccount(userId);
  const set = hub().get(userId);
  if (!set) return;
  const text = JSON.stringify(payload);
  for (const ws of [...set]) {
    try {
      if (ws.readyState === OPEN) ws.send(text);
    } catch {
      // Half-dead socket — drop it so we don't retry it next time.
      set.delete(ws);
    }
  }
}

/** True when the user has at least one live socket (offline-path indicator). */
export function isUserOnline(userId: string): boolean {
  return (hub().get(userId)?.size ?? 0) > 0;
}

/**
 * Force-close every live socket for both users, notifying each why. Called by
 * the block route so a block takes effect immediately rather than on the next
 * message. Server-side enforcement in the read/send path is the durable guard;
 * this is the immediate one.
 */
export function dropSocketsForPair(a: string, b: string): void {
  for (const [userId, other] of [
    [a, b],
    [b, a],
  ] as const) {
    const set = hub().get(userId);
    if (!set) continue;
    for (const ws of [...set]) {
      try {
        ws.send(JSON.stringify({ type: "blocked", blocked_user_id: other }));
        ws.close(4000, "blocked");
      } catch {
        // ignore
      }
    }
    hub().delete(userId);
  }
}

// -----------------------------------------------------------------------------
// Upgrade handling (auth happens here, before the socket is created).
// -----------------------------------------------------------------------------

function wsResponse(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: code, message }), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/**
 * Authenticate and upgrade an HTTP request to the chat WebSocket. Returns a
 * JSON error Response on failure, or `undefined` after a successful upgrade.
 */
export async function handleChatUpgrade(
  req: Request,
  server: ChatServer
): Promise<Response | undefined> {
  const url = new URL(req.url);

  let token: string | null = null;
  const authHeader = req.headers.get("authorization");
  const bearer = /^Bearer\s+(.+)$/i.exec(authHeader ?? "");
  if (bearer) token = bearer[1].trim();
  if (!token) token = url.searchParams.get("token");
  if (!token) {
    return wsResponse(401, "missing_token", "Missing token.");
  }

  let userId: string;
  try {
    userId = await verifyAccessToken(token);
    await requireActiveAccount(userId);
  } catch (err) {
    if (err instanceof AuthError) return wsResponse(err.status, err.code, err.message);
    return wsResponse(401, "invalid_token", "Invalid or expired token.");
  }

  const upgraded = server.upgrade(req, { data: { userId } });
  if (!upgraded) {
    return wsResponse(500, "upgrade_failed", "WebSocket upgrade failed.");
  }
  return undefined;
}

// -----------------------------------------------------------------------------
// Client message parsing + routing.
// -----------------------------------------------------------------------------

interface SendMessage {
  thread_id?: string;
  recipient_id?: string;
  client_message_id: string;
  body: string;
}

type ClientMessage = ({ type: "send" } & SendMessage) | { type: "read"; thread_id: string };

function parseClientMessage(raw: string): ClientMessage | { type: "invalid" } {
  try {
    const obj: unknown = JSON.parse(raw);
    if (!obj || typeof obj !== "object" || typeof (obj as { type?: unknown }).type !== "string") {
      return { type: "invalid" };
    }
    return obj as ClientMessage;
  } catch {
    return { type: "invalid" };
  }
}

function toWireMessage(m: StoredMessage): Record<string, unknown> {
  return {
    id: m.id,
    thread_id: m.thread_id,
    sender_id: m.sender_id,
    client_message_id: m.client_message_id,
    body: m.body,
    moderation_status: m.moderation_status,
    created_at: m.created_at,
  };
}

async function handleSend(senderId: string, msg: SendMessage): Promise<void> {
  const result = await sendMessage(senderId, {
    threadId: msg.thread_id,
    recipientId: msg.recipient_id,
    clientMessageId: msg.client_message_id,
    body: msg.body,
  });

  const message = toWireMessage(result.message);

  // Ack to the sender (idempotent: same payload for a new send or a retry).
  await sendToUser(senderId, { type: "ack", message, duplicate: !result.created });

  // Deliver to the recipient if live. Offline is fine — the message is already
  // persisted; they hydrate history on reconnect.
  // Recipient availability must never close or mislabel the sender's session.
  try {
    await sendToUser(result.recipientId, { type: "message", message });
  } catch (error) {
    if (!(error instanceof AuthError)) throw error;
  }
}

// -----------------------------------------------------------------------------
// The `websocket` handler object passed to Bun.serve.
// -----------------------------------------------------------------------------

export const chatWebSocketHandlers = {
  async open(ws: ChatSocket): Promise<void> {
    const userId = ws.data?.userId;
    if (!userId) {
      try {
        ws.close(4001, "unauthorized");
      } catch {
        // ignore
      }
      return;
    }
    register(userId, ws);
    try {
      await requireActiveAccount(userId);
      if (hub().get(userId)?.has(ws) && ws.readyState === OPEN) {
        ws.send(JSON.stringify({ type: "connected", user_id: userId }));
      }
    } catch {
      unregister(ws);
      try { ws.close(4001, "account_unavailable"); } catch { /* already closed */ }
    }
  },

  async message(ws: ChatSocket, raw: string | Uint8Array): Promise<void> {
    const userId = ws.data?.userId;
    if (!userId) return;

    const text = typeof raw === "string" ? raw : new TextDecoder().decode(raw);
    const msg = parseClientMessage(text);
    if (msg.type === "invalid") {
      ws.send(JSON.stringify({ type: "error", code: "invalid_message", message: "Malformed message." }));
      return;
    }

    try {
      await requireActiveAccount(userId);
      if (msg.type === "send") {
        await handleSend(userId, msg);
      } else if (msg.type === "read") {
        await markThreadRead(userId, msg.thread_id);
        await sendToUser(userId, { type: "read_ack", thread_id: msg.thread_id });
      }
    } catch (err) {
      const payload =
        err instanceof ChatError || err instanceof AuthError
          ? { type: "error", code: err.code, message: err.message }
          : { type: "error", code: "internal", message: "Something went wrong." };
      try {
        ws.send(JSON.stringify(payload));
      } catch {
        // ignore
      }
      if (err instanceof AuthError) dropSocketsForUser(userId);
      else if (!(err instanceof ChatError)) console.error("[ws] send error:", err);
    }
  },

  close(ws: ChatSocket): void {
    unregister(ws);
  },
};
