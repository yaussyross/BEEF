# BEEF — ChatGPT Launch Pack

What to paste into ChatGPT to hand the project over, in three parts.
All factual claims mirror the repo, especially `docs/STATUS.md`
(built-vs-not-yet), `docs/BUSINESS.md` (owner-endorsed plan) and
`docs/HANDOFF.md` (handoff). The repo is **public** — never mention or commit
secrets.

---

## Part 1 — Project instructions (paste into a ChatGPT Project or custom instructions)

**What BEEF is.** BEEF is a free, ads-supported gay male social app for friends,
dates, and hookups — a grid-based proximity app in the spirit of Grindr, but
with original branding, personality, and features ("a cut above the rest.").
The product leans into camp, wit, and style; privacy-first is the key
differentiator and legal shield. The business plan is `docs/BUSINESS.md`
(owner-ratified); read it and `docs/HANDOFF.md` first.

**Where the code lives.** The repository is `yaussyross/BEEF` on GitHub
(public). It is a monorepo: `backend/` (Bun + TypeScript API), `app/` (Flutter
client), `db/migrations/` (Postgres schema), `design/` (brand briefs + store
assets), `docs/` (all project documentation). If you cannot clone it, the
owner can upload the exported ZIP instead (see the export README).

**What is built and verified vs compiles-only vs unstarted** (mirrors
`docs/STATUS.md` exactly):
- *Verified:* Postgres schema — 8 migrations, 16 tables, applied to a live
  Neon Postgres; 18+ gate enforced at the DB layer (underage registration
  returns 403); backend auth (register/login/refresh, JWT), proximity grid
  (bucketed distance only — no lat/lng in any payload), profiles (sanitised
  public view), 1:1 chat (WebSocket + REST fallback, idempotent sends,
  block-aware), block/report, and the moderation pipeline (text keyword
  buckets, env-gated image AI hook, queue + review routes) — all live-tested
  end-to-end; CI is green on `main` (backend + Flutter jobs).
- *Compiles only (never run on a device):* the Flutter app — slice 1
  (foundation, onboarding, mandatory 18+ gate, auth flow, ~1,700 lines) and
  slice 2 (grid, profiles, intent tags, interest discovery). CI builds and
  analyzes them; nobody has run them.
- *Unstarted:* in-app chat UI (backend exists), block/report + privacy-settings
  UI (backend exists), the profile rating system ("Rate this Guy" — 1–5 stars,
  unlocked after a real 5-minute chat, re-rateable with latest vote winning,
  aggregate shown next to the username; schema/endpoint/prompt all unstarted).
  The landing page and store-ready assets exist; the published landing-page URL
  was platform-only and does not transfer.

**Hard constraints — never violate.**
1. 18+ gate is enforced at the DB/API layer (`users_assert_adult` trigger) — do
   not weaken or bypass it.
2. Precise location never leaves the server; clients receive bucketed distance
   strings only.
3. No third-party ad SDK receives location in v1 — architecture rule.
4. Content is suggestive, never explicit (store-policy and brand requirement) —
   see `docs/RESEARCH.md`.
5. No copy of Grindr's trade dress (colors, tiles, icons, name) — original
   branding only.
6. Never commit secrets, tokens, or connection strings (repo is public); use
   `.env.example` as the template.
7. Never invent metrics, users, or testimonials — in code, docs, or copy.
8. Moderation keyword lists and the `ncmec.ts` stub stay in place; the stub
   does not transmit anything.

**How to work in the repo.** Read `AGENTS.md` — it is the operating manual.
Work on a feature branch, open a PR, and only merge when CI is green. The
Flutter app compiles only in CI (GitHub Actions) — this environment cannot
build it, so never claim a Flutter change "works"; claim it "passes CI".
Follow `docs/ROADMAP.md` for priorities; update `docs/STATUS.md` when
something ships. Keep the tree clean on the default branch.

**Environment variables.** The owner supplies these — the database is
disposable because `db/migrations/` rebuilds the entire schema, and it
currently holds **no data** (zero users, zero waitlist rows):
- `DATABASE_URL` (required — Neon/Postgres connection string)
- `JWT_SECRET` (required, ≥32 chars)
- `MODERATION_ADMIN_KEY` (optional; unset → moderation admin routes 503 by design)
- `IMAGE_MODERATION_API_KEY` (optional; unset → image moderation returns
  `pending_human`)
- Flutter's API base URL is a compile-time `--dart-define=BEEF_API_BASE_URL=…`,
  not an env file. See `.env.example` and `docs/RUNBOOK.md`.

---

## Part 2 — Kickoff prompt (first message, ~120 words — copy verbatim)

> "Read `docs/HANDOFF.md` first, then `AGENTS.md`. Clone or sync the BEEF
> repository (`yaussyross/BEEF`). Stand up the backend locally per
> `docs/RUNBOOK.md` using the env vars I supply — if I have not supplied them
> yet, tell me exactly which ones you need and wait. Then start the
> highest-priority unstarted item from `docs/ROADMAP.md` Phase 1: the Flutter
> in-app chat UI (inbox + chat screens against the verified WebSocket/REST
> chat backend). Work on a feature branch, keep commits small and grounded in
> the repo, and open a PR when the slice is coherent. Do not invent metrics,
> users, or features; if anything in the repo contradicts what you assume, say
> so and ask before proceeding."

---

## Part 3 — Getting set up (short)

- **Give ChatGPT the code:** connect the GitHub repo (simplest — it's public
  and CI runs there), or paste/upload the exported ZIP from the release; both
  contain the same tree. The ZIP also includes `BEEF-history.bundle` (full git
  history) and `EXPORT-README.md` (exact commands).
- **First run expectations:** the first message should be Part 2 above. ChatGPT
  will read the handoff, ask you for the four env vars (`DATABASE_URL`,
  `JWT_SECRET`, and optionally `MODERATION_ADMIN_KEY`,
  `IMAGE_MODERATION_API_KEY`), and start the chat UI on a feature branch. It
  cannot compile the Flutter app here — CI on the PR is the proof.
- **Order of work from `docs/ROADMAP.md`:** (1) chat UI, (2) block/report +
  privacy-settings UI, (3) "Rate this Guy" (schema → endpoint → prompt), (4)
  bundle store assets/fonts into the app, (5) store-compliance pass, then
  Phase 2 (you create Apple Developer, Google Play, and Firebase accounts) →
  private beta → Phase 3 store submission → Phase 4 launch + v1.1
  monetization (native/direct → house ads → AdMob with no location).