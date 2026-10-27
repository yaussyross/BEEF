/** Explicit closed-test bootstrap only. No public endpoint or automatic general migration. */
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { nativeOptions } from '../backend/src/native-db';

export async function migrateNative(directory = join(import.meta.dir, 'migrations')) {
  if (process.env.BEEF_STAGING_MIGRATIONS !== 'apply' || process.env.BEEF_ACCESS_MODE !== 'closed_test') {
    throw new Error('Closed-test migration opt-in required');
  }
  const options = nativeOptions(process.env.DATABASE_URL ?? '');
  const pool = new Bun.SQL(options.url, { ...options, max: 1, connection: { statement_timeout: 60000, lock_timeout: 10000 } });
  try {
    const connection = await pool.reserve();
    try {
      await connection.unsafe('BEGIN');
      // One transaction covers schema and ledger, and serializes concurrent starts.
      await connection.unsafe('SELECT pg_advisory_xact_lock(734292601)');
      await connection.unsafe('CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
      const files = (await readdir(directory)).filter(f => /^\d{4}_.*\.sql$/.test(f)).sort();
      if (!files.length) throw new Error('Missing migrations');
      let applied = 0;
      for (const file of files) {
        const existing = await connection.unsafe('SELECT 1 FROM schema_migrations WHERE version=$1', [file]);
        if (existing.length) continue;
        await connection.unsafe(await readFile(join(directory, file), 'utf8')).simple();
        await connection.unsafe('INSERT INTO schema_migrations(version) VALUES ($1)', [file]);
        applied++;
      }
      await connection.unsafe('COMMIT');
      return { applied, total: files.length };
    } catch (error) {
      try { await connection.unsafe('ROLLBACK'); } catch { /* connection shutdown below */ }
      const safe = new Error('Closed-test migration failed');
      const code = (error as { code?: unknown })?.code;
      if (typeof code === 'string' && /^[0-9A-Z]{5}$/.test(code)) Object.assign(safe, { code });
      throw safe;
    } finally { connection.release(); }
  } finally { await pool.close({ timeout: 1 }); }
}
if (import.meta.main) {
  try { const result = await migrateNative(); console.log(`Migrations ready: ${result.applied} applied, ${result.total} total`); }
  catch { console.error('Closed-test migration failed; service not started'); process.exitCode = 1; }
}
