# Existing product completion plan

Goal: complete the existing approved flows for a private synthetic test without rewriting the app or granting live access.
Architecture: extend the existing Flutter screens, Bun routes and PostgreSQL contracts. Preserve server-side authentication, privacy, report idempotency and content holds.
Spec: docs/BUSINESS.md, docs/ROADMAP.md and the October 26 owner decisions recorded in docs/LAUNCH-READINESS-2026-10-26.md. Latest instructions retain closed synthetic testing and withhold public rating exposure and specialized moderation policy.
Execution: inline in the preserved working branch; existing user instruction authorizes implementation without another design approval round.

## Concrete acceptance gaps

- Profile editing: no client editor; API lacks display-name editing, accepts invalid bio types and validates interests after writing other fields. Add validated atomic updates and editor using existing intent/interest vocabulary.
- Safety: add own block list/unblock management and message-specific report entry points, preserving stable retry IDs and metadata-only containment.
- Test build: remove legacy public host default; make an unconfigured build visibly inert; retain a secret-free debug APK artifact through the approved review workflow if permissions allow. Actual target URL/access remains a setup gate.
- Brand: bundle existing fonts; no new downloaded assets.
- Verification: add targeted API/database and Flutter regressions, run current aggregate local suites; verify exact new CI head if permitted.
- Deployment preparation: exact environment/access/restore/acceptance contract, synthetic fixtures, no provisioning or credentials.

## Remaining consequential decisions, not silently implemented

- Public rating aggregates: original plan requires display next to names but later instructions explicitly hold public exposure. Owner must settle visibility/abuse/appeal requirements before enabling.
- Photo uploads and verification: schema/status fields exist, but no storage/verification provider or reviewer procedure. No false verified badge or unaudited public media path.
- Prompts and consent lane: only named in business plan, no consent lifecycle/visibility semantics; require definition, not arbitrary sensitive fields.
- Account deletion/evidence retention/recovery delivery: specify retention and recovery channel before destructive or external behavior.
- Specialized urgent review: credible-danger/release criteria, deadlines and escalation procedure remain undefined; no harmful previews, live admin credentials or external reporting.

## Review focus

Invalid mixed profile updates must make no partial changes; simultaneous updates must not erase unrelated fields; blocked lists must reveal no profile/contact/location details; report retries must preserve the selected message and request identity; unconfigured mobile builds must make no requests to a historical host.

## Tasks

- [x] Add failing integration coverage for atomic profile validation and caller-scoped block list; implement and verify.
- [x] Add Flutter editor, block management and exact-message reporting with loading/error/retry/disabled-account regression coverage.
- [x] Prepare inert configuration, bundled assets and reproducible test artifact; run verification.
- [x] Reconcile historical docs with current results and exact external setup gates.


Review ledger: independent review identified flagged profile names and an existing
privacy geometry race; both reproduced with real API/DB regressions and fixed.
A location-only update also reset hide-distance; it was reproduced and fixed.
Synthetic test-area selection makes the closed test grid usable without any
real device location collection. New final-head CI must verify that follow-up.
Client tests were authored locally and executed in permitted CI because local
Flutter remains unavailable; no denied download was retried. Native real-data
location, photo/verification lifecycle, aggregate publication, prompt/consent
semantics and account retention/recovery remain explicitly unfinished.
