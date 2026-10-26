# BEEF launch readiness — 26 October 2026

This is the current local audit, not a launch certification. No live backend,
real-user data, production migration, deployment, push, PR creation or merge was
performed. Older handoff claims describe historical runs only.

## Source reconciliation

Canonical remote: `https://github.com/yaussyross/BEEF` (repository ID supplied by
owner: 1352833489). Remote refs fetched successfully:

| Track | Source commit | Result |
|---|---|---|
| main | `bd2a7ad95da54cbc7db051c0eb1ae47beebc4ef6` | Clean starting checkout; unchanged remote |
| chat / draft PR #5 | `4c79f830d6496c3033433bcc2dd9d14d1b92d568` | Existing native inbox, history, WS/REST retry and tests preserved |
| waitlist recovery | `1a9c543594742d9f6f391eace178a50e995cf1f1` | Waitlist repair, strict Bun typing and disposable DB tests preserved |

Both tracks branch independently from main. On local branch
`audit/launch-readiness-2026-10-26`, their six commits were cherry-picked in order
without conflicts. Before the audit fix, `app/` exactly matched the chat head;
`backend/` and `db/` exactly matched recovery. No rewrite or source branch changes.
The supplied PR status is draft/unmerged; PR metadata and hosted CI were not
requeried after the earlier GraphQL Forbidden response.

## Current results

| Stage | Result | Scope / evidence |
|---|---|---|
| Frozen backend install | PASS | Bun 1.3.14, existing lockfile |
| Production backend build | PASS | Client and SSR bundles, no live service |
| TypeScript | PASS | Zero errors; includes new regression tests |
| Chat privacy/account access/rating input regression | PASS | 32 Bun tests with mocked SQL/socket objects; not REST/WS transport integration |
| Waitlist browser suite | PASS | 6 grouped checks: validation, loading/double submit, network retry, temporary persistence, disk failure, keyboard/responsive/reduced motion |
| PostgreSQL/PostGIS | PASS | 41 printed PASS checks, nine migrations applied then skipped on second run; synthetic fixtures rolled back; container removed |
| Flutter analyze / tests / APK | NOT RUN | SDK absent; prior official manifest HTTP 403 not retried or bypassed |
| Authenticated REST/WS + local Neon transport | PASS | Twelve integration groups against real disposable PostgreSQL; see follow-up below |
| Two-device Android/iOS, signed release, stores | NOT RUN | No devices or signing used |

The previous 29 Flutter tests and debug APK success are historical reports for
the chat track, not current results for this combined branch. The older 36/83
live checks likewise were not rerun. Database output is committed at
`artifacts/audit-2026-10-26/postgresql.txt`.

The saved environment did not retain the PostGIS image. The previously approved
pinned image was downloaded again through Docker's supported route, successfully.
The test had no network, no exposed ports and memory-backed data. The browser
test used a loopback-only ephemeral server and fictional example.test emails.
Its first invocation failed because Bun was not on PATH; setting PATH to the
existing installation resolved this, with the complete suite then passing.

## Fixed during this audit

`sendMessage()` deduplicates by `(sender_id, client_message_id)` across all
threads. Previously, sending an already-used ID to another conversation returned
the original message with the newly requested recipient ID. The WebSocket caller
would then broadcast that old message to the new recipient. The shared domain
function now returns 409 `client_message_id_conflict` on a thread mismatch before
returning any delivery result. Same-thread retries still return the stored row.
Two regression tests cover both cases and are added to backend CI.

## Exact finish line

Today's completed milestone is a reconciled, locally checked development branch
and one privacy repair. It is not a public dating-app launch or beta-ready build.
The next engineering milestone is a feature-complete private-beta candidate with
the following acceptance gates. Ratings remain required, not deferred implicitly.

- [ ] Ratings: schema, API and Flutter prompt/display; integer stars 1–5;
  participant-only eligibility after a genuine five-minute chat; no self-rating;
  latest vote replaces prior vote; aggregate beside username. Backend eligibility
  and vote persistence now implement the approved mutual-message rule; client
  controls are authored but await Flutter validation. Public aggregate exposure
  is held by the latest instruction. See follow-ups below.
