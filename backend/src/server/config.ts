import { closedTestPolicy } from "../lib/closed-test";
import { nativeOptions } from "../native-db";
/** Explicit service configuration. Values are never included in error messages. */
export function serverConfig(env: Record<string, string | undefined>) {
  const host = env.BEEF_HOST ?? '127.0.0.1';
  if (!host || !/^[a-zA-Z0-9.:[\]-]+$/.test(host)) throw new Error('Invalid BEEF_HOST');
  const integer = (name: string, fallback: number, max: number) => {
    const value = env[name] ?? String(fallback);
    if (!/^\d+$/.test(value) || Number(value) < 1 || Number(value) > max) throw new Error(`Invalid ${name}`);
    return Number(value);
  };
  let database: URL;
  try { database = new URL(env.DATABASE_URL ?? ''); } catch { throw new Error('DATABASE_URL is required'); }
  if (!['postgres:', 'postgresql:'].includes(database.protocol)) throw new Error('DATABASE_URL must use PostgreSQL');
  const driver = env.BEEF_DATABASE_DRIVER ?? 'neon';
  if (!['neon', 'postgres'].includes(driver)) throw new Error('Invalid BEEF_DATABASE_DRIVER');
  if (driver === 'postgres') nativeOptions(env.DATABASE_URL!);
  closedTestPolicy(env);
  if ((env.JWT_SECRET?.length ?? 0) < 32) throw new Error('JWT_SECRET must contain at least 32 characters');
  if ((env.MODERATION_ADMIN_KEY?.length ?? 0) < 32) throw new Error('MODERATION_ADMIN_KEY must contain at least 32 characters');
  return { host, port: integer('BEEF_PORT', 3000, 65535),
    readinessTimeoutMs: integer('BEEF_READINESS_TIMEOUT_MS', 2000, 30000),
    shutdownTimeoutMs: integer('BEEF_SHUTDOWN_TIMEOUT_MS', 10000, 60000) };
}
