# Database transport and closed-test access

Local code/test preparation only. No provider, deployment, credential, account,
cost, live configuration or persistent data changes are authorized by this file.
Render is a candidate, not a selected or verified-free deployment target.

## Database contract

- `DATABASE_URL`: required PostgreSQL URL. Never include it in committed files.
- `BEEF_DATABASE_DRIVER=neon` (default): existing Neon HTTP transport unchanged.
- `BEEF_DATABASE_DRIVER=postgres`: Bun 1.3.14 native PostgreSQL TCP transport.
  No Neon-compatible HTTP/WebSocket database proxy is required by the application.
- Native TLS verifies certificates by default. Absent `sslmode` means verified
  TLS; `sslmode=verify-full` is explicit. There is no insecure TLS fallback.
  Only `sslmode=disable` explicitly permits cleartext, for separately approved
  local/private transport. `require`, `prefer`, `allow` and unknown modes are
  rejected rather than silently relaxing verification. A provider's certificate
  chain/network routing must still be tested in the approved host.
- Native pool: maximum five connections per configured URL, 20-second idle
  timeout, five-second connection timeout; readiness has one additional bounded
  probe connection per URL. Shared across bundled/source modules;
  shutdown closes pools after draining HTTP. One application process remains the
  staging limit until distributed chat delivery/revocation exists.
- Queries use bound positional parameters. Arrays use PostgreSQL value encoding;
  returned timestamps normalize to ISO strings. Transaction batches are lazy and
  execute sequentially on one connection with rollback on failure. Readiness
  cancellation rejects immediately and closes a separate one-connection probe
  pool; a two-second server statement timeout bounds abandoned probes because
  Bun 1.3.14 cancellation alone may wait for SQL completion. Driver diagnostics/parameters are not returned.
- Migrations do not run at startup. For ordinary PostgreSQL use the existing
  `db/migrate.sh` with `psql` against the separately approved synthetic database.
  The older `db/migrate.ts` remains Neon-specific; do not use it as a native runner.
  The selected provider must support PostGIS and citext plus all eleven migrations.

## Closed-test contract

- `BEEF_ACCESS_MODE` defaults to `closed_test`.
- `BEEF_CLOSED_TEST_EMAILS` must contain 1–100 comma-separated exact email
  addresses. Whitespace is trimmed and case normalized. Empty entries, malformed
  entries, wildcards and missing configuration fail closed. No domain matching.
- Missing/invalid configuration prevents persistent service startup and returns
  generic 503 when a route is invoked through another entry point. Configuration
  values are not included in responses.
- Register/login require an allowed address. Refresh and authenticated requests
  use the current database email, not an email claim from a token. Account status
  is still checked independently. Allowlist removal blocks already-issued tokens.
- Protected API routes have a runtime guard; route/domain checks remain in place.
  WebSocket upgrades accept existing bearer/query-token transport forms but both
  require current allowlist membership. Existing sockets recheck access on actions
  and recipient delivery. Removing an account is not a recall of offline content.
- Moderator API requires BOTH an allowed active tester session AND the moderator
  key in closed mode. This does not grant reviewer credentials or define policy.
- Waitlist intake is disabled in closed mode, including for allowed testers.
  Health probes and static/landing content are not identity-protected by this gate;
  an approved private HTTP/WSS network boundary is still required for staging.
- `BEEF_ACCESS_MODE=open` exists for explicit legacy compatibility and isolated
  baseline regression tests. It is not authorization for public deployment.
- Host/port, JWT and moderator-secret requirements remain in STAGING-RUNTIME.md.
  Set synthetic `.test` addresses only for the selected closed-test boundary.

## Isolated verification

After building the backend, run these only with the cached approved test images:

```sh
python3 db/tests/run_api_local.py --driver neon
python3 db/tests/run_api_local.py --driver postgres
```

Both modes create fresh disposable PostgreSQL/PostGIS and an internal network;
no host ports, cloud credentials, real users, inherited `.env` or live data.
The native mode uses direct PostgreSQL for application queries; the existing
local Neon proxy is only the fixture-control connection. Native-specific checks
cover SQL parameter binding, array/timestamp/boolean compatibility, lazy rollback
and query cancellation/recovery. Both modes run auth/chat/privacy/suspension/
ratings/report suites plus allowlist tests for all protected HTTP methods,
registration/login/refresh, moderator access, both WS token forms and old sockets.
Provider TLS, hosted network controls and device testing remain unrun.
