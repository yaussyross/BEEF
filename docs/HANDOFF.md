# BEEF — Handoff

**BEEF** is a free, ads-supported gay male social app for friends, dates, and
hookups — a grid-based proximity app (in the spirit of Grindr, but with its own
branding, personality, and features) that is *privacy-first by design*: precise
location never leaves the server, clients only ever receive coarse distance
buckets, and no third-party ad SDK receives location in v1. Content is campy,
stylish, and suggestive-not-explicit so the app can pass App Store / Google Play
dating-app review at 17+/18+.

This repository is the **complete handoff** — everything needed to understand,
run, and continue the project. Anyone (human or AI) who clones `main` should
start here and read the docs in the order below.

---

## What's in this repo

```
.
├── docs/            ← start here: HANDOFF, BUSINESS, ARCHITECTURE, STATUS, RUNBOOK
├── backend/         Bun + TanStack Start — the landing site AND the app's REST API + WebSocket chat hub
├── app/             Flutter client (one Dart codebase → Android + iOS)
├── db/              Postgres migrations (0001–0008, idempotent) + runners
├── .github/workflows/ci.yml   CI (backend type-check/build + Flutter analyze/build)
├── .env.example     all env vars the codebase reads (placeholders only)
├── AGENTS.md        operating rules for anyone (especially AI agents) working here
└── README.md        short overview + pointer to this file
```

## Current state (verified)

- **Backend: built and verified live.** All 8 migrations are applied to a live
  Postgres (Neon). Auth (JWT), the proximity grid, profiles, 1:1 chat
  (WebSocket + REST fallback), block/report, and the moderation pipeline are
  written, type-checked, and were re-verified end-to-end against the live
  database in this handoff (36/36 automated checks) — see `docs/STATUS.md`.
  A full endpoint smoke suite was reported by the team as **83/83 checks
  passed** in September 2026 (team-reported; the suite itself is not committed —
  see `docs/STATUS.md` and `docs/RUNBOOK.md`).
- **CI is the proof for everything that can't run here.** GitHub Actions builds
  the backend (type-check + build) and compiles the Flutter app (analyze +
  debug APK). CI is green on `main`.
- **Flutter client: built, not yet run on a device.** Slice 1 (foundation +
  onboarding/18+ gate + auth, ~1,700 lines) and slice 2 (grid, profiles,
  intent tags, interest discovery) exist in `app/lib/` and pass CI
  compilation/analysis, but nobody has run the app on a device or emulator yet.
- **Not built yet:** the in-app chat UI (the backend WebSocket works), the
  block/report and privacy-settings UI, and the profile rating system
  ("Rate this Guy" — schema, endpoint, and prompt are all unstarted).

## What to do next (priority order)

1. **Read the docs** in the order below (~10 minutes).
2. **Bring the backend up locally** (`docs/RUNBOOK.md`) and confirm the
   endpoints answer. Everything needed is in `.env.example`.
3. **Finish the Flutter client:** the chat UI (backend is done — Wire
   `lib/screens/` to `src/ws/chat.ts` over `/api/ws`), the block/report and
   privacy settings UI, and the "Rate this Guy" rating system (schema +
   endpoint + prompt).
4. **Get CI green on app builds** (already green on `main`; keep it that way —
   every PR runs the Flutter compile).
5. **Owner accounts for release:** Apple Developer, Google Play, and Firebase
   (push) are needed before Phase 2 (private beta via TestFlight / Play
   internal). Not yet created.
6. **Store-compliance pass before submission:** review the moderation keyword
   lists in `backend/src/lib/moderation.ts`, wire the real NCMEC CyberTipline
   submission (`backend/src/lib/ncmec.ts` is a stub that does NOT transmit),
   and confirm content stays suggestive-not-explicit.

## Read these in this order

| Doc | What it gives you |
|-----|-------------------|
| [`docs/BUSINESS.md`](BUSINESS.md) | The owner-endorsed business plan, verbatim (what/why, revenue reality, privacy strategy, phased roadmap). |
| [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) | How the code actually works: route map, WebSocket hub, auth, the privacy model, moderation pipeline, database. |
| [`docs/STATUS.md`](STATUS.md) | Honest built-vs-not-yet table — what is verified, what compiles only, what does not exist. |
| [`docs/RUNBOOK.md`](RUNBOOK.md) | Copy-paste commands to run everything, each verified in this handoff where possible. |

`AGENTS.md` (repo root) is the rulebook — read it before writing any code.

## Platform caveats

A few things in this repo were tied to the team's original sandbox platform and
do **not** transfer: the published site URL, the `backend/publish.sh` /
`go-live.sh` / `build-vercel.sh` ship tooling, and the Vercel entry point
(`backend/vercel-entry.ts`). They are marked "[this-platform only]" where they
appear. The next owner should re-host the landing site + API on their own host;
the code itself is portable Bun + TanStack Start.