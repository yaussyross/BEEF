# BEEF — Runbook

Copy-paste commands to get everything running. Each command is marked with its
verification status in THIS handoff:

- ✅ **verified** — actually run against the live database/backend in the
  handoff sandbox (2026-10).
- ⚠️ **not verifiable here** — environment-limited (no `psql`, no Flutter SDK
  on this sandbox); the equivalent proof lives in CI or in `app/README.md`.

The Flutter app **cannot be compiled in this sandbox** (the Flutter SDK fails to
extract on its overlay filesystem and doesn't fit the disk). CI is the compile
proof: every PR runs `flutter analyze` + `flutter build apk --debug` on GitHub
Actions. See `app/README.md` for the client-side steps to run on a machine that
has Flutter.

## Prerequisites

- **Bun** ≥ 1.3 (CI pins `bun-version: "1.3.14"`). `curl`, `git`.
- **Postgres with PostGIS + citext** (Neon works) and a connection string.
- **Flutter 3.47.2 stable** (only needed for the app; not this sandbox).
- `psql` optional — only for `db/migrate.sh` (the Bun runner works without it).

## 1. Clone and install

```bash
git clone https://github.com/yaussyross/BEEF.git
cd BEEF

bun install                # ✅ root deps (@neondatabase/serverless for db/migrate.ts)
cd backend && bun install  # ✅ backend deps (141 packages, frozen-lockfile)
cd ..
```

## 2. Environment variables

Copy the template (all placeholders — the repo is public, never commit real
values):

```bash
cp .env.example .env        # backend reads DATABASE_URL, JWT_SECRET, ... from env
```

Backend reads: `DATABASE_URL` (required — Postgres/Neon connection string),
`JWT_SECRET` (required, ≥32 chars), `MODERATION_ADMIN_KEY` (optional; ≥16 chars
to enable the moderation routes), `IMAGE_MODERATION_API_KEY` (optional; Google
Cloud Vision, enables AI image screening), `WAITLIST_FILE` (optional; JSONL
path for the waitlist import script). The app takes `BEEF_API_BASE_URL` as a
Flutter `--dart-define` at build time, not from an env file. See `.env.example`
for one-line descriptions.

`serve.ts` deliberately ignores `PORT`/`HOST` — the public surface is pinned to
`0.0.0.0:3000`.

## 3. Apply migrations to a fresh Postgres

**Bun runner (no psql needed)** — ✅ verified (no-op on the already-migrated
live DB; prints schema verification):

```bash
DATABASE_URL=postgres://user:pass@host/dbname bun run db:migrate
```

**psql runner** (versioned, same contract) — ⚠️ not verifiable in this sandbox
(no `psql` installed); works anywhere psql is available:

```bash
DATABASE_URL=postgres://user:pass@host/dbname bash db/migrate.sh
```

Both are idempotent (each file is `IF NOT EXISTS`-style and also tracked in
`schema_migrations`, so re-runs are no-ops). No `psql` at all? Paste the
`db/migrations/000*.sql` files in order into the Neon SQL console — also
idempotent. CI never runs migrations.

## 4. Run the backend (landing site + REST API + chat WebSocket)

Production server — ✅ verified (served `http://0.0.0.0:3000`, chat at `/api/ws`):

```bash
cd backend
bun install
bun run build          # ✅ ~1s; generates routeTree.gen.ts + dist/
bun run start          # ✅ serves on 0.0.0.0:3000, frees the port first
```

Dev server with hot reload:

```bash
cd backend && bun run dev    # ⚠️ command exists (vite dev on :3000); not re-run this handoff
```

Type-check (must report **exactly the 5 known `serve.ts` Bun-global errors** and
nothing else) — ✅ verified (5 errors, 0 unexpected):

```bash
cd backend
node_modules/.bin/tsc --noEmit --pretty false > /tmp/tsc.log 2>&1 || true
grep -E 'error TS[0-9]+' /tmp/tsc.log | grep -v -E '^serve\.ts\(26,35\): error TS2339:' \
  | grep -v -E '^serve\.ts\((44,9|46,5|61,24|70,11)\): error TS2868:' \
  || echo "no unexpected errors"
```

> Build **before** type-check on a clean checkout (the build generates
> `routeTree.gen.ts` and `dist/server/server.js` that `tsc` needs).

## 5. Smoke-test the API by hand

The team's 83-check suite (Sept 2026, team-reported) was never committed; this
handoff re-verified the same surface with a 36-check live run — all passed.
Here's the minimal manual version (✅ each step verified live during the
handoff; vars `$A`/`$B` are your throwaway `@example.test` emails):

