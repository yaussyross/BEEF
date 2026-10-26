// Persistent HTTP + WebSocket service. Build first. TLS belongs to the proxy.
// No port takeover, sudo, automatic migrations or deployment on startup.
import handler from './dist/server/server.js';
import { serverConfig } from './src/server/config';
import { createRuntime } from './src/server/runtime';
import { chatWebSocketHandlers } from './src/ws/chat';
import { hub } from './src/ws/registry';

const config = serverConfig(process.env);
const runtime = createRuntime({ handler, clientDir: `${import.meta.dir}/dist/client`,
  readinessTimeoutMs: config.readinessTimeoutMs });
const server = Bun.serve({ hostname: config.host, port: config.port,
  websocket: chatWebSocketHandlers, fetch: runtime.fetch });
console.log(`BEEF listening on ${config.host}:${server.port}`);

let stopping = false;
async function shutdown() {
  if (stopping) return;
  stopping = true;
  runtime.beginShutdown();
  for (const sockets of hub().values()) {
    for (const socket of sockets) {
      try { socket.close(1001, 'server_shutdown'); } catch { /* continue draining */ }
    }
  }
  hub().clear();
  const deadline = setTimeout(() => { void server.stop(true); }, config.shutdownTimeoutMs);
  try { await server.stop(false); }
  finally { clearTimeout(deadline); }
}
process.on('SIGTERM', () => { void shutdown(); });
process.on('SIGINT', () => { void shutdown(); });
