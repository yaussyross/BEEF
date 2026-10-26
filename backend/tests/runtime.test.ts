import { test, expect } from 'bun:test';
import { mkdtemp, writeFile, mkdir, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { serverConfig } from '../src/server/config';
import { createRuntime } from '../src/server/runtime';
import type { ChatServer } from '../src/ws/chat';

const env = { DATABASE_URL: 'postgres://fixture:fixture@localhost/fixture',
  JWT_SECRET: 'synthetic-jwt-secret-00000000000000', MODERATION_ADMIN_KEY: 'synthetic-admin-key-00000000000000' };
const server = { upgrade: () => false } as ChatServer;
const request = (path: string, method = 'GET') => new Request('http://localhost' + path, { method });

test('explicit runtime config defaults to loopback and validates without disclosing values', () => {
  expect(serverConfig(env)).toEqual({ host: '127.0.0.1', port: 3000, readinessTimeoutMs: 2000, shutdownTimeoutMs: 10000 });
  expect(serverConfig({ ...env, BEEF_HOST: '0.0.0.0', BEEF_PORT: '8080' }).port).toBe(8080);
  for (const value of ['0', '-1', '65536', '3000oops', '']) expect(() => serverConfig({ ...env, BEEF_PORT: value })).toThrow('Invalid BEEF_PORT');
  expect(() => serverConfig({ ...env, JWT_SECRET: '' })).toThrow('JWT_SECRET');
  expect(() => serverConfig({ ...env, MODERATION_ADMIN_KEY: '' })).toThrow('MODERATION_ADMIN_KEY');
  expect(() => serverConfig({ ...env, DATABASE_URL: 'https://secret.example' })).toThrow('DATABASE_URL must use PostgreSQL');
});

test('readiness timeout aborts; liveness stays independent and responses disclose no diagnostics', async () => {
  let signal: AbortSignal | undefined;
  const runtime = createRuntime({ handler: { fetch: () => new Response('app') }, clientDir: '/unused',
    readinessTimeoutMs: 10, checkReady: async s => { signal = s; return new Promise(() => {}); } });
  expect((await runtime.fetch(request('/healthz'), server))?.status).toBe(200);
  const ready = await runtime.fetch(request('/readyz'), server);
  expect(ready?.status).toBe(503);
  expect(await ready?.json()).toEqual({ status: 'unavailable' });
  expect(signal?.aborted).toBe(true);
  expect((await runtime.fetch(request('/readyz', 'POST'), server))?.status).toBe(405);
});

test('shutdown fails readiness and application traffic closed but preserves liveness', async () => {
  const runtime = createRuntime({ handler: { fetch: () => new Response('app') }, clientDir: '/unused',
    readinessTimeoutMs: 100, checkReady: async () => true });
  expect((await runtime.fetch(request('/readyz'), server))?.status).toBe(200);
  runtime.beginShutdown();
  expect((await runtime.fetch(request('/readyz'), server))?.status).toBe(503);
  expect((await runtime.fetch(request('/api/me'), server))?.status).toBe(503);
  expect((await runtime.fetch(request('/api/ws'), server))?.status).toBe(503);
  expect((await runtime.fetch(request('/healthz'), server))?.status).toBe(200);
});

test('static serving prevents symlink escape, hidden files and encoded traversal', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'beef-runtime-'));
  try {
    const clientDir = join(dir, 'client');
    await mkdir(clientDir);
    await writeFile(join(clientDir, 'safe.txt'), 'synthetic public asset');
    await writeFile(join(dir, 'private.txt'), 'synthetic private value');
    await writeFile(join(clientDir, '.env'), 'synthetic hidden value');
    await symlink(join(dir, 'private.txt'), join(clientDir, 'escape.txt'));
    const runtime = createRuntime({ handler: { fetch: () => new Response('route', { status: 404 }) },
      clientDir, readinessTimeoutMs: 100 });
    expect(await (await runtime.fetch(request('/safe.txt'), server))?.text()).toBe('synthetic public asset');
    expect(await (await runtime.fetch(request('/safe.txt', 'HEAD'), server))?.text()).toBe('');
    for (const path of ['/escape.txt', '/.env', '/%2e%2e%2fprivate.txt', '/%5c..%5cprivate.txt']) {
      const result = await runtime.fetch(request(path), server);
      expect(result?.status).toBe(404);
      expect(await result?.text()).not.toContain('synthetic private value');
    }
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('real service starts on explicit loopback, shuts down, and never takes over an occupied port', async () => {
  const holder = Bun.serve({ hostname: '127.0.0.1', port: 0, fetch: () => new Response('original listener') });
  const childEnv = { ...env, BEEF_HOST: '127.0.0.1', BEEF_PORT: String(holder.port), BEEF_SHUTDOWN_TIMEOUT_MS: '100' };
  const cwd = join(import.meta.dir, '..');
  const conflicting = Bun.spawn([process.execPath, '--no-env-file', 'serve.ts'], { cwd, env: childEnv, stdout: 'pipe', stderr: 'pipe' });
  try {
    expect(await conflicting.exited).not.toBe(0);
    expect(await (await fetch(holder.url)).text()).toBe('original listener');
  } finally { holder.stop(true); conflicting.kill(); }
  const service = Bun.spawn([process.execPath, '--no-env-file', 'serve.ts'], { cwd, env: childEnv, stdout: 'pipe', stderr: 'pipe' });
  try {
    let response: Response | undefined;
    for (let i = 0; i < 100; i++) {
      try { response = await fetch(`http://127.0.0.1:${childEnv.BEEF_PORT}/healthz`); break; }
      catch { await Bun.sleep(10); }
    }
    expect(response?.status).toBe(200);
    service.kill('SIGTERM');
    expect(await service.exited).toBe(0);
  } finally { service.kill(); }
});
