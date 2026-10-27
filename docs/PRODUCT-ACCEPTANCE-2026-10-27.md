# Product acceptance audit — 27 October 2026

This is the current acceptance map. Earlier dated handoff/live/CI statements are
historical. PR #5 remains untouched; PR #6 combines both tracks without merging
main. Starting verified PR head was 8a0036f (53 Flutter tests and debug APK in CI
run 40385963128). This follow-up requires its own CI result.

## Current implementation and verification

| Flow | Implemented | Verification ceiling |
|---|---|---|
| Adult registration/login, grid, public profiles, friends mode | Yes | Real synthetic API/DB tests; Flutter CI; no device pass |
| Profile editor, display name, bio, tags/interests | Added in this follow-up | Local API validation/concurrency/rollback checks; new Flutter tests pending CI |
| Interest chips | Fixed: selected slugs filter actual profile interests server-side | New real API and Flutter stale-response tests |
| Chat/history, retries, socket/session status enforcement | Yes | Real isolated HTTP/WS tests, Flutter regressions; no two-device pass |
| Private rating eligibility/save/re-rate | Yes, 1–5, latest vote wins; mutual messages spanning five minutes | DB/API boundary tests and Flutter CI |
| Block/report/privacy | Yes; block list/unblock and specific-message reporting added | API authorization/privacy plus new Flutter confirmation/retry tests |
| Urgent reports | Targeted message holds; account/thread-only accusations queue urgently | Atomic rollback/idempotency, metadata-only queue, restoration guards tested |
| Test configuration | Legacy host removed; no-config build is inert; explicit HTTPS build script | New config test; no configured hosted build yet |
| Fonts | Existing Unbounded/Space Grotesk bundled | Requires updated Flutter build |
| Runtime/waitlist | Explicit config, health/readiness, graceful stop, durable DB waitlist | Local runtime/browser/API/DB tests |

## Unfinished acceptance criteria

These are real gaps; the product is not complete merely because its APK builds.

1. **Location acquisition:** Flutter has no location permission/acquisition flow.
   Grid requires a location set through the API; closed-test fixtures must supply
   synthetic coordinates. Real-device location collection is outside the current
   synthetic-data boundary. No fabricated proximity claim should be made.
2. **Public rating aggregates:** required in the original business plan, but later
   instructions explicitly withheld public exposure. Set visibility, minimum
   count/abuse protection and correction/appeal rules before enabling it.
3. **Photos/verification:** schema and moderation hooks are not a working upload,
   storage, review or verification lifecycle. Choose approved private storage and
   define what a verified badge attests to; do not create fake verification.
4. **Prompts/consent lane:** business plan names these without lifecycle or sharing
   semantics. Specify prompts and what opt-in/revocation does; no sensitive fields
   or implied consent are invented by this implementation.
5. **Account lifecycle:** recovery channel and deletion/evidence-retention policy
   are undefined. No email provider, destructive deletion or retention promise is
   silently introduced.
6. **Moderation operations:** Ross intends to review, but specialized urgent
   review/release criteria, deadlines, evidence permissions and escalation remain
   undefined. No harmful media previews, external reporting or live admin access.
7. **Private host:** approved free/account capacity, HTTP and WebSocket access
   restriction, TLS origin, staging database/secret storage, backups/restore,
   monitoring and abuse limits must be established before device staging.
8. **Distribution/device QA:** no configured APK delivered, no two-device test,
   no iOS/signing/store submission. CI currently compiles but does not retain APKs.

## Exact next human-only inputs

- Hosting target/account and verified no-cost capacity; authorization for the
  specific deployment and staging-only database/schema/data persistence.
- Separate permission to create/store JWT and moderator secrets in that target;
  access-restricted reviewer/tester identity setup. No credentials in chat/git.
- Approved private HTTPS/WSS origin and two devices/testers for the acceptance
  script in CLOSED-TEST-ACCEPTANCE.md, using synthetic adult accounts only.
- Product/operational decisions in items 2–6 above. Public launch, real-user
  collection, paid accounts and invitations remain unapproved.

The local container suites need none of these external permissions. They use
fresh disposable synthetic PostgreSQL data and remove it when done. No public
launch, merge, paid resource, persistent access or real-user processing occurred.
