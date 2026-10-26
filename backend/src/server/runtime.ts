import { realpath, stat } from 'node:fs/promises';
import { isAbsolute, relative, resolve } from 'node:path';
import { sql } from '../db';
import { handleChatUpgrade, type ChatServer } from '../ws/chat';

const migrations = ['0001_extensions.sql', '0002_enums.sql', '0003_tables.sql',
  '0004_indexes.sql', '0005_triggers.sql', '0006_seed_interests.sql',
  '0007_chat_thread_pair_key.sql', '0008_moderation.sql',
  '0009_profile_ratings.sql', '0010_report_idempotency.sql'];

export async function databaseReady(signal: AbortSignal): Promise<boolean> {
  const rows = await sql().query(`SELECT
    (SELECT count(*) FROM schema_migrations WHERE version = ANY($1::text[]))::int AS n,
    (SELECT count(*) FROM (SELECT client_report_id, request_hash FROM reports LIMIT 0) r) AS reports_ok,
    (SELECT count(*) FROM (SELECT email FROM waitlist_emails LIMIT 0) w) AS waitlist_ok`,
    [migrations], { fetchOptions: { signal } });
  return rows[0]?.n === migrations.length;
}

export function createRuntime(options: {
  handler: { fetch(request: Request): Response | Promise<Response> };
  clientDir: string;
  readinessTimeoutMs: number;
  checkReady?: (signal: AbortSignal) => Promise<boolean>;
}) {
  let draining = false;
  const json = (status: number, state: string) => Response.json({ status: state },
    { status, headers: { 'Cache-Control': 'no-store' } });
  return {
    beginShutdown() { draining = true; },
    async fetch(request: Request, server: ChatServer): Promise<Response | undefined> {
      const { pathname } = new URL(request.url);
      if (pathname === '/healthz' || pathname === '/readyz') {
        if (!['GET', 'HEAD'].includes(request.method)) return new Response(null, { status: 405, headers: { Allow: 'GET, HEAD' } });
        let response: Response;
        if (pathname === '/healthz') response = json(200, 'ok');
        else if (draining) response = json(503, 'unavailable');
        else {
          const controller = new AbortController();
          let timer: ReturnType<typeof setTimeout> | undefined;
          try {
            const timedOut = new Promise<boolean>(resolve => {
              timer = setTimeout(() => { controller.abort(); resolve(false); }, options.readinessTimeoutMs);
            });
            const ready = await Promise.race([(options.checkReady ?? databaseReady)(controller.signal), timedOut]);
            response = ready && !draining ? json(200, 'ready') : json(503, 'unavailable');
          } catch { response = json(503, 'unavailable'); }
          finally { clearTimeout(timer); }
        }
        return request.method === 'HEAD' ? new Response(null, { status: response.status, headers: response.headers }) : response;
      }
      if (draining) return json(503, 'unavailable');
      if (pathname === '/api/ws') return handleChatUpgrade(request, server);
      // Only serve regular files inside the built public tree, even through
      // encoded paths or symlinks. APIs and other methods go to the router.
      if (pathname !== '/' && !pathname.startsWith('/api/') && ['GET', 'HEAD'].includes(request.method)) {
        try {
          const decoded = decodeURIComponent(pathname);
          if (decoded.includes('\\') || decoded.includes('\0') || decoded.split('/').some(p => p === '..' || p.startsWith('.'))) {
            return new Response(null, { status: 404 });
          }
          const root = await realpath(options.clientDir);
          const target = await realpath(resolve(root, '.' + decoded));
          const path = relative(root, target);
          if (isAbsolute(path) || path === '..' || path.startsWith('../')) return new Response(null, { status: 404 });
          const file = Bun.file(target);
          if ((await stat(target)).isFile() && await file.exists()) return new Response(request.method === 'HEAD' ? null : file,
            { headers: { 'Content-Type': file.type } });
        } catch { /* Missing/non-file paths are handled by the application. */ }
      }
      return options.handler.fetch(request);
    },
  };
}
