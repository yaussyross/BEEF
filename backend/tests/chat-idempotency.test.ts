import { afterAll, afterEach, beforeAll, expect, mock, test } from "bun:test";

let results: (unknown[] | Error)[] = [];
let queries: string[] = [];
mock.module("../src/db", () => ({
  sql: () => async (query: TemplateStringsArray) => {
    queries.push(query.join("?"));
    const result = results.shift();
    if (!result) throw new Error("Unexpected database query");
    if (result instanceof Error) throw result;
    return result;
  },
}));
const { sendMessage } = await import("../src/lib/chat");

function duplicate(storedThread: string) {
  results = [
    [{ status: "active" }],
    [{ id: "current-thread", participant_low: "sender", participant_high: "recipient" }],
    [{ x: 1 }], // other participant active
    [], // participation path: no block
    [], // send path: no block
    [], // duplicate insert
    [{ id: "stored-message", thread_id: storedThread, sender_id: "sender", body: "private original", moderation_status: "approved" }],
  ];
  return sendMessage("sender", {
    threadId: "current-thread", clientMessageId: "reused-id", body: "hello",
  });
}

test("same-conversation retry returns the original message", async () => {
  const result = await duplicate("current-thread");
  expect(result.created).toBe(false);
  expect(result.message.body).toBe("private original");
  expect(result.recipientId).toBe("recipient");
  expect(results).toHaveLength(0);
});

test("cross-conversation reuse cannot deliver private history to a new recipient", async () => {
  await expect(duplicate("different-thread")).rejects.toMatchObject({
    status: 409, code: "client_message_id_conflict",
  });
  expect(results).toHaveLength(0);
});

// Keep a single mocked database module across these domain/transport tests.
const { requireAuth, signAccessToken } = await import('../src/lib/auth');
const { getThreadHistory, listThreads, markThreadRead } = await import('../src/lib/chat');
const { chatWebSocketHandlers, handleChatUpgrade } = await import('../src/ws/chat');
const { hub, dropSocketsForUser } = await import('../src/ws/registry');
const { notifyContentContained } = await import('../src/ws/registry');
const { applyReviewDecision } = await import('../src/lib/moderation');
const { errorResponse } = await import('../src/lib/http');
const originalSecret = process.env.JWT_SECRET;
let token: string;
beforeAll(async () => {
  process.env.JWT_SECRET = 'test-only-account-status-secret-000000000000';
  token = await signAccessToken('sender', 'fictional-adult@example.test');
});
afterAll(() => {
  if (originalSecret === undefined) delete process.env.JWT_SECRET;
  else process.env.JWT_SECRET = originalSecret;
});
afterEach(() => {
  expect(results).toHaveLength(0);
  hub().clear();
  queries = [];
});
function request() {
  return new Request('http://localhost/api/ws', { headers: { authorization: `Bearer ${token}` } });
}
function socket(userId = 'sender') {
  const sent: string[] = [];
  const closed: number[] = [];
  return {
    data: { userId }, readyState: 1, sent, closed,
    send(value: string) { sent.push(value); },
    close(code?: number) { closed.push(code ?? 1000); this.readyState = 3; },
  };
}
const active = [{ status: 'active' }];
const thread = [{ id: 'current-thread', participant_low: 'sender', participant_high: 'recipient' }];

for (const status of ['suspended', 'banned', 'deleted']) {
  test(`existing HTTP token is denied after ${status}`, async () => {
    results = [active, [{ status }]];
    expect(await requireAuth(request())).toBe('sender');
    try {
      await requireAuth(request());
      throw new Error('Access unexpectedly allowed');
    } catch (error) {
      const response = errorResponse(error);
      expect(response.status).toBe(403);
      expect((await response.json()).error).toBe('account_disabled');
    }
  });
  test(`WebSocket upgrade denied for ${status}`, async () => {
    results = [[{ status }]];
    let upgraded = false;
    const response = await handleChatUpgrade(request(), { upgrade: () => { upgraded = true; return true; } });
    expect(response?.status).toBe(403);
    expect(upgraded).toBe(false);
  });
}

