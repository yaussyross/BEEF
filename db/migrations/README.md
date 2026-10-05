# BEEF — database migrations

Postgres schema for the BEEF app backend, authored as **idempotent** SQL files
applied in filename order.

## Layout

| File | Contents |
|------|----------|
| `0001_extensions.sql` | PostGIS + citext extensions |
| `0002_enums.sql`      | Enum types (created via `DO` blocks — idempotent) |
| `0003_tables.sql`     | All tables (users, profiles, photos, interests, locations, chat, blocks, reports, moderation, waitlist, ads, push) |
| `0004_indexes.sql`    | GIST + btree/GIN indexes (radius queries, chat, safety, ads) |
| `0005_triggers.sql`   | 18+ gate trigger, geography-sync trigger, thread-touch, updated_at |
| `0006_seed_interests.sql` | Seed interest taxonomy (no users — demo profiles come later with an `is_demo` flag) |
| `0007_chat_thread_pair_key.sql` | Move the 1:1 thread dedupe key onto `chat_threads` (0003 put it on the membership table) |
| `0008_moderation.sql` | Moderation content states (`photo_status.blurred`, `chat_messages.moderation_status`) + NCMEC `report_evidence` snapshot |

## Running

**Via `psql`** (recommended, versioned runner):

```bash
DATABASE_URL=postgres://... bash db/migrate.sh
```

`db/migrate.sh` records each applied file in a `schema_migrations` table, so
re-runs are no-ops. Each file is *also* internally idempotent
(`IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP TRIGGER IF EXISTS` + recreate),
so applying a single file twice is safe.

**Via the Neon SQL console** (when `psql` is unavailable, as in this sandbox):
paste each `000*.sql` file in order. All statements are idempotent.

Requires the `postgis` and `citext` extensions — both supported on Neon.

## Privacy invariants encoded here

- `users.birthdate` is mandatory and an 18+ gate trigger rejects any
  insert/update with an under-18 birthdate at the DB layer (the auth routes
  also reject server-side). It is **never** selected into a payload another
  user can read.
- `locations.precise_lat/lng/geog` are server-side only. The proximity grid
  queries `coarse_geog` (city/region centroid) via `ST_DWithin`; the precise
  point is never exported to ad SDKs or other users.
- `chat_messages(client_message_id)` + unique constraint give idempotent sends.
- `thread_participants(participant_low, participant_high)` sorted-pair unique
  key collapses (A,B) and (B,A) into one thread.
- `waitlist_emails.email` is `citext UNIQUE` — waitlist import dedupes by
  lowercased email at the storage layer too.

## Notes for later phases

- `ad_inventory` is region-scoped, first-party/native + house only (v1): the
  server matches a user's *coarse* region and returns a creative to render
  natively. No programmatic SDK and no location leaves the server.
- `reports.is_csam` + `ncmec_status`/`ncmec_report_id` reserve the NCMEC
  CyberTipline flow (preserve evidence → disable account → submit).
- Demo profiles are seeded in a separate migration with `signup_source =
  'synthetic_demo'` and stripped before store review — never fabricated as real
  users.