- [ ] Block/report controls in profile and conversation, confirmation and retry,
  blocked conversation removal and unread refresh; test enforcement both ways.
- [ ] Privacy settings: coarse mode and hide-distance controls persisted through
  API; verify no coordinates or other users' birthdates in public payloads.
- [ ] Account lifecycle: working account deletion and recovery flows; retention
  decisions documented; verify old tokens and sockets cannot continue after
  suspension/deletion. The account-status gap found in the initial audit is now
  fixed and transport-tested in the follow-ups below; deletion/recovery flows
  remain outstanding.
- [ ] Moderation operations: human queue review, reports, appeals/escalation and
  evidence handling exercised with synthetic fixtures. NCMEC submission remains
  explicitly a nontransmitting stub. Do not treat a stub as an operational process.
- [ ] Photo upload/verification, moderation re-do prompts, consent-friendly
  discovery and profile prompts: deliver the owner-plan features or obtain explicit
  owner agreement on beta scope; they cannot silently count as finished.
- [ ] Reproducible Flutter analyze/test/debug APK on the combined commit, then
  signed Android and iOS builds. CI configuration exists but has not run here.
- [x] Isolated HTTP/WS integration: registration and 18+ rejection, login/refresh,
  profile/grid privacy, inbox/history pagination, idempotency conflict, moderation,
  block, suspension and reconnect. Real PostgreSQL constraints alone do not cover
  the Neon HTTP driver or endpoint behavior. The separate local proxy suite now
  validates these paths; concurrency and deployment-host checks remain separate.
- [ ] Two-device scripted QA: send/receive/read, background/resume, expired token,
  airplane-mode retry, lost acknowledgement, logout/account switch and block.
  Record device/OS, build commit and each expected/actual outcome.
- [ ] Owned staging TLS/WSS endpoint with backup/restore, monitoring, rate limits
  and durable waitlist storage. Current waitlist is local append-only JSONL and
  may duplicate after a lost response. Current app default URL is an old platform
  host; explicitly set `BEEF_API_BASE_URL` for testing and release.
- [ ] Release review: current store requirements, truthful assets, privacy/terms,
  age/data declarations, support and moderation coverage reviewed before submission.
  This audit does not assert current legal or store compliance.

## Genuine owner-dependent gates

Engineering can continue without production secrets. When needed, the owner must
select an owned staging/deployment target and provide secrets through secure
configuration, confirm beta devices/testers, and supply store account/signing
access for distribution. Confirm moderation responsibility and an appropriate
reporting/escalation process before a real-user beta. Push service credentials are
needed if push is included. No spending/account creation is authorized here.
Staging selection is not a prerequisite for the isolated integration suite.

The owner approved the genuine-chat rule on October 26 at 17:55:53 UTC: messages
from both people spanning at least five minutes. No further decision on that
rule is pending. The 1–5 scale, re-rating and aggregate display remain required.

## Reproduce available checks

Use the installed Bun directory on PATH:
`/workspace/.tools/node_modules/@oven/bun-linux-x64-baseline/bin`.
From backend: `bun install --frozen-lockfile`, `bun run build`,
`node_modules/.bin/tsc --noEmit`, `bun test tests/chat-idempotency.test.ts`.
Browser: set `PLAYWRIGHT_MODULE=/opt/codex/cua_node/lib/node_modules/playwright/index.mjs`
and `CHROMIUM_PATH=/usr/bin/chromium`, then `bun run test:waitlist`.
From repository root: `python db/tests/run_local.py` after obtaining the pinned
image described in `db/tests/README.md`.

No access operation was denied during this audit. Known earlier Flutter manifest
and GraphQL denials were left untouched. Environment/tool and integration gaps
above remain unresolved; none has an uncertain mutation outcome.

## Follow-up: account status enforcement