for (const [result, status] of [[[], 401], [new Error('database unavailable'), 503]] as const) {
  test(`HTTP and upgrade fail closed with ${status}`, async () => {
    results = [result as unknown[] | Error, result as unknown[] | Error];
    await expect(requireAuth(request())).rejects.toMatchObject({ status });
    const response = await handleChatUpgrade(request(), { upgrade: () => { throw new Error('Must not upgrade'); } });
    expect(response?.status).toBe(status);
  });
}

test('active account can upgrade', async () => {
  results = [active];
  let upgraded = false;
  expect(await handleChatUpgrade(request(), { upgrade: () => { upgraded = true; return true; } })).toBeUndefined();
  expect(upgraded).toBe(true);
});

for (const type of ['send', 'read']) {
  test(`existing socket cannot ${type} after suspension`, async () => {
    const ws = socket();
    results = [active, [{ status: 'suspended' }]];
    await chatWebSocketHandlers.open(ws);
    ws.sent.length = 0;
    await chatWebSocketHandlers.message(ws, JSON.stringify({ type, thread_id: 'current-thread', client_message_id: 'new', body: 'hello' }));
    expect(ws.closed).toContain(4001);
    expect(ws.sent.some(value => ['ack', 'read_ack', 'message'].includes(JSON.parse(value).type))).toBe(false);
    expect(hub().has('sender')).toBe(false);
    expect(queries.some(query => /INSERT|UPDATE/.test(query))).toBe(false);
  });
}

test('socket open rechecks status after upgrade; lookup failure also closes', async () => {
  for (const result of [[{ status: 'deleted' }], new Error('offline')]) {
    results = [result];
    const ws = socket();
    await chatWebSocketHandlers.open(ws);
    expect(ws.sent).toEqual([]);
    expect(ws.closed).toContain(4001);
    expect(hub().has('sender')).toBe(false);
  }
});

for (const operation of [
  () => getThreadHistory('sender', 'current-thread'),
  () => markThreadRead('sender', 'current-thread'),
  () => listThreads('sender'),
  () => sendMessage('sender', { recipientId: 'recipient', clientMessageId: 'new', body: 'hello' }),
]) {
  test('disabled caller cannot access chat domain', async () => {
    results = [[{ status: 'banned' }]];
    await expect(operation()).rejects.toMatchObject({ status: 403 });
    expect(queries).toHaveLength(1);
  });
}

for (const operation of [
  () => getThreadHistory('sender', 'current-thread'),
  () => markThreadRead('sender', 'current-thread'),
  () => sendMessage('sender', { threadId: 'current-thread', clientMessageId: 'new', body: 'hello' }),
]) {
  test('inactive peer prevents history, reads and sends', async () => {
    results = [active, thread, []];
    await expect(operation()).rejects.toMatchObject({ status: 404, code: 'thread_not_found' });
    expect(queries.some(query => /INSERT|UPDATE/.test(query))).toBe(false);
  });
}

test('recipient-ID path rejects inactive peer before creating a thread', async () => {
  results = [active, []];
  await expect(sendMessage('sender', { recipientId: 'recipient', clientMessageId: 'new', body: 'hello' }))
    .rejects.toMatchObject({ status: 404, code: 'user_not_found' });
  expect(queries.some(query => /INSERT|UPDATE/.test(query))).toBe(false);
});

test('inbox filters out inactive peers in SQL', async () => {
  results = [active, []];
  expect(await listThreads('sender')).toEqual([]);
  expect(queries.at(-1)).toContain("other.status = 'active'");
});

test('active participant can mark an unblocked thread read', async () => {
  results = [active, thread, [{ x: 1 }], [], []];
  await markThreadRead('sender', 'current-thread');
  expect(queries.at(-1)).toContain('UPDATE thread_participants');
});

test('idle recipient disabled between persistence and delivery receives nothing', async () => {
  const sender = socket();
  const recipient = socket('recipient');
  hub().set('sender', new Set([sender]));
  hub().set('recipient', new Set([recipient]));
  results = [active, active, thread, [{ x: 1 }], [], [],
    [{ id: 'new-message', thread_id: 'current-thread', body: 'hello' }],
    active, [{ status: 'suspended' }]];
  await chatWebSocketHandlers.message(sender, JSON.stringify({ type: 'send', thread_id: 'current-thread', client_message_id: 'new', body: 'hello' }));
  expect(sender.sent.some(value => JSON.parse(value).type === 'ack')).toBe(true);
  expect(sender.closed).toEqual([]);
  expect(recipient.sent).toEqual([]);
  expect(recipient.closed).toContain(4001);
});

