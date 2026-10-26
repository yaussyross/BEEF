/** Shared by bundled REST handlers and the Bun WebSocket entry point. */
export interface ChatSocket {
  data: { userId: string };
  readyState: number;
  send(data: string): void;
  close(code?: number, reason?: string): void;
}

declare global {
  var __BEEF_CHAT_HUB__: Map<string, Set<ChatSocket>> | undefined;
}

export function hub(): Map<string, Set<ChatSocket>> {
  return (globalThis.__BEEF_CHAT_HUB__ ??= new Map<string, Set<ChatSocket>>());
}

/** Remove first; a broken socket must not prevent the others being closed. */
export function dropSocketsForUser(userId: string): void {
  const sockets = hub().get(userId);
  hub().delete(userId);
  for (const socket of sockets ?? []) {
    try { socket.close(4001, "account_unavailable"); } catch { /* already closed */ }
  }
}

/** Invalidate only the identified message on connected participant devices. */
export function notifyContentContained(userIds: string[], messageId: string, threadId: string): void {
  const event = JSON.stringify({ type: 'content_contained', message_id: messageId, thread_id: threadId });
  for (const id of new Set(userIds)) {
    for (const socket of hub().get(id) ?? []) {
      try { if (socket.readyState === 1) socket.send(event); } catch { /* next hydration remains authoritative */ }
    }
  }
}