The same local branch now checks current account status on every authenticated
HTTP request, WebSocket upgrade/open/action and outbound WebSocket delivery.
Missing accounts are rejected with 401, non-active accounts with 403, and an
unavailable status lookup with 503. No active-status cache or JWT-only fallback
is used. Failed status checks remove and close that user's local sockets.

The existing CSAM suspension and human ban paths now remove/close all local
sockets immediately after the user-status update, before the profile update.
This still closes sockets if the subsequent profile update fails. The socket
registry remains on globalThis, shared by bundled REST and Bun entry modules.
No reporting or moderation decision policy changed; the NCMEC stub still does
not transmit.

Chat domain guards cover both callers and peers before history/send/read access;
the recipient-ID send path cannot create a thread for an inactive recipient.
Inboxes exclude inactive peers. Read acknowledgements now use the same
participant/block/status checks as history. Outbound delivery rechecks the
recipient; a newly unavailable recipient receives nothing and is closed,
without closing the active sender's session or claiming persistence failed.
The earlier cross-conversation message-ID privacy fix is preserved.

Validation: 31 Bun regression tests pass (including the original two), build
passes, and TypeScript has zero errors. The tests exercise real JWT signing and
verification plus production auth/chat/socket/moderation functions, but mock SQL
and socket objects. They are not a live Neon HTTP or real WebSocket transport
test. The browser suite passed all six grouped checks again, and the disposable
database suite passed all 20 checks again with its container removed afterward.
The GitHub CI test step invokes the expanded suite; no push or hosted CI run.

Operational limits: immediate socket closure is process-local. Other processes
and direct database status changes are caught on the next action or delivery;
there is no cross-process revocation broadcast or idle-socket sweep. Checks
are not a serialized transaction with account-state changes, so already in-flight
work is not claimed to be atomically cancelled. Persistent token revocation on
later account reactivation is also outside this change. These need explicit
integration/concurrency validation before real-user beta, not production tests
during this task. No Flutter, device, signing or deployment check was run.

## Follow-up: real isolated API/WebSocket integration

The local transport prerequisite has been resolved without a staging host.
`db/tests/run_api_local.py` now starts fresh PostgreSQL/PostGIS and the
Neon-documented local HTTP proxy on a disposable internal network. The built
REST handler and production WebSocket callbacks run in a test-only Bun wrapper.
No production runtime/database configuration was changed. No ports or host
directories are exposed, no cloud credentials are inherited, and all fixtures
are synthetic. Containers, data and network were removed after the run.

Ten integration groups passed, including real JWT/auth routes, PostgreSQL queries,
Neon HTTP decoding, location/profile privacy, persisted privacy settings, chat
send/read/pagination and retry, REST and WS cross-thread privacy rejection,
block socket closure across bundled modules, suspension and human ban revocation,
direct status changes, and transport-outage fail-closed behavior/recovery.
See [reproduction and coverage](../db/tests/API.md) and
[captured output](../artifacts/audit-2026-10-26/api-integration.txt).

This supersedes the earlier local HTTP/WS NOT RUN status, not the unrun cloud,
mobile, multi-process/concurrency or signed-release stages. No rating eligibility
or moderation policy decision was made. The earlier 31 regression tests, backend
build and zero-error type-check remain passing after adding the integration suite.

## Follow-up: approved rating eligibility

The owner accepted the proposed rule: messages from both people across at least
five minutes, not simply leaving a chat window open. Migration 0009 implements
that rule using only existing server-generated chat-message timestamps and
participant IDs. Both participants must have sent a message in their shared
thread, and `max(created_at) - min(created_at)` must be at least 300 seconds.
Two messages (one each) exactly five minutes apart qualify; one-sided messages
or a shorter exchange followed by waiting do not. No continuous activity,
online tracking, location, extra message-count threshold or new collection is used.

`GET /api/ratings/:id` returns only `eligible` and the caller's `my_rating`.
`POST /api/ratings/:id` accepts integer `stars` 1–5, always uses the authenticated
user as rater, and stores one vote per pair. Re-rating replaces that vote. A
database trigger rechecks eligibility for inserts and updates, including block
and active-account guards. Client eligibility flags, identities and timestamps
are not authority. Future message timestamps and unrelated senders do not count.
The eligibility rule uses persisted exchanged messages without inventing new
content-based penalties or a separate moderation policy.

