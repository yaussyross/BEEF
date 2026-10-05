# BEEF — Business Plan

**Revision 6 — ratified by the owner on 2026-09-01.** Reproduced verbatim from
the owner-endorsed plan.

---

## What we're building

BEEF is a free, ads-supported gay male social app for friends, dates, and hookups — a grid-based proximity app in the spirit of Grindr, but with its own branding, personality, and features so it's clearly *inspired by*, not a copy of, anyone. The whole product leans into camp, wit, and style: bold typography, playful copy, and a confident aesthetic made for gay men.

## Current state

The MVP landing page is built and published live: campy one-pager with the BEEF brand, the headline "A cut above the rest.", all six on-brand model images, and a working email waitlist. Aesthetic direction (palette, fonts, voice) set the full app style.

The app is a native Flutter app (one Dart codebase → both stores). The backend evolves the existing Bun/TanStack site into the app's API, backed by a connected Postgres (Neon). Phase 1 is well underway and the backend is now verified live: the full database schema (16 tables, privacy-safe geolocation, moderation, 18+ gate at the DB layer) plus auth, proximity grid, profiles, 1:1 chat (WebSocket), block/report, and the moderation pipeline are all written and type-checked. Migrations applied to the live database and every endpoint smoke-tested end-to-end (83/83 checks passed, one real bug found and fixed: Postgres enum arrays were silently dropping intent tags, corrected with a `::text[]` cast). The Flutter client is scaffolded and its first slice (foundation + onboarding/18+ gate + auth flow, ~1,700 lines) is written. Store-ready assets (icon, screenshots, onboarding) are done.

## Build dependencies — both now cleared

1. **Database** — `DATABASE_URL` is connected; the backend runs and passes its full smoke suite against real data.
2. **GitHub repo + CI** — repo `yaussyross/BEEF` is linked; the monorepo (backend + Flutter + migrations) is committed and CI is being finalized so the Flutter app (which the sandbox cannot compile) gets built and verified on GitHub Actions.

## How it works (research-informed)

- Free to use; revenue from ads (in-app + placements), treated realistically. Research found the category is store-policy-constrained: Google AdMob and Apple allow dating apps at 17+/18+ but ban sexually explicit content; Google AdSense (web display) is unavailable for dating entirely. So the app must be suggestive-not-explicit, moderated, and 18+ gated, and ad revenue is a secondary engine — the more realistic value is native/direct partnerships with LGBTQ-friendly brands plus light optional perks, not plain banner ads.
- Privacy-first is our differentiator and our legal shield. Grindr drew a Norway GDPR fine and a 2024 FTC settlement for sharing precise location and HIV-status data with ad partners. BEEF's trust story — never selling location to advertisers, coarse-location modes, opt-in sharing — is central to the brand, and it's enforced in the architecture (location lives server-side; grid returns bucketed distance only; no third-party ad SDK receives location in v1).
- Core loop: nearby profiles, chat, friends/date/hookup intent tags, interest-led discovery. Differentiators: intent tags, community, privacy/trust defaults, safety moderation, and a profile rating system ("Rate this Guy").
- Original branding throughout — a proximity grid is fine, but no copy of Grindr's trade dress (colors, tiles, icons, name) and no fake claims.

## MVP milestone (Phase 1, in progress)

Onboarding + 18+ gate, proximity grid, profiles, intent tags, interest-led discovery, 1:1 chat (TLS), privacy/trust defaults, safety/moderation, and profile ratings (1–5 stars, unlocked after a real 5-minute chat, re-rateable — latest vote wins — with the aggregate ranking shown next to the username) — with the MVP feature pack folded in (friends mode, photo verification, AI-blur moderation, a consent-friendly discovery lane, prompts). Phase 2 is QA + private beta (TestFlight/Play internal); Phase 3 store submission; Phase 4 launch + v1.1 monetization (native/direct → house ads → AdMob no-location).

## Remaining before Phase 2 (QA/beta)

Finish the Flutter client (grid/profiles/chat UI + the rating prompt), CI green on the app build, then the Apple Developer + Google Play + Firebase accounts (owner) for release and push.

---

*Update note (this handoff): the plan text above was written before Flutter
slice 2 landed; slice 2 (grid, profiles, intent tags, interest discovery) is
merged into `main`. The chat UI — which the plan groups under "finish the
Flutter client" — is still unstarted. See `docs/STATUS.md` for the exact
built-vs-not-yet state.*