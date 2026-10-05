# BEEF

**A cut above the rest.** BEEF is a free, ads-supported gay male social app for
friends, dates, and hookups — campy, stylish, and privacy-first by design.

This is a monorepo holding both codebases plus the database schema:

```
.
├── backend/     Bun + TanStack Start — the landing site AND the app's REST API + WebSocket hub
├── app/         Flutter app (one Dart codebase → Android + iOS)
├── db/          Postgres schema migrations + migration runners
├── .github/     CI (GitHub Actions)
└── README.md    you are here
```

> **CI is the only place the Flutter app is compiled.** The team sandbox can't
> run the Flutter SDK (2.48 GB unpacked, extraction fails on its overlay FS), so
> every push to a PR runs `flutter analyze` + `flutter build apk --debug` on
> GitHub Actions. Write Flutter source freely in the sandbox; CI proves it
> compiles.

---

## Backend (`backend/`)

The Bun + TanStack Start app. It serves the landing page and the mobile API.

```bash
cd backend
bun install            # first time
bun run dev            # dev server on :3000 (hot reload)
bun run build          # production build → dist/
bun run start          # serve the built site (+ /api/ws WebSocket)
```

Layout highlights:

- `src/routes/` — filesystem routes: landing page (`/`) and REST API (`src/routes/api/*`).
- `src/lib/` — auth, chat, moderation, privacy, ncmec, http helpers.
- `src/ws/chat.ts` + `serve.ts` — the 1:1 chat WebSocket hub (Bun-level; wired
  through `Bun.serve({ websocket })` at `/api/ws`).
- `src/db.ts` — server-only `sql()` handle over `DATABASE_URL` (Neon Postgres).

### Type-check note

`bunx tsc --noEmit` (or `node_modules/.bin/tsc --noEmit`) reports **exactly five
pre-existing errors, all in `serve.ts`**, because that file uses Bun-only globals
(`Bun.*`, `import.meta.dir`) under the site's Vite/`@types/node` tsconfig. These
five are intentional and tolerated by CI. `src/` (including `src/ws/chat.ts`)
type-checks clean. Do not add new type errors.

### Scripts

| script | what it does |
|--------|--------------|
| `bun run dev`   | Vite dev server on `0.0.0.0:3000` |
| `bun run build` | production client + SSR build into `dist/` (no secrets needed) |
| `bun run start` | serve the built site + chat WebSocket |
| `bun run publish` / `go-live` | platform-specific ship tooling (see `SITE.md`) |

---

## Flutter app (`app/`)

One Dart codebase → both stores. Source is authoritative in `app/lib/` +
`app/pubspec.yaml` + `app/analysis_options.yaml`.

```bash
cd app
flutter pub get
flutter analyze          # must be clean — CI gates on this
flutter build apk --debug   # Android compile proof
flutter build appbundle     # Android release
flutter build ipa           # iOS release (needs signing on a Mac)
```

The `android/` and `ios/` platform folders are **not committed** — they are
generated on CI (and on any machine with Flutter installed):

```bash
flutter create . --org com.beef --project-name beef --platforms android,ios
```

CI generates those folders in a throwaway directory and copies only the platform
scaffolding back, so the hand-written `lib/` and `pubspec.yaml` are never
clobbered. See `app/README.md` for the full client architecture and privacy
invariants.

---

## Database (`db/`)

Idempotent Postgres migrations (`0001..0008`), applied in filename order with a
`schema_migrations` version table.

```bash
cd db
YOUR_DATABASE_URL=postgres://... bash migrate.sh     # if psql is available
```

Bun runner (no `psql` needed — the sandbox path):

```bash
# from the repo root
bun install                       # installs @neondatabase/serverless (root package.json)
DATABASE_URL=postgres://... bun db/migrate.ts
# or: DATABASE_URL=... bun run db:migrate
```

**Migrations are never run in CI.** CI is compile/type-check/build only — it
does not touch the live database and needs no secrets.

---

## CI (`.github/workflows/ci.yml`)

Two jobs, deterministic, **no secrets**:

1. **backend** — `bun install` → `tsc --noEmit` (fails on any error other than
   the 5 known `serve.ts` Bun-global errors) → `bun run build`.
2. **flutter** — installs Flutter (pinned stable `3.47.2`) → generates platform
   folders → `flutter pub get` → `flutter analyze` (must be clean) →
   `flutter build apk --debug`. iOS is gated by `analyze` only; an iOS build
   needs signing certs and is not done in CI for now.

CI intentionally does **not** run live-DB migrations, smoke tests, or anything
requiring `DATABASE_URL` / `JWT_SECRET`.

---

## Branding

Original throughout — BEEF's own campy, bold, stylish voice and palette. A
proximity grid is a product pattern; nothing here reproduces Grindr's trade
dress (colors, tiles, icons, or name). No counterfeit claims.