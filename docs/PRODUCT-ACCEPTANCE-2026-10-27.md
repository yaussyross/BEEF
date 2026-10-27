# Product acceptance audit — 27 October 2026

This is the current acceptance map. Earlier dated handoff/live/CI statements are
historical. PR #5 remains untouched; PR #6 combines both tracks without merging
main. Starting verified PR head was 8a0036f (53 Flutter tests and debug APK in CI
run 40385963128). This follow-up requires its own CI result.

## Current implementation and verification

| Flow | Implemented | Verification ceiling |
|---|---|---|
| Adult registration/login, grid, public profiles, friends mode | Yes | Real synthetic API/DB tests; Flutter CI; no device pass |
| Profile editor, display name, bio, tags/interests | Added in this follow-up | Local API validation/concurrency/rollback checks; Flutter tests passed at 420ced8 |
| Interest chips | Fixed: selected slugs filter actual profile interests server-side | Real API and Flutter stale-response tests passed at 420ced8 |
| Chat/history, retries, socket/session status enforcement | Yes | Real isolated HTTP/WS tests, Flutter regressions; no two-device pass |
| Private rating eligibility/save/re-rate | Yes, 1–5, latest vote wins; mutual messages spanning five minutes | DB/API boundary tests and Flutter CI |
| Block/report/privacy | Yes; block list/unblock and specific-message reporting added | API authorization/privacy and Flutter confirmation/retry tests passed at 420ced8 |
| Urgent reports | Targeted message holds; account/thread-only accusations queue urgently | Atomic rollback/idempotency, metadata-only queue, restoration guards tested |
| Test configuration | Legacy host removed; no-config build is inert; explicit HTTPS build script | Config test and APK build passed at 420ced8; no configured hosted build yet |
| Fonts | Existing Unbounded/Space Grotesk bundled | Flutter build passed at 420ced8 |
| Runtime/waitlist | Explicit config, health/readiness, graceful stop, durable DB waitlist | Local runtime/browser/API/DB tests |

## Unfinished acceptance criteria

These are real gaps; the product is not complete merely because its APK builds.

1. **Location acquisition:** closed-test area selection is now implemented with
   explicit fictional fixture coordinates, no GPS permission and no device data.
   Location-only updates preserve hide-distance and coarse-mode choices. Native
   one-shot acquisition, denial/service/timeout handling and generated platform
   permissions are implemented behind BEEF_ENABLE_DEVICE_LOCATION=false. The
   closed-test build never requests GPS. Real-data enablement and physical-device
   permission testing remain unapproved/unrun. No real proximity claim is made.
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
   no iOS/signing/store submission. The follow-up workflow is configured to retain a secret-free unconfigured debug APK for one day; it opens only the setup screen until rebuilt for an approved private origin.

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


## Build artifact safety and cost basis

The repository metadata was rechecked as public with push permission on October
27. Existing standard ubuntu-latest runners are used. GitHub documents public
repository standard-runner Actions usage as free:
https://docs.github.com/en/actions/concepts/billing-and-usage
The APK artifact has one-day retention, includes only the named APK, and uses
upload-artifact v7 pinned to cf430e030ddbb5b0abf93d22962f4752f3646cd9. No workflow
permissions, secrets, deployment jobs or hosting integrations were added.
No-config builds open only the setup screen and contain no server/account data.
A configured private-test APK still needs the approved target and access setup.


## Review fixes and current verification

Independent read-only code review found flagged display-name exposure and a
preexisting privacy-mode/geometry race. Regression tests reproduced both before
fixes. Public profile/grid/chat summaries now hide automatically flagged text
while review is pending, without hiding harmless text or suspending accounts.
Clean rewrites display normally. Privacy-mode geometry is recomputed from locked
current database state. Location updates now atomically preserve omitted privacy
choices (a regression reproduced the former hide-distance reset).

The 420ced8 review head passed backend CI, clean Flutter analysis, 59 Flutter
tests and debug APK compilation in run 40566820371. The subsequent review fixes,
synthetic-area UI and artifact-retention step require their own latest-head CI.
No device, hosted staging, iOS or real-user acceptance has been performed.


Native location uses geolocator 14.0.2, following the publisher's versioned docs:
https://pub.dev/packages/geolocator/versions/14.0.2
Generated Android permissions request coarse foreground access only and remove
background/foreground-service location declarations. iOS uses WhenInUse with the
Always bypass macro; Swift Package Manager builds must set
BYPASS_PERMISSION_LOCATION_ALWAYS=1 (the build script does). No generated platform
folders are committed. Default builds keep the native action disabled; no real
position was collected, sent or stored. The hardware permission path and iOS
signing remain untested; unit tests use injected synthetic permission/position
providers. This code addition does not authorize real-user testing.

CI dependency resolution exposed a win32 constraint conflict between geolocator
14.0.3+ and the existing secure-storage 9.x. Pinning geolocator 14.0.2 avoids
an unrelated credential-storage migration; latest-head CI remains required.
