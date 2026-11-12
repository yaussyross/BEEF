import { expect, test } from 'bun:test';
import { readJson, MAX_JSON_BYTES } from '../src/lib/http';
import { createLoginThrottle } from '../src/lib/login-throttle';
import { Route } from '../src/routes/api/login';
const request = (body: string, headers: Record<string, string> = {}) => new Request('https://fixture.test/api/login', { method: 'POST', body, headers });
test('JSON accepts objects and rejects arrays, malformed and invalid UTF8', async () => {
  expect(await readJson(request('{"ok":true}'))).toEqual({ok:true});
  for (const body of ['', 'null', '[]', '{']) expect(await readJson(request(body))).toBeNull();
  expect(await readJson(new Request('https://fixture.test', {method:'POST', body: new Uint8Array([255])}))).toBeNull();
});
test('byte cap handles absent and dishonest lengths and exact boundary', async () => {
  const exact = '{"a":"' + 'a'.repeat(MAX_JSON_BYTES - 8) + '"}';
  expect(await readJson(request(exact))).not.toBeNull();
  for (const headers of [{}, {'content-length':'1'}, {'content-length':String(MAX_JSON_BYTES+1)}] as Record<string,string>[]) {
    expect(await readJson(request(exact+' ', headers))).toBeNull();
  }
});
test('stream overflow cancels reader', async () => {
  let cancelled = false;
  const body = new ReadableStream({pull(c) { c.enqueue(new Uint8Array(MAX_JSON_BYTES+1)); }, cancel() { cancelled=true; }});
  expect(await readJson(new Request('https://fixture.test', {method:'POST', body}))).toBeNull();
  expect(cancelled).toBe(true);
});
test('normalized account and global limits expire', () => {
  let time=1000; const throttle=createLoginThrottle(()=>time);
  for (let i=0;i<10;i++) expect(throttle(' A@EXAMPLE.TEST ')).toBe(0);
  expect(throttle('a@example.test')).toBe(60);
  for(let i=0;i<89;i++) expect(throttle(`${i}@example.test`)).toBe(0);
  expect(throttle('new@example.test')).toBe(60);
  time+=60000; expect(throttle('a@example.test')).toBe(0);
});
test('login throttles before credentials/database work', async () => {
  const handler=(Route.options.server!.handlers as { POST: (ctx: {request: Request}) => Promise<Response> }).POST;
  for(let i=0;i<10;i++) {
    const result=await handler({request:request('{"email":"route@example.test"}')} as never);
    expect((result as Response).status).toBe(400);
  }
  const result=await handler({request:request('{"email":"route@example.test"}')} as never) as Response;
  expect(result.status).toBe(429); expect(Number(result.headers.get('retry-after'))).toBeGreaterThan(0);
});