```bash
BASE=http://localhost:3000
PASS='grill-it-123'; BIRTH='1990-06-15'; CM="cm-$(date +%s)"

# register (expect 201) — underage (birthdate 2015-… expect 403)
curl -s -X POST $BASE/api/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"$A\",\"password\":\"$PASS\",\"birthdate\":\"$BIRTH\"}"
curl -s -X POST $BASE/api/register -H 'Content-Type: application/json' \
  -d "{\"email\":\"minor@example.test\",\"password\":\"$PASS\",\"birthdate\":\"2015-01-01\"}"   # 403 underage

# login → token (extract with bun or jq)
TA=$(curl -s -X POST $BASE/api/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$A\",\"password\":\"$PASS\"}" | bun -e 'const d=await Bun.stdin.json(); console.log(d.accessToken)')
TB=$(curl -s -X POST $BASE/api/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$B\",\"password\":\"$PASS\"}" | bun -e 'const d=await Bun.stdin.json(); console.log(d.accessToken)')

# protected routes without a token → 401
curl -s -o /dev/null -w '%{http_code}\n' $BASE/api/me            # 401
curl -s -o /dev/null -w '%{http_code}\n' $BASE/api/grid          # 401

# set location (server-side precise → coarse centroid; nothing echoed back)
curl -s -X POST $BASE/api/location -H "Authorization: Bearer $TA" \
  -H 'Content-Type: application/json' -d '{"lat":37.7749,"lng":-122.4194,"coarse_location":"city"}'

# grid → distance is a bucket string, never coordinates
curl -s -H "Authorization: Bearer $TA" "$BASE/api/grid?limit=10"

# public profile → age_bucket + is_adult, no birthdate
curl -s -H "Authorization: Bearer $TA" "$BASE/api/profile/<B's user id>"

# chat
curl -s -X POST $BASE/api/threads -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' \
  -d "{\"other_user_id\":\"<B's user id>\"}"                                            # 201
curl -s -X POST $BASE/api/threads/<thread id>/messages -H "Authorization: Bearer $TA" \
  -H 'Content-Type: application/json' -d "{\"client_message_id\":\"$CM\",\"body\":\"hey\"}"   # 201
curl -s -X POST $BASE/api/threads/<thread id>/messages -H "Authorization: Bearer $TA" \
  -H 'Content-Type: application/json' -d "{\"client_message_id\":\"$CM\",\"body\":\"dupe\"}"   # 200, same body (idempotent)

# moderation routes are key-gated → 503/401 without MODERATION_ADMIN_KEY
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TA" $BASE/api/moderation/queue
```

WebSocket (1:1 chat): `wss://your-host/api/ws` with
`Authorization: Bearer <accessToken>` (or `?token=<accessToken>` for browser
sockets). Send `{"type":"send","thread_id":"…","client_message_id":"…","body":"…"}`
→ you get `{"type":"ack",…}` and the recipient gets `{"type":"message",…}`.

## 6. Flutter app — analyze and build

⚠️ Not runnable in this sandbox (no Flutter SDK — see `app/README.md` for the
full explanation). On any machine with **Flutter 3.47.2+**:

```bash
cd app
flutter create . --org com.beef --project-name beef --platforms android,ios   # one-time: generates android/ + ios/ (not committed)
flutter pub get
flutter analyze                    # must be clean — CI gates on this
flutter build apk --debug          # CI's compile proof; also `flutter build appbundle` for release
flutter run                        # device/emulator
```

Point the app at your backend at build time:

```bash
flutter build ... --dart-define=BEEF_API_BASE_URL=https://your-host
```

CI (`ci.yml`) regenerates the platform folders itself so the committed
hand-written `lib/`, `pubspec.yaml`, and `analysis_options.yaml` are never
clobbered. iOS release (`flutter build ipa`) needs signing on a Mac; CI covers
it with `analyze` only.

## 7. Waitlist import (landing page)

```bash
cd backend
WAITLIST_FILE=/path/to/waitlist.jsonl bun run scripts/import-waitlist.ts
```

Dedupes by lowercased email (`citext UNIQUE` at the storage layer too).

## 8. Ship tooling ([this-platform only] — do not rely on it)

`backend/publish.sh`, `go-live.sh`, `build-vercel.sh`, `vercel-entry.ts` belong
to the original sandbox/vercel hosting. For self-hosting, use the commands in
section 4 and terminate TLS at your reverse proxy. If you republish the site
elsewhere, `serve.ts` is the whole server (static client + SSR + `/api/ws`).