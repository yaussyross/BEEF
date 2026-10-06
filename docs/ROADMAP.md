# BEEF — Roadmap (working checklist)

The plan of record for what happens next, consistent with `docs/BUSINESS.md`
(owner-endorsed) and `docs/STATUS.md` (the honest built-vs-not-yet table).
This is a **checklist, not marketing**: every item maps to a concrete artifact
or owner action. Status of each item is tracked against `docs/STATUS.md`;
update both together when an item ships.

Legend: ✅ done (see STATUS.md) · ⬜ not started · 🔶 in progress

---

## Phase 1 — MVP build (in progress)

### 1.1 Backend + schema — DONE (see STATUS.md for how each is verified)
- ✅ Postgres schema, migrations `0001–0008` (16 tables) applied to a live Neon DB
- ✅ 18+ gate at the DB layer (`users_assert_adult` trigger; underage = 403)
- ✅ Auth: register / login / refresh (bcrypt, JWT access + refresh)
- ✅ Proximity grid (bucketed distance only — no lat/lng ever leaves the server)
- ✅ Profiles (sanitised public view: `is_adult`, `age_bucket`, no birthdate/location)
- ✅ 1:1 chat (WebSocket hub + REST fallback, idempotent `client_message_id`, block-aware)
- ✅ Block / report endpoints
- ✅ Moderation pipeline (text keyword buckets, image AI hook env-gated, queue + review routes)
- ✅ `ncmec.ts` stub wired into the report flow (see Store-compliance pass below)

### 1.2 Flutter client — remaining work (all ⬜)
Ordered by dependency; the first is the highest-priority unstarted item in the repo.

1. ⬜ **In-app chat UI** — inbox/thread screens + WebSocket client for
   `backend/src/ws/chat.ts` with REST fallback (`threads…` routes). Backend is
   verified; the client screens do not exist (`app/lib/` has no thread/message
   screens). Uses the already-pinned `web_socket_channel: ^3.0.1` dependency.
   - [ ] Thread list screen (inbox)
   - [ ] Chat screen (message bubbles, send, typing/ack states)
   - [ ] WS connect/retry + refresh-on-401 client plumbing
   - [ ] In-chat entry points to block/report (hook into 1.3)
2. ⬜ **Block/report + privacy-settings UI** — client screens calling the
   verified `block` / `report` endpoints; privacy/trust settings surfaced in-app
   (coarse-location modes, hide-distance toggle, opt-in sharing — whatever the
   API exposes; see `backend/src/lib/privacy.ts`).
3. ⬜ **Profile rating system ("Rate this Guy")** — fully unstarted:
   - [ ] Migration `0009` — ratings table (rater, ratee, stars 1–5, created_at,
         unique on (rater, ratee))
   - [ ] Endpoint — POST rating, **unlocked only after a real ≥5-minute chat**
         thread exists between the pair; re-rating allowed, **latest vote wins**;
         aggregate shown next to the username on the recipient's public profile
   - [ ] Client prompt + stars UI ("Rate this Guy")
   - [ ] Grid/profile display of the aggregate rating
4. ⬜ **Bundle store assets into the app** — link the shipped fonts
   (`design/store/fonts/`: Unbounded + Space Grotesk) per the note in
   `app/lib/theme/app_theme.dart`; wire icon/onboarding screens into the build.
5. ⬜ **Feature-pack leftovers mapped to built components** — photo-verification
   UI (API + schema field exist), AI-blur client re-do prompt (server-side states
   exist), prompts + consent-friendly discovery lane (not present in code).

### 1.3 Store-compliance pass (explicit checklist — do not skip)
Both stores treat dating apps as 17+/mature and **ban sexually explicit content**;
ad revenue and distribution both depend on this pass (see `docs/RESEARCH.md`).

- [ ] **Moderation keyword lists** — keep the three buckets in
      `backend/src/lib/moderation.ts` current (commercial-sex / escort
      solicitation matters under FOSTA–SESTA); review before every store submit
- [ ] **NCMEC stub** — `backend/src/lib/ncmec.ts` currently **does not
      transmit** anything; it exists so the report flow has a named call site.
      Wire a real CyberTipline submission (credentialed, non-résumé) before
      public launch — legal prerequisite, not optional
- [ ] **Content rule: suggestive, never explicit** — enforced in imagery
      (six tasteful model photos), copy, and UGC moderation; audit before submit
- [ ] **18+ gate demonstrable** — DB-layer trigger + onboarding gate; stores will
      ask; document the flow
- [ ] **Submission kit** — privacy policy, data-safety/age-rating forms,
      moderation declaration, screenshot set from `design/store/`

### 1.4 QA + beta-readiness gate
- [ ] CI green on the Flutter app build (`.github/workflows/ci.yml`)
- [ ] Manual QA on a device/emulator (nothing Flutter has been run yet — CI
      compiles only)
- [ ] Smoke the whole backend surface against a fresh DB from `db/migrations`

**Exit criteria for Phase 1:** chat UI, block/report + privacy UI, and the
rating system all built; CI green; compliance checklist above reviewed.

---

## Phase 2 — QA + private beta (owner accounts are the hard dependency)
- [ ] **Owner creates accounts** (identity/legal requirement — BEEF cannot):
      Apple Developer ($99/yr), Google Play ($25 one-time), Firebase (push)
- [ ] TestFlight (iOS) + Play internal testing (Android) builds from the same
      Flutter codebase
- [ ] Beta cohort from the landing-page waitlist — the DB currently holds
      **zero waitlist rows**; the import tool
      (`bun run scripts/import-waitlist.ts`) exists but has nothing to import yet
- [ ] Moderation tuning from real-user feedback; safety review

## Phase 3 — Store submission
- [ ] Complete the submission kit (1.3) for App Store + Google Play
- [ ] Submit, handle rejections (normal for this category), revise, resubmit

## Phase 4 — Launch + v1.1 monetization
- [ ] Public launch (both stores)
- [ ] **v1.1 ad ladder, in order:**
      1. Native/direct partnerships with LGBTQ-friendly brands (primary,
         per research)
      2. House ads / own-brand placements (zero cost, `ad_inventory` schema
         already exists in `0003_tables.sql`)
      3. AdMob — **with no location passed** (architecture rule: no third-party
         ad SDK ever receives precise location)
- [ ] Optional light perks later (keeps the "free core" promise)

---

## Standing rules for every phase
- Never commit secrets (repo is public); use `.env.example` as the template
- Feature branch → PR → CI green → merge; Flutter compiles only in CI
- Update `docs/STATUS.md` whenever something moves from ⬜ to ✅
- Never invent metrics, users, or testimonials in copy or docs