import { sql } from "../db";
import { enqueueModeration, screenText } from "./moderation";

/**
 * BEEF — chat domain logic (server-only). Shared by the REST hydration routes
 * (`/api/threads*`) and the WebSocket hub (`src/ws/chat.ts`) so the two paths
 * can never diverge on the rules that matter.
 *
 * Privacy-first invariants enforced here:
 *   - A 1:1 thread is keyed by the sorted pair of participant ids; there is at
 *     most one thread per unordered pair (chat_threads.participant_low/high).
 *   - A block is enforced in BOTH directions on every read and every send.
 *   - Chat payloads carry message/thread metadata only — never location data.
 */

export const MAX_MESSAGE_LENGTH = 4000;
export const MAX_CLIENT_MESSAGE_ID_LENGTH = 128;
export const MAX_HISTORY_PAGE = 100;

/** A domain error carrying an HTTP status + stable machine code. */
export class ChatError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export interface StoredMessage {
  id: string;
  thread_id: string;
  sender_id: string;
  client_message_id: string;
  body: string;
  moderation_status: string;
  created_at: string;
}

export interface ThreadRow {
  id: string;
  participant_low: string;
  participant_high: string;
  created_at: string;
  last_message_at: string | null;
}

export interface ThreadSummary {
  id: string;
  other_user_id: string;
  other_display_name: string | null;
  other_photo_verification_status: string;
  last_message: {
    id: string;
    sender_id: string;
    body: string;
    moderation_status: string;
    created_at: string;
  } | null;
  last_message_at: string | null;
  last_read_at: string | null;
  unread_count: number;
}

/** Sort two user ids into (low, high) — the canonical thread key. */
export function sortedPair(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}

/** The other participant of a 1:1 thread, given one participant id. */
export function otherParticipant(
  thread: { participant_low: string; participant_high: string },
  userId: string
): string {
  return thread.participant_low === userId ? thread.participant_high : thread.participant_low;
}

/** True when a block exists in either direction (both sides are blind). */
export async function isBlockedEither(a: string, b: string): Promise<boolean> {
  if (a === b) return false;
  const rows = await sql()`SELECT 1 AS x
                         FROM blocks
                         WHERE (blocker_id = ${a} AND blocked_id = ${b})
                            OR (blocker_id = ${b} AND blocked_id = ${a})
                         LIMIT 1`;
  return rows.length > 0;
}

/** True when `id` is an active (non-deleted/suspended/banned) user. */
export async function isActiveUser(id: string): Promise<boolean> {
  const rows = await sql()`SELECT 1 AS x FROM users WHERE id = ${id} AND status = 'active' LIMIT 1`;
  return rows.length > 0;
}

/**
 * Find the 1:1 thread between two users, or create it lazily. The insert uses
 * ON CONFLICT DO NOTHING on the unique pair index, so a concurrent create races
 * safely to a single thread; participant rows are only inserted when the thread
 * was actually newly created.
 */
export async function getOrCreateThread(userId: string, otherId: string): Promise<ThreadRow> {
  if (userId === otherId) {
    throw new ChatError(400, "self_thread", "You can't start a thread with yourself.");
  }
  const [low, high] = sortedPair(userId, otherId);

  // Get-or-create in one statement (CTE inserts participants only on create).
  await sql()`WITH ins AS (
      INSERT INTO chat_threads (participant_low, participant_high)
      VALUES (${low}, ${high})
      ON CONFLICT (participant_low, participant_high) DO NOTHING
      RETURNING id
    ), p1 AS (
      INSERT INTO thread_participants (thread_id, user_id)
      SELECT id, ${userId} FROM ins
    ), p2 AS (
      INSERT INTO thread_participants (thread_id, user_id)
      SELECT id, ${otherId} FROM ins
    )
    SELECT 1`;

  const rows = await sql()`SELECT id, participant_low, participant_high,
                                 created_at::text AS created_at,
                                 last_message_at::text AS last_message_at
                          FROM chat_threads
                          WHERE participant_low = ${low} AND participant_high = ${high}
                          LIMIT 1`;
  const thread = rows[0] as ThreadRow | undefined;
  if (!thread) {
    throw new ChatError(500, "thread_failed", "Could not create or find the thread.");
  }
  return thread;
}

/**
 * Load a thread and assert `userId` is a participant AND not blocked in either
 * direction. This is the single choke point that every read/send path goes
 * through, so block enforcement can't be forgotten by a caller.
 */
export async function getThreadForParticipant(userId: string, threadId: string): Promise<ThreadRow> {
  const rows = await sql()`SELECT ct.id, ct.participant_low, ct.participant_high,
                                ct.created_at::text AS created_at,
                                ct.last_message_at::text AS last_message_at
                         FROM chat_threads ct
                         JOIN thread_participants tp ON tp.thread_id = ct.id AND tp.user_id = ${userId}
                         WHERE ct.id = ${threadId}
                         LIMIT 1`;
  const thread = rows[0] as ThreadRow | undefined;
  if (!thread) {
    throw new ChatError(404, "thread_not_found", "Thread not found.");
  }
  if (await isBlockedEither(userId, otherParticipant(thread, userId))) {
    throw new ChatError(403, "blocked", "You can't access this conversation.");
  }
  return thread;
}

export interface SendResult {
  message: StoredMessage;
  recipientId: string;
  /** false when this was a duplicate client_message_id (idempotent retry). */
  created: boolean;
}

/**
 * Persist a message with idempotency on (sender_id, client_message_id). A
 * duplicate client_message_id returns the already-stored row instead of
 * inserting a second copy. Enforces participation + block before persisting.
 */
export async function sendMessage(
  senderId: string,
  input: {
    threadId?: string;
    recipientId?: string;
    clientMessageId: string;
    body: string;
  }
): Promise<SendResult> {
  if (typeof input.body !== "string" || input.body.trim().length === 0) {
    throw new ChatError(400, "empty_message", "Message body is required.");
  }
  if (input.body.length > MAX_MESSAGE_LENGTH) {
    throw new ChatError(
      400,
      "message_too_long",
      `Message is too long (max ${MAX_MESSAGE_LENGTH} characters).`
    );
  }
  const clientMessageId = input.clientMessageId;
  if (
    typeof clientMessageId !== "string" ||
    clientMessageId.trim().length === 0 ||
    clientMessageId.length > MAX_CLIENT_MESSAGE_ID_LENGTH
  ) {
    throw new ChatError(400, "invalid_client_message_id", "client_message_id is required.");
  }

  let thread: ThreadRow;
  let recipientId: string;
  if (input.threadId) {
    thread = await getThreadForParticipant(senderId, input.threadId);
    recipientId = otherParticipant(thread, senderId);
  } else if (input.recipientId) {
    recipientId = input.recipientId;
    thread = await getOrCreateThread(senderId, recipientId);
  } else {
    throw new ChatError(400, "missing_target", "thread_id or recipient_id is required.");
  }

  // getThreadForParticipant already checks the block for the threadId path; this
  // covers the recipientId (lazy-create) path and is idempotent/cheap.
  if (await isBlockedEither(senderId, recipientId)) {
    throw new ChatError(403, "blocked", "You can't message this user.");
  }

  const body = input.body.trim();

  // Sauce Check (text screen) — runs on every write. Blocked content (paid sex
  // / slurs) is refused; flagged (suggestive) content is stored blurred and
  // queued for human review, never auto-banned.
  const screen = screenText(body);
  if (screen.verdict === "block") {
    throw new ChatError(403, "message_blocked", "That message can't be sent. Keep it saucy, not smutty.");
  }
  const moderationStatus = screen.verdict === "flag" ? "blurred" : "approved";

  const inserted = await sql()`INSERT INTO chat_messages
      (thread_id, sender_id, client_message_id, body, moderation_status)
    VALUES (${thread.id}, ${senderId}, ${clientMessageId}, ${body}, ${moderationStatus})
    ON CONFLICT (sender_id, client_message_id) DO NOTHING
    RETURNING id, thread_id, sender_id, client_message_id, body, moderation_status,
              created_at::text AS created_at`;

  const first = inserted[0] as StoredMessage | undefined;
  if (first) {
    if (screen.verdict === "flag") {
      await enqueueModeration("message", first.id, "auto", screen.reasons.join(","));
    }
    return { message: first, recipientId, created: true };
  }

  // Duplicate client_message_id → return the already-stored row (idempotent).
  const dup = await sql()`SELECT id, thread_id, sender_id, client_message_id, body,
                               moderation_status, created_at::text AS created_at
                         FROM chat_messages
                         WHERE sender_id = ${senderId} AND client_message_id = ${clientMessageId}
                         LIMIT 1`;
  const message = dup[0] as StoredMessage | undefined;
  if (!message) {
    throw new ChatError(500, "send_failed", "Could not persist the message.");
  }
  return { message, recipientId, created: false };
}

export interface HistoryResult {
  messages: StoredMessage[];
  next_cursor: string | null;
}

function decodeCursor(cursor: string): { createdAt: string; id: string } | null {
  const sep = cursor.lastIndexOf("|");
  if (sep <= 0 || sep === cursor.length - 1) return null;
  return { createdAt: cursor.slice(0, sep), id: cursor.slice(sep + 1) };
}

/**
 * Read a thread's history newest-first, keyset-paginated by (created_at, id).
 * The opaque `cursor` is the `next_cursor` of the previous page. Enforces
 * participation + block via getThreadForParticipant.
 */
export async function getThreadHistory(
  userId: string,
  threadId: string,
  limit = 50,
  cursor?: string
): Promise<HistoryResult> {
  const pageSize = Math.min(Math.max(1, Math.floor(limit)), MAX_HISTORY_PAGE);

  const thread = await getThreadForParticipant(userId, threadId);

  const messages =
    cursor === undefined
      ? await sql()`SELECT id, thread_id, sender_id, client_message_id, body,
                         moderation_status, created_at::text AS created_at
                  FROM chat_messages
                  WHERE thread_id = ${thread.id}
                  ORDER BY created_at DESC, id DESC
                  LIMIT ${pageSize + 1}`
      : await (() => {
          const decoded = decodeCursor(cursor);
          if (!decoded) {
            throw new ChatError(400, "invalid_cursor", "Invalid pagination cursor.");
          }
          return sql()`SELECT id, thread_id, sender_id, client_message_id, body,
                            moderation_status, created_at::text AS created_at
                     FROM chat_messages
                     WHERE thread_id = ${thread.id}
                       AND (created_at, id) < (${decoded.createdAt}::timestamptz, ${decoded.id}::uuid)
                     ORDER BY created_at DESC, id DESC
                     LIMIT ${pageSize + 1}`;
        })();

  const hasMore = messages.length > pageSize;
  const page = (messages as unknown as StoredMessage[]).slice(0, pageSize);
  const nextCursor =
    hasMore && page.length > 0 ? `${page[page.length - 1].created_at}|${page[page.length - 1].id}` : null;

  return { messages: page, next_cursor: nextCursor };
}

/** Mark a thread read up to now for a participant (updates last_read_at). */
export async function markThreadRead(userId: string, threadId: string): Promise<void> {
  await sql()`UPDATE thread_participants
             SET last_read_at = now()
             WHERE thread_id = ${threadId} AND user_id = ${userId}`;
}

/**
 * List a user's threads (inbox), newest-activity first. Excludes threads that
 * are blocked in either direction, and never returns any location data. Each
 * row carries the other participant's public summary, the last message, and an
 * unread count (messages from the other user newer than this user's last_read_at).
 */
export async function listThreads(userId: string): Promise<ThreadSummary[]> {
  const rows = await sql()`SELECT
      ct.id,
      ct.last_message_at::text AS last_message_at,
      tp.last_read_at::text AS last_read_at,
      other.id AS other_user_id,
      other_p.display_name AS other_display_name,
      other_p.photo_verification_status AS other_photo_verification_status,
      last_msg.id AS last_msg_id,
      last_msg.sender_id AS last_msg_sender_id,
      last_msg.body AS last_msg_body,
      last_msg.moderation_status AS last_msg_moderation_status,
      last_msg.created_at::text AS last_msg_created_at,
      (
        SELECT count(*)
        FROM chat_messages cm
        WHERE cm.thread_id = ct.id
          AND cm.sender_id <> ${userId}
          AND (tp.last_read_at IS NULL OR cm.created_at > tp.last_read_at)
      ) AS unread_count
    FROM thread_participants tp
    JOIN chat_threads ct ON ct.id = tp.thread_id
    JOIN thread_participants other_tp ON other_tp.thread_id = ct.id AND other_tp.user_id <> ${userId}
    JOIN users other ON other.id = other_tp.user_id
    JOIN profiles other_p ON other_p.user_id = other.id
    LEFT JOIN LATERAL (
      SELECT cm.id, cm.sender_id, cm.body, cm.moderation_status, cm.created_at
      FROM chat_messages cm
      WHERE cm.thread_id = ct.id
      ORDER BY cm.created_at DESC, cm.id DESC
      LIMIT 1
    ) last_msg ON true
    WHERE tp.user_id = ${userId}
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = ${userId} AND b.blocked_id = other.id)
           OR (b.blocker_id = other.id AND b.blocked_id = ${userId})
      )
    ORDER BY ct.last_message_at DESC NULLS LAST, ct.id DESC`;

  const summaries = rows as unknown as {
    id: string;
    last_message_at: string | null;
    last_read_at: string | null;
    other_user_id: string;
    other_display_name: string | null;
    other_photo_verification_status: string;
    last_msg_id: string | null;
    last_msg_sender_id: string | null;
    last_msg_body: string | null;
    last_msg_moderation_status: string | null;
    last_msg_created_at: string | null;
    unread_count: number;
  }[];

  return summaries.map((r) => ({
    id: r.id,
    other_user_id: r.other_user_id,
    other_display_name: r.other_display_name,
    other_photo_verification_status: r.other_photo_verification_status,
    last_message:
      r.last_msg_id === null
        ? null
        : {
            id: r.last_msg_id,
            sender_id: r.last_msg_sender_id ?? "",
            body: r.last_msg_body ?? "",
            moderation_status: r.last_msg_moderation_status ?? "approved",
            created_at: r.last_msg_created_at ?? "",
          },
    last_message_at: r.last_message_at,
    last_read_at: r.last_read_at,
    unread_count: Number(r.unread_count) || 0,
  }));
}