Ratings are still not a finished user-facing feature: the Flutter prompt and
public aggregate API/display remain implementation work. No decision was made
about appeals, rating removal/retention or moderation treatment of aggregates.
Those are separate from the approved eligibility rule and must not be inferred
from this backend change. Local migration tests and API tests use synthetic
fixtures only; migration 0009 has not been applied to any live database.

Final rating verification: backend build and zero-error TypeScript pass; 32 Bun
regression tests pass; 41 real PostgreSQL checks pass (20 existing plus 21 rating
checks), including all nine migrations and a no-op second application; eleven
API/WebSocket integration groups pass; the six-group browser suite passes.
Fresh evidence: [database](../artifacts/audit-2026-10-26/ratings-postgresql.txt)
and [API/WebSocket](../artifacts/audit-2026-10-26/ratings-api-integration.txt).
All test containers and networks were removed. Flutter/device/cloud deployment
checks remain unrun; no push, live migration or deployment occurred.

## Follow-up: private rating, safety and privacy controls

Local Flutter source now provides rating eligibility/submission from profiles
and conversations, a confirmed block flow, report forms scoped to profile or
thread, and privacy preferences from the grid. Loading, retry, retained inputs,
duplicate submission guards and server rejection states are implemented. After a
confirmed block the parent screen clears local chat state and closes the profile
or conversation; WS delivery is not required for that local invalidation. Chat
poll responses with `account_disabled` now request the existing session teardown.
Covered conversations stop read markers while the rating/safety route is open.

The defaults are existing requirements, not new product decisions:

- **1–5 stars and re-rating:** `docs/BUSINESS.md`, MVP milestone (line 32),
  explicitly specifies 1–5 stars and “re-rateable — latest vote wins”; the
  implementation plan repeats this in `docs/ROADMAP.md` section 1.2.
- **Five-minute eligibility:** owner approval recorded in the prior section;
  the client fetches server eligibility rather than timing an open screen.
- **Reports:** the seven categories in `backend/src/routes/api/report.ts`;
  the UI does not change existing suspension, review or NCMEC-stub behavior.
- **Privacy:** existing `city`, `region`, `exact` and `hide_distance` fields
  in `api/profile.ts`/`lib/privacy.ts`. Saved values are loaded; exact mode is an
  explicit choice with explanatory text. No new location collection or defaults.

Public rating aggregates are **not added or exposed in this step**, per the latest
instruction.
Visibility, rating appeals/removal/retention and moderation treatment remain
separate; none was decided here. Blocked-user listing/unblock management is also
not included in this bounded UI step.

Verification on the resulting source: backend build, zero-error TypeScript and
32 Bun regression tests pass; the real API/WS suite passes 12 groups, now also
covering participant-only thread reporting, explicit exact-mode distance output,
and suspended-account rejection of profile changes, reports and blocks.
Evidence: [private-controls API run](../artifacts/audit-2026-10-26/private-controls-api.txt).
The unchanged database schema/contracts last passed 41 checks in the preceding
step. The landing-page browser suite was not rerun for these client-only controls.

**Flutter NOT RUN:** 21 new tests are authored across `ratings_test.dart` and
`safety_privacy_test.dart` (9 rating cases including parameterized revocation,
12 safety/privacy cases). There is no installed Flutter/Dart SDK; the prior
official-download denial was not retried or bypassed. These are source-reviewed
changes, not a compile-verified private build. No new action was denied, and all
test containers/networks were removed.

Remaining device gates: run Flutter analyze and the entire old/new test suite;
build an Android debug APK; exercise two synthetic adult accounts on devices for
rating unlock/re-rate/retry, block while disconnected, report confirmation,
privacy persistence, suspension/session teardown, navigation/read markers and
small-screen/accessibility behavior. iOS compilation/signing and release checks
remain separate. No new owner decision blocks these authored controls; an
approved SDK/CI environment and then devices are the immediate validation needs.
