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
| Chat privacy/account access regression | PASS | 31 Bun tests with mocked SQL/socket objects; not REST/WS transport integration |
| Waitlist browser suite | PASS | 6 grouped checks: validation, loading/double submit, network retry, temporary persistence, disk failure, keyboard/responsive/reduced motion |
| PostgreSQL/PostGIS | PASS | 20 printed PASS checks, eight migrations applied then skipped on second run; synthetic fixtures rolled back; container removed |
| Flutter analyze / tests / APK | NOT RUN | SDK absent; prior official manifest HTTP 403 not retried or bypassed |
| Authenticated REST/WS + Neon transport | NOT RUN | No isolated Neon-compatible HTTP test stack configured |
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
  latest vote replaces prior vote; aggregate beside username. Test boundary,
  concurrent re-rating, blocked/suspended users and privacy. Define genuine chat
  activity precisely before implementation; elapsed thread age alone is not proof.
- [ ] Block/report controls in profile and conversation, confirmation and retry,
  blocked conversation removal and unread refresh; test enforcement both ways.
- [ ] Privacy settings: coarse mode and hide-distance controls persisted through
  API; verify no coordinates or other users' birthdates in public payloads.
- [ ] Account lifecycle: working account deletion and recovery flows; retention
  decisions documented; verify old tokens and sockets cannot continue after
  suspension/deletion. The account-status gap found in the initial audit is now
  fixed in the follow-up below; deletion/recovery flows and transport-level
  validation remain outstanding.
- [ ] Moderation operations: human queue review, reports, appeals/escalation and
  evidence handling exercised with synthetic fixtures. NCMEC submission remains
  explicitly a nontransmitting stub. Do not treat a stub as an operational process.
- [ ] Photo upload/verification, moderation re-do prompts, consent-friendly
  discovery and profile prompts: deliver the owner-plan features or obtain explicit
  owner agreement on beta scope; they cannot silently count as finished.
- [ ] Reproducible Flutter analyze/test/debug APK on the combined commit, then
  signed Android and iOS builds. CI configuration exists but has not run here.
- [ ] Isolated HTTP/WS integration: registration and 18+ rejection, login/refresh,
  profile/grid privacy, inbox/history pagination, idempotency conflict, moderation,
  block, suspension and reconnect. Real PostgreSQL constraints alone do not cover
  the Neon HTTP driver or endpoint behavior.
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

The only product clarification needed before the rating implementation is the
definition of a genuine five-minute chat; the 1–5 scale, re-rating and aggregate
display are already owner requirements. A proposed acceptance rule should be
presented for this narrow decision rather than asking whether ratings belong.

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
