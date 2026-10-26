# Local staging runtime preparation

Not deployed. PR #6 remains at its green head 777700a; this follow-up is local.
No provider, account, persistent credential, real data or paid resource was used.

## Environment contract

Build dependencies first (`bun install --frozen-lockfile`, `bun run build`). Run
from `backend` under a supervisor with injected environment:

```sh
bun --no-env-file serve.ts
```

| Variable | Requirement/default |
|---|---|
| `DATABASE_URL` | Required PostgreSQL URL usable by the Neon HTTP driver; plain PostgreSQL needs a compatible transport. Never printed. |
| `JWT_SECRET` | Required, at least 32 characters; staging-only random secret. |
| `MODERATION_ADMIN_KEY` | Required, at least 32 characters; staging-only random secret. |
| `BEEF_HOST` | Default `127.0.0.1`; explicitly choose `0.0.0.0` inside an approved container/proxy boundary. |
| `BEEF_PORT` | Default `3000`; integer 1–65535. Generic `PORT` is ignored. |
| `BEEF_READINESS_TIMEOUT_MS` | Default `2000`; integer 1–30000. Cancels the driver request on timeout. |
| `BEEF_SHUTDOWN_TIMEOUT_MS` | Default `10000`; integer 1–60000. Force-closes remaining connections at deadline. |
| `IMAGE_MODERATION_API_KEY` | Leave unset for synthetic staging. No external image service is needed or authorized. |

Invalid required configuration fails before binding. A busy port causes startup
failure; no sudo, lsof, process takeover, migration, credential generation or
resource provisioning occurs. `publish.sh` is now only a legacy-name foreground
build/run wrapper, not a detach/restart/deploy mechanism. Existing supervisors
must stop/restart their own service explicitly. Old go-live tooling is not the
staging setup path.

GET/HEAD `/healthz` returns 200 for a responsive process, independent of the DB.
GET/HEAD `/readyz` returns 200 only when required migrations 0001–0011 are recorded
and report/waitlist schema is queryable. DB failure, missing migration, timeout
or shutdown yields 503. Responses contain generic status only, are not cached,
and expose no address, credential, database error or migration detail. Other
methods return 405. Configure readiness as a traffic gate, not as liveness.
Startup does not apply migrations. The versioned migration runner must be used
on the separately authorized staging database.

SIGTERM/SIGINT stops admitting application work, marks readiness unavailable,
closes chat sockets with 1001, and drains HTTP connections until the configured
deadline. Static files are restricted to the real built client tree; hidden
paths, encoded traversal and symlink escapes are not served.

## Durable waitlist

`POST /api/waitlist` accepts `{ "email": "fictional-adult@example.test" }`.
It validates type/format/maximum 254 characters, trims and lowercases, then uses
existing `waitlist_emails.email` citext UNIQUE with `ON CONFLICT DO NOTHING`.
First submissions and duplicates return the same `{ "ok": true }` response;
existing source, invitation state and original timestamp are preserved. Nothing
creates an account, authenticates a user, sends email or automatically imports
historical files. Storage failure returns 503 and the UI preserves input/retry.
There is no filesystem fallback. Durability follows the selected database's
persistence/backup guarantees; the isolated tests deliberately destroy fixtures.

## Validation and remaining gates

Runtime tests exercise configuration, readiness timeout/abort, drain behavior,
static containment, actual foreground startup/shutdown and occupied-port safety.
The browser suite tests validation/loading/failure/retry and layout; its success
receipt is mocked. The separate real API/WS suite verifies database persistence,
case-insensitive concurrent retries, new server instances, missing migrations,
outage/recovery and no waitlist account creation, alongside existing safety tests.

This is not a complete hosting or release hardening pass. Still needed: approved
host/database and secure secret storage, TLS/WSS/proxy configuration, backup and
restore exercises, monitoring, rate limiting/abuse controls, private tester access,
configured APK delivery and two-device QA. Use one process until shared chat
fan-out/revocation is implemented. No moderation policy changed; false-report
suspension and external-reporting operations remain unresolved release gates.


Latest local results: backend build and TypeScript passed; 32 existing safety
regressions, five runtime tests, six browser groups and 18 isolated API/WebSocket
groups passed. All test accounts/addresses were synthetic. The database suite
applied all ten migrations to a fresh disposable database; no schema migration
was added by this change. Test containers/network and browser temporary files
were removed. No new CI run or Flutter checks were needed for unchanged Flutter
source. The remote PR remains unchanged pending review of this local work.


Moderation follow-up now requires migration 0011 for readiness. Current local
checks additionally pass 33 safety regressions, five runtime tests, 41 database
checks over eleven migrations and 19 real API/WS groups. The earlier six browser
checks still apply to unchanged waitlist UI. A new Flutter containment-cache test
is authored but not run locally. See CLOSED-TEST-ACCEPTANCE.md for the selected
synthetic-only boundary and pending approvals; this source is not deployed.
