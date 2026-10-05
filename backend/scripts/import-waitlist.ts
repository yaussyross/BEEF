import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { sql } from "../src/db";

/**
 * BEEF — waitlist → waitlist_emails import (idempotent).
 *
 * Reads `.run/waitlist.jsonl` (one JSON object per line: { email, ts }) and
 * upserts into `waitlist_emails`, deduped by lowercased email, preserving the
 * original submission timestamp.
 *
 * IMPORTANT: this RESERVES emails for invite priority ("founding cut") only.
 * It NEVER creates pre-authenticated accounts — there are no passwords in the
 * waitlist file and this script writes no password_hash.
 *
 * Run (once DATABASE_URL is connected):
 *   bun run scripts/import-waitlist.ts
 * Or override the source file:
 *   WAITLIST_FILE=/path/to/waitlist.jsonl bun run scripts/import-waitlist.ts
 *
 * Safe to run repeatedly: re-runs are no-ops for already-imported emails.
 */

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const DEFAULT_FILE = ".run/waitlist.jsonl";

interface WaitlistEntry {
  email?: unknown;
  ts?: unknown;
}

function normalizeEmail(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const email = raw.trim().toLowerCase();
  return EMAIL_RE.test(email) ? email : null;
}

function parseTs(raw: unknown): string {
  if (typeof raw === "string" && !Number.isNaN(Date.parse(raw))) {
    return new Date(raw).toISOString();
  }
  return new Date().toISOString();
}

async function main() {
  const file = process.env.WAITLIST_FILE ?? DEFAULT_FILE;

  if (!existsSync(file)) {
    console.log(`[import-waitlist] "${file}" not present — nothing to import.`);
    return;
  }

  const contents = await readFile(file, "utf8");
  const lines = contents.split("\n").filter((line) => line.trim().length > 0);

  // Dedupe by lowercased email; first occurrence wins (preserve original ts).
  const seen = new Map<string, string>();
  for (const line of lines) {
    let entry: WaitlistEntry;
    try {
      entry = JSON.parse(line) as WaitlistEntry;
    } catch {
      console.warn(`[import-waitlist] skipping malformed line: ${line.slice(0, 120)}`);
      continue;
    }
    const email = normalizeEmail(entry.email);
    if (!email) continue;
    if (!seen.has(email)) seen.set(email, parseTs(entry.ts));
  }

  if (seen.size === 0) {
    console.log("[import-waitlist] no valid emails to import.");
    return;
  }

  const db = sql();

  const queries = [...seen.entries()].map(([email, ts]) => {
    return db`INSERT INTO waitlist_emails (email, source, original_ts, imported_at, status)
               VALUES (${email}, 'landing_page', ${ts}::timestamptz, now(), 'pending')
               ON CONFLICT (email) DO NOTHING`;
  });

  try {
    await db.transaction(queries);
    console.log(`[import-waitlist] upserted ${queries.length} waitlist email(s).`);
  } catch (err) {
    console.error("[import-waitlist] import failed:", err);
    process.exitCode = 1;
  }
}

main();
