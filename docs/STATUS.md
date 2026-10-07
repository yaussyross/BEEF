# BEEF — Status (built vs. not yet)

Honest state of the project at handoff. "Verified" means pointed at in the repo
and confirmed working (this handoff re-verified the backend live);
"team-reported" means the team recorded the result but the artifact isn't in the
repo; "compiles only" means CI proves it builds but no one has run it.

## Built and verified

| Item | Where it lives | How it's verified |
|------|----------------|-------------------|
| Postgres schema, 8 migrations (16 tables) | `db/migrations/0001–0008` | Applied to a live Neon Postgres. This handoff re-ran the migration runner (no-op, prints schema verification) and the full schema is in the repo. |
| 18+ gate at the DB layer | `0005_triggers.sql` (`users_assert_adult`) | Schema applied; underage registration returned 403 in this handoff's live re-verification. |
| Backend: auth (register/login/refresh, bcrypt, JWT access+refresh) | `backend/src/routes/api/{register,login,refresh}.ts`, `src/lib/auth.ts` | Type-checked (CI) + live-tested (this handoff: register → login → 18+ rejection → rotate). |
| Backend: proximity grid (bucketed distance only) | `backend/src/routes/api/grid.ts`, `src/lib/privacy.ts` | Live-tested: distance returned as `"<1 mi"`-style strings, no lat/lng anywhere in the payload. |
| Backend: profiles (own + sanitised public view) | `backend/src/routes/api/{profile,profile.$id}.ts` | Live-tested: public profile has `is_adult`/`age_bucket`, no birthdate, no location. |
| Backend: 1:1 chat (WebSocket hub + REST fallback) | `backend/src/ws/chat.ts`, `src/lib/chat.ts`, `src/routes/api/{threads,threads.$id.messages}.ts` | Live-tested: WS send → sender ack + recipient delivery; REST history/send; idempotent `client_message_id`; blocked read refused 403. |
| Backend: block/report | `backend/src/routes/api/{block,report}.ts` | Live-tested: block excludes from grid, blocks chat read, unblocks. |
| Backend: moderation pipeline (text screen, image AI hook, queue + review routes) | `backend/src/lib/moderation.ts`, `ncmec.ts`, `src/routes/api/moderation.{queue,review}.ts` | Type-checked; queue route correctly 503s without `MODERATION_ADMIN_KEY` (by design). Image AI is env-gated and falls back to `pending_human`. |
| Full endpoint smoke suite | not committed (see note) | **Team-reported:** 83/83 checks passed in September 2026 against the live DB (also the source of the real enum-array bug fix — `::text[]` cast — now baked into the code). |
| CI green on `main` | `.github/workflows/ci.yml` | Backend job (build → type-check with the 5 tolerated `serve.ts` errors) + Flutter job (scaffold → analyze → debug APK). |

> **Smoke-suite note:** the 83-check suite was run by the team during Phase 1
> but was never committed to the repo. Do not claim it as a committed artifact.
> This handoff instead re-verified the same surface live with a 36-check
> script (register ×2, underage rejection, login, me, location, grid, public
> profile, threads, REST send + idempotency, history, block/unblock,
> moderation key-gate, and WS send/ack/delivery) — all passed. See
> `docs/RUNBOOK.md` for the manual commands.

## Built but not yet verified end-to-end

| Item | Where it lives | Verification ceiling |
|------|----------------|----------------------|
| Flutter slice 1 — app foundation, onboarding, mandatory 18+ gate, register/login/auth flow (~1,700 lines) | `app/lib/{main.dart, app.dart, auth/, api/, models/, screens/onboarding/, widgets/, theme/, config/}` | **CI compiles and analyzes it.** Nobody has run it on a device/emulator; no store assets linked to the running app. |
| Flutter slice 2 — grid, profiles, intent tags, interest discovery | `app/lib/{screens/grid_screen.dart, screens/profile_screen.dart, screens/home_screen.dart, widgets/{grid_tile.dart, discovery_filters.dart}, discovery/, models/{grid_profile.dart, intent_tag.dart, interest.dart, public_profile.dart}, api/discovery_api.dart}` | **CI compiles and analyzes it.** Same ceiling — built, not run. |

## Chat client increment (feature branch)

The Flutter inbox and conversation UI now exist in `app/lib/screens/` with
`chat/`, `api/chat_api.dart`, and typed chat models. The increment includes
WebSocket receive/send with HTTP fallback, stable retry IDs, history pagination,
moderation-safe display, block handling, and foreground/resume behavior.
`app/test/` adds isolated API, controller, and widget regressions; CI runs them.
This is not a live-backend or two-device verification claim. Current validation
results belong to the feature PR; private beta still needs a real-device pass.

## Not built (unstarted)

| Item | Notes |
|------|-------|
| Block/report and privacy-settings UI | Backend endpoints exist; no client UI. |
| Profile rating system ("Rate this Guy") | 1–5 stars, unlocked after a real 5-minute chat, re-rateable (latest vote wins), aggregate shown next to username. Schema, endpoint, and client prompt are **all unstarted** — no rating tables exist in `db/migrations/`. |

## Also true (from the owner-endorsed plan, mapped to reality)

- Landing page: built and live (BEEF brand, "A cut above the rest.", six model
  images, email waitlist). Store-ready assets (icon, screenshots, onboarding)
  exist under the team's design work, not in `main` — they were produced for the
  store without a committed home in this repo.
- Friends mode: the `friends` intent tag exists end-to-end (enum, profile
  column, grid filter); no separate "friends mode" UI/phasing.
- Photo verification: `photo_verification_status` exists in schema + API
  surfaces; no verification flow UI.
- AI-blur moderation: text screening + image hook + `blurred` states exist
  server-side; client re-do prompt not built.
- Prompts and the consent-friendly discovery lane (plan's feature pack): not
  present in this codebase.
- Monetization (native/direct → house ads → AdMob no-location): `ad_inventory`
  schema exists only; no ad serving or SDK work.

## Platform-only items (do NOT transfer)

- The published site URL and the original sandbox's port-3000 hosting setup.
  `backend/publish.sh`, `go-live.sh`, `build-vercel.sh`, `vercel-entry.ts` are
  ship tooling for the old host; re-host on your own infra.
- Owner accounts (Apple Developer, Google Play, Firebase) — not yet created.