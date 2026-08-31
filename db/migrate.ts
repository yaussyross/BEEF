// @ts-nocheck
/**
 * BEEF — migration applier (Bun). The sandbox has no `psql`, so this uses the
 * Neon serverless Postgres driver over HTTP. It applies `db/migrations/*.sql`
 * in filename order, recording each file in a `schema_migrations` table (the
 * same contract as `db/migrate.sh`), then prints schema verification.
 *
 * Run from the repo root:
 *   bun install                       # first time, to fetch @neondatabase/serverless
 *   DATABASE_URL=postgres://... bun db/migrate.ts
 *
 * CI does NOT run this (no live DB). It is compile/build-only; migrations run
 * manually against a connected DATABASE_URL.
 */
import { Client } from "@neondatabase/serverless";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

// Migrations live next to this script: db/migrations/.
const MIGRATIONS_DIR = join(import.meta.dir, "migrations");

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not set");

  const client = new Client(url);
  await client.connect();

  try {
    await client.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version    text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    )`);

    const files = (await readdir(MIGRATIONS_DIR))
      .filter((f) => /^\d{4}_.*\.sql$/.test(f))
      .sort();

    for (const file of files) {
      const applied = await client.query(
        `SELECT 1 AS x FROM schema_migrations WHERE version = $1`,
        [file]
      );
      if (applied.rows.length > 0) {
        console.log(`skip   ${file} (already applied)`);
        continue;
      }
      const sqlText = await readFile(join(MIGRATIONS_DIR, file), "utf8");
      console.log(`apply  ${file} (${sqlText.length} bytes)`);
      await client.query(sqlText);
      await client.query(`INSERT INTO schema_migrations (version) VALUES ($1)`, [file]);
    }
    console.log("migrations up to date");

    // ── Verification ─────────────────────────────────────────────────────
    const tables = await client.query(`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY tablename`);
    console.log("\n=== public tables ===");
    console.log(tables.rows.map((r) => r.tablename).join("\n"));

    const extensions = await client.query(`SELECT extname FROM pg_extension ORDER BY extname`);
    console.log("\n=== extensions ===");
    console.log(extensions.rows.map((r) => r.extname).join("\n"));

    const chatCols = await client.query(`
      SELECT column_name, data_type FROM information_schema.columns
      WHERE table_name = 'chat_threads' ORDER BY ordinal_position`);
    console.log("\n=== chat_threads columns ===");
    console.log(chatCols.rows.map((r) => `${r.column_name} ${r.data_type}`).join("\n"));

    const msgCols = await client.query(`
      SELECT column_name, data_type FROM information_schema.columns
      WHERE table_name = 'chat_messages' ORDER BY ordinal_position`);
    console.log("\n=== chat_messages columns ===");
    console.log(msgCols.rows.map((r) => `${r.column_name} ${r.data_type}`).join("\n"));

    const reportCols = await client.query(`
      SELECT column_name, data_type FROM information_schema.columns
      WHERE table_name = 'reports' ORDER BY ordinal_position`);
    console.log("\n=== reports columns ===");
    console.log(reportCols.rows.map((r) => `${r.column_name} ${r.data_type}`).join("\n"));

    const evidence = await client.query(
      `SELECT to_regclass('public.report_evidence') AS t`
    );
    console.log("\n=== report_evidence exists ===");
    console.log(evidence.rows[0].t ?? "MISSING");

    const photoStatus = await client.query(`
      SELECT enumlabel FROM pg_enum
      JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
      WHERE pg_type.typname = 'photo_status' ORDER BY enumsortorder`);
    console.log("\n=== photo_status enum ===");
    console.log(photoStatus.rows.map((r) => r.enumlabel).join(", "));
  } finally {
    await client.end();
  }
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error(err);
    process.exit(1);
  }
);
