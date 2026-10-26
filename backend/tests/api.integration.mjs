// Real built REST handler + production WebSocket handlers + real SQL over HTTP.
// Invoked ONLY by db/tests/run_api_local.py with a fresh synthetic database.
import assert from 'node:assert/strict';
import { neon, neonConfig } from '@neondatabase/serverless';

const endpoint = new URL(process.env.BEEF_TEST_PROXY_URL || 'http://invalid');
const database = new URL(process.env.BEEF_TEST_DATABASE_URL || 'postgres://invalid');
assert.equal(endpoint.hostname, '127.0.0.1');
assert.equal(endpoint.protocol, 'http:');
assert.equal(database.hostname, 'db.localtest.me');
assert.equal(database.pathname, '/beef_test');
process.env.DATABASE_URL = database.href;
process.env.JWT_SECRET = 'isolated-test-only-' + crypto.randomUUID();
process.env.MODERATION_ADMIN_KEY = 'isolated-moderation-' + crypto.randomUUID();
process.env.IMAGE_MODERATION_API_KEY = '';
neonConfig.fetchEndpoint = endpoint.href;
const sql = neon(database.href);
let ready = false;
for (let attempt = 0; attempt < 60; attempt++) {
  try { await sql`SELECT 1`; ready = true; break; }
  catch { await Bun.sleep(500); }
}
assert.ok(ready, 'Local Neon HTTP proxy did not become ready');
assert.equal((await sql`SELECT count(*)::int AS n FROM users`)[0].n, 0);
console.log('PASS fresh migrated PostgreSQL reachable through real Neon HTTP driver');