test('content containment notification contains IDs only and never closes accounts', () => {
  const first = socket();
  const second = socket('recipient');
  hub().set('sender', new Set([first]));
  hub().set('recipient', new Set([second]));
  notifyContentContained(['sender', 'recipient'], 'message-id', 'thread-id');
  expect(JSON.parse(first.sent[0])).toEqual({ type: 'content_contained', message_id: 'message-id', thread_id: 'thread-id' });
  expect(second.sent).toEqual(first.sent);
  expect(first.closed).toEqual([]);
  expect(second.closed).toEqual([]);
});

test('ordinary review cannot resolve urgent reports or held content', async () => {
  for (const flags of [{ priority: 'urgent' }, { content_held: true }]) {
    results = [[{ id: 'queue', target_type: 'message', target_id: 'message', status: 'pending', ...flags }]];
    await expect(applyReviewDecision('queue', 'approve')).rejects.toMatchObject({ code: 'specialized_review_required' });
    expect(results).toHaveLength(0);
  }
});

test('human ban closes existing sockets', async () => {
  const ws = socket();
  hub().set('sender', new Set([ws]));
  results = [[{ id: 'queue', target_type: 'profile', target_id: 'profile', status: 'pending' }],
    [{ user_id: 'sender' }], [], [], []];
  await applyReviewDecision('queue', 'ban');
  expect(ws.closed).toContain(4001);
  expect(hub().has('sender')).toBe(false);
});

test('broken socket cannot prevent other sockets being revoked', () => {
  const broken = socket();
  broken.close = () => { throw new Error('broken'); };
  const healthy = socket();
  hub().set('sender', new Set([broken, healthy]));
  dropSocketsForUser('sender');
  expect(healthy.closed).toContain(4001);
  expect(hub().has('sender')).toBe(false);
});

test('database outage on an existing socket closes it without a read or write', async () => {
  const ws = socket();
  hub().set('sender', new Set([ws]));
  results = [new Error('database unavailable')];
  await chatWebSocketHandlers.message(ws, JSON.stringify({ type: 'read', thread_id: 'current-thread' }));
  expect(ws.closed).toContain(4001);
  expect(queries).toHaveLength(1);
  expect(ws.sent.some(value => JSON.parse(value).type === 'read_ack')).toBe(false);
});

test('recipient status lookup outage suppresses delivery and closes recipient only', async () => {
  const sender = socket();
  const recipient = socket('recipient');
  hub().set('sender', new Set([sender]));
  hub().set('recipient', new Set([recipient]));
  results = [active, active, thread, [{ x: 1 }], [], [],
    [{ id: 'new-message', thread_id: 'current-thread', body: 'hello' }],
    active, new Error('database unavailable')];
  await chatWebSocketHandlers.message(sender, JSON.stringify({ type: 'send', thread_id: 'current-thread', client_message_id: 'new', body: 'hello' }));
  expect(sender.closed).toEqual([]);
  expect(recipient.sent).toEqual([]);
  expect(recipient.closed).toContain(4001);
});

test('read acknowledgements cannot bypass a block', async () => {
  results = [active, thread, [{ x: 1 }], [{ x: 1 }]];
  await expect(markThreadRead('sender', 'current-thread')).rejects.toMatchObject({ code: 'blocked' });
  expect(queries.some(query => /UPDATE/.test(query))).toBe(false);
});

const { validateStars } = await import('../src/lib/ratings');
test('rating rejects fractional, out-of-range and coerced input', () => {
  for (const value of [0, 6, -1, 1.5, NaN, Infinity, '5', null, true, {}, []]) {
    expect(() => validateStars(value)).toThrow();
  }
  for (const value of [1, 2, 3, 4, 5]) expect(() => validateStars(value)).not.toThrow();
});