const { default: handler } = await import('../dist/server/server.js');
const { chatWebSocketHandlers, handleChatUpgrade } = await import('../src/ws/chat.ts');
const server = Bun.serve({
  hostname: '127.0.0.1', port: 0, websocket: chatWebSocketHandlers,
  fetch(request, server) {
    if (new URL(request.url).pathname === '/api/ws') return handleChatUpgrade(request, server);
    return handler.fetch(request);
  },
});
const sockets = [];
async function api(path, { token, method = 'GET', body, status = 200, admin = false } = {}) {
  const response = await fetch(new URL(path, server.url), {
    method, headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(admin ? { 'X-Moderation-Key': process.env.MODERATION_ADMIN_KEY } : {}),
    }, body: body ? JSON.stringify(body) : undefined,
  });
  const result = await response.json();
  assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(result)}`);
  return result;
}
function publicPayload(value) {
  const forbidden = new Set(['birthdate', 'email', 'lat', 'lng', 'latitude', 'longitude',
    'precise_lat', 'precise_lng', 'coarse_lat', 'coarse_lng', 'precise_geog', 'coarse_geog', 'travel_lat', 'travel_lng']);
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    for (const [key, item] of Object.entries(node)) {
      assert.ok(!forbidden.has(key), `Private field leaked: ${key}`);
      walk(item);
    }
  }
  walk(value);
}
async function connect(token) {
  const url = new URL('/api/ws', server.url);
  url.protocol = 'ws:';
  const ws = new WebSocket(url, { headers: { authorization: `Bearer ${token}` } });
  const events = [];
  let closeCode;
  ws.addEventListener('message', event => events.push(JSON.parse(event.data)));
  ws.addEventListener('close', event => { closeCode = event.code; });
  sockets.push(ws);
  async function until(predicate, label) {
    for (let i = 0; i < 200; i++) {
      if (predicate()) return;
      await Bun.sleep(10);
    }
    throw new Error(`Timed out: ${label}`);
  }
  async function event(type) {
    await until(() => events.some(event => event.type === type), type);
    return events.splice(events.findIndex(event => event.type === type), 1)[0];
  }
  await event('connected');
  return { ws, events, event, closed: async () => { await until(() => closeCode !== undefined, 'close'); return closeCode; } };
}
const password = 'fictional-test-password-123';
async function register(label) {
  const account = await api('/api/register', { method: 'POST', status: 201,
    body: { email: `${label}@example.test`, password, birthdate: '1990-06-15' } });
  await sql`UPDATE users SET signup_source = 'synthetic_demo' WHERE id = ${account.user.id}`;
  return { id: account.user.id, token: account.accessToken, refresh: account.refreshToken };
}
try {
  await api('/api/me', { status: 401 });
  await api('/api/register', { method: 'POST', status: 403,
    body: { email: 'underage-fixture@example.test', password, birthdate: '2020-01-01' } });
  const a = await register('fictional-adult-a');
  const b = await register('fictional-adult-b');
  const c = await register('fictional-adult-c');
  await api('/api/login', { method: 'POST', body: { email: 'fictional-adult-a@example.test', password } });
  await api('/api/refresh', { method: 'POST', body: { refreshToken: a.refresh } });
  await api('/api/me', { token: a.refresh, status: 401 });
  console.log('PASS auth registration/login/refresh, token audience, unauthenticated and underage rejection');

  for (const [person, lat] of [[a, 37.7749], [b, 37.775]]) {
    const location = await api('/api/location', { token: person.token, method: 'POST', body: { lat, lng: -122.4194, coarse_location: 'city' } });
    publicPayload(location);
    await api('/api/profile', { token: person.token, method: 'PUT', body: { intent_tags: ['friends', 'chat'], bio: 'Coffee and walks' } });
  }
  const profile = await api(`/api/profile/${b.id}`, { token: a.token });
  publicPayload(profile);
  assert.deepEqual(profile.user.intent_tags, ['friends', 'chat']);
  const grid = await api('/api/grid', { token: a.token });
  publicPayload(grid);
  assert.ok(grid.items.some(item => item.user_id === b.id));
  assert.ok(grid.items.every(item => ['<1 mi', '1–5 mi', '5–20 mi', '20–50 mi', '50+ mi', 'nearby'].includes(item.distance)));
  await api('/api/profile', { token: b.token, method: 'PUT', body: { hide_distance: true, coarse_location: 'region' } });
  const own = await api('/api/profile', { token: b.token });
  assert.equal(own.user.hide_distance, true);
  assert.equal(own.user.coarse_location, 'region');
  const privateGrid = await api('/api/grid', { token: a.token });
  publicPayload(privateGrid);
  assert.equal(privateGrid.items.find(item => item.user_id === b.id).distance, 'nearby');
  console.log('PASS intent-array decoding, grid distance buckets and public payload privacy');

  const ab = (await api('/api/threads', { token: a.token, method: 'POST', status: 201, body: { other_user_id: b.id } })).thread.id;
  const ac = (await api('/api/threads', { token: a.token, method: 'POST', status: 201, body: { other_user_id: c.id } })).thread.id;
  const sa = await connect(a.token);
  const sb = await connect(b.token);
  sa.ws.send(JSON.stringify({ type: 'send', thread_id: ab, client_message_id: 'ws-one', body: 'Hello from A' }));
  const ack = await sa.event('ack');
  const delivery = await sb.event('message');
  assert.equal(ack.message.id, delivery.message.id);
  publicPayload(delivery);
  const retry = await api(`/api/threads/${ab}/messages`, { token: a.token, method: 'POST', body: { client_message_id: 'ws-one', body: 'retry' } });
  assert.equal(retry.message.id, ack.message.id);
  assert.equal(retry.duplicate, true);
  await api(`/api/threads/${ac}/messages`, { token: a.token, method: 'POST', status: 409, body: { client_message_id: 'ws-one', body: 'wrong recipient' } });
  const sc0 = await connect(c.token);
  sa.ws.send(JSON.stringify({ type: 'send', thread_id: ac, client_message_id: 'ws-one', body: 'wrong recipient' }));
  assert.equal((await sa.event('error')).code, 'client_message_id_conflict');
  assert.equal(sc0.events.filter(event => event.type === 'message').length, 0);
  sc0.ws.close();
  await api(`/api/threads/${ab}/messages`, { token: c.token, status: 404 });
  const history = await api(`/api/threads/${ab}/messages`, { token: b.token });
  assert.equal(history.messages.length, 1);
  publicPayload(history);
  await api(`/api/threads/${ab}/messages`, { token: a.token, method: 'POST', status: 201,
    body: { client_message_id: 'rest-two', body: 'Second message' } });
  const page = await api(`/api/threads/${ab}/messages?limit=1`, { token: b.token });
  assert.equal(page.messages.length, 1);
  assert.ok(page.next_cursor);
  const next = await api(`/api/threads/${ab}/messages?limit=1&cursor=${encodeURIComponent(page.next_cursor)}`, { token: b.token });
  assert.equal(next.messages[0].id, ack.message.id);
  sb.ws.send(JSON.stringify({ type: 'read', thread_id: ab }));
  await sb.event('read_ack');
  const inbox = await api('/api/threads', { token: b.token });
  publicPayload(inbox);
  assert.equal(inbox.threads.find(thread => thread.id === ab).unread_count, 0);
  console.log('PASS real WebSocket send/ack/delivery/read and REST history/idempotency/privacy/participant guards');

  await api('/api/block', { token: a.token, method: 'POST', body: { blocked_user_id: b.id } });
  assert.equal(await sa.closed(), 4000);
  assert.equal(await sb.closed(), 4000);
  await api(`/api/threads/${ab}/messages`, { token: b.token, status: 403 });
  await api(`/api/threads/${ab}/messages`, { token: a.token, method: 'POST', status: 403, body: { client_message_id: 'blocked', body: 'hello' } });
  assert.equal((await api('/api/threads', { token: b.token })).threads.length, 0);
  await api('/api/block', { token: a.token, method: 'DELETE', body: { blocked_user_id: b.id } });
  console.log('PASS REST block closes sockets across bundled modules and prevents both directions of access');

  const sb2 = await connect(b.token);
  // Synthetic report metadata only: no images or explicit/evidence content.
  await api('/api/report', { token: a.token, method: 'POST', status: 201,
    body: { report_type: 'csam', reported_user_id: b.id, reason: 'Synthetic integration fixture; no real content' } });
  assert.equal(await sb2.closed(), 4001);
  await api('/api/me', { token: b.token, status: 403 });
  await api('/api/refresh', { method: 'POST', status: 403, body: { refreshToken: b.refresh } });
  await api('/api/ws', { token: b.token, status: 403 });
  await api(`/api/threads/${ab}/messages`, { token: a.token, status: 404 });
  assert.equal((await api('/api/threads', { token: a.token })).threads.some(thread => thread.id === ab), false);
  console.log('PASS synthetic report suspension closes sockets and rejects existing tokens/refresh/upgrade/chat');

  const sc = await connect(c.token);
  const report = await api('/api/report', { token: a.token, method: 'POST', status: 201,
    body: { report_type: 'harassment', reported_user_id: c.id, reason: 'Synthetic integration fixture' } });
  assert.ok(report.report_id);
  const queue = await sql`SELECT mq.id FROM moderation_queue mq JOIN profiles p ON p.id = mq.target_id WHERE p.user_id = ${c.id}`;
  await api('/api/moderation/review', { method: 'POST', admin: true, body: { queue_id: queue[0].id, decision: 'ban' } });
  assert.equal(await sc.closed(), 4001);
  await api('/api/me', { token: c.token, status: 403 });
  console.log('PASS human moderation ban revokes existing socket and HTTP session');

  const sa2 = await connect(a.token);
  await sql`UPDATE users SET status = 'deleted' WHERE id = ${a.id}`;
  sa2.ws.send(JSON.stringify({ type: 'read', thread_id: ac }));
  assert.equal(await sa2.closed(), 4001);
  await api('/api/me', { token: a.token, status: 403 });
  console.log('PASS direct status change is enforced on an existing socket next action and HTTP request');

  const d = await register('fictional-adult-d');
  const sd = await connect(d.token);
  // Deliberate loopback-only connection failure; restore before cleanup checks.
  neonConfig.fetchEndpoint = 'http://127.0.0.1:1/sql';
  try {
    sd.ws.send(JSON.stringify({ type: 'read', thread_id: ac }));
    assert.equal(await sd.closed(), 4001);
    await api('/api/me', { token: d.token, status: 503 });
    await api('/api/ws', { token: d.token, status: 503 });
  } finally {
    neonConfig.fetchEndpoint = endpoint.href;
  }
  await api('/api/me', { token: d.token });
  console.log('PASS transport outage fails closed on active socket, HTTP and upgrade; recovery restores access');
  assert.equal((await sql`SELECT count(*)::int AS n FROM users WHERE signup_source <> 'synthetic_demo'`)[0].n, 0);
  console.log('PASS all persisted accounts are synthetic fixtures');
} finally {
  for (const ws of sockets) ws.close();
  server.stop(true);
}
