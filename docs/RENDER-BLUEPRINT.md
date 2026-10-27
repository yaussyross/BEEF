> Security follow-up: closed-test registration now requires an independently configured `BEEF_CLOSED_TEST_SETUP_KEY` (32–256 characters) in `X-BEEF-Test-Setup-Key`, in addition to exact allowlisting. The Blueprint intentionally does not set this key, so hosted registration is disabled until an approved secure setup path exists. Never embed the key in mobile builds. Closed-test accounts are tagged `synthetic_demo`. Login to already-established accounts is unchanged.

# Closed synthetic Render Blueprint

Prepared, not applied. Use `deploy/render.closed-test.yaml` from the exact reviewed
commit on `review/private-controls-2026-10-26`, only in Ross workspace
`tea-db0folad0e5s73bem6pg`. Never substitute main. No API key is needed for the
Dashboard route; stop if connecting a new Git-provider authorization is required.

## Owner dashboard step

1. In Ross's workspace, choose New > Blueprint, select `yaussyross/BEEF`, branch
   `review/private-controls-2026-10-26`, Blueprint Path
   `deploy/render.closed-test.yaml`. Check the source commit against the handoff.
2. Supply `BEEF_CLOSED_TEST_EMAILS` with only the chosen synthetic `.test` account
   addresses. Do not use real personal addresses or publish the list. Missing or
   malformed configuration prevents startup. A listing is not mailbox verification:
   securely establish the approved synthetic accounts before distributing access.
3. Review the provider's validation/plan preview: exactly **one Free web service**
   and **one Free Postgres database**, same Oregon region; no paid resources,
   upgrades, cards, extra services or existing-resource changes. Database external
   IP rules must be **empty**, not `0.0.0.0/0`. Stop on any discrepancy or error.
4. Deploy Blueprint only after that preview passes. This is within the approved
   dedicated synthetic staging scope. Immediately set Blueprint Settings > Auto
   Sync = No (separate from the service's already-disabled auto deploy). No later
   branch push should cause a configuration sync without explicit action.
5. Return only the resource IDs/URLs and deploy result; never paste credentials.
   Verify the database Networking page has no external IP rules. Inspect actual
   deployed SHA and Free plans before testing. There is no callable Blueprint
   apply tool in the current connector, so this dashboard step is needed.

The manifest explicitly uses `plan: free` for both resources, disables previews
and service auto deploy, generates dedicated JWT/moderator secrets through Render,
and references the database's **internal** connectionString. It creates no custom
DNS, disk, paid worker, shell, one-off job or third-party integration. A Blueprint
cannot enforce the workspace selection; the owner must choose the specified one.

## Private database and startup

`ipAllowList: []` is supported by Render's Blueprint specification for blocking
all external database connections. This configuration is applied at creation;
there is no create-open-then-close window in the intended manifest semantics.
Verify the actual created settings before relying on the resource.

Render internal database certificates are self-signed. The explicit
`BEEF_DATABASE_TLS=render_internal` mode requires TLS without public-CA certificate
verification and accepts only an internal `dpg-...` hostname, with no SSL override
query parameters. It has no plaintext fallback. This protects against passive
network observation but does **not** authenticate the server certificate; trust
rests on Render's private routing/DNS. General native PostgreSQL remains verified
TLS by default. Never use the internal mode with an external endpoint. Actual
provider handshake still needs deployment verification.

Free services cannot run a pre-deploy job or shell. The explicit staging start
entry point first validates environment, then runs `db/migrate-native.ts`, and
only then binds HTTP/WS. The runner requires closed_test plus explicit migration
opt-in. It applies eleven existing versioned migrations on one connection in a
transaction with an advisory lock and atomic ledger. Failure rolls back and
prevents startup. Replays skip recorded files; no table reset, deletion, fixture
wipe or real-user import. Error logs omit SQL, URLs and secrets. Runtime startup
remains unchanged outside this explicit staging entry point. This single-process
bootstrap is for the dedicated synthetic database, not a production migration
strategy. Restart checks are bounded; failed migration must be investigated.

Closed-test mode hides landing/static routes (404). Generic /healthz and /readyz
remain exposed for the platform; auth endpoints are reachable but accept only the
configured addresses. HTTP APIs and WebSocket upgrades/actions enforce current
allowlist and status. This is application access restriction on an internet-
reachable web-service endpoint, **not** private network ingress. Hobby/Free does
not support the paid inbound web IP rules; do not silently add them to the plan.

## Validation and expiry

Local checks cover migration fresh apply/replay/rollback, gate rules and native
adapter configuration. YAML parses and explicit resource invariants pass. Full
JSON-schema validation was not run: downloading Render's schema into the workspace
returned HTTP403; no retry or alternate transfer. Official reference was readable
through the research tool. The Dashboard's validation/plan preview must pass.

After provisioning: confirm plans, region, external DB denial, exact SHA, readiness,
anonymous HTTP/WS rejection, disallowed account rejection and approved synthetic
chat/privacy/ratings/block/report/moderation flows. Validate cold start/reconnect.
No live checks, Render resource IDs, deployed URL or expiry timestamp exist yet.

Record provider creation/expiry timestamps. Free Postgres expires after 30 days,
has no backups and is deleted by the provider after a further 14-day grace period.
Review with owner at day 23, stop testing before expiry, preserve fixture recipes
and nonsensitive results. Obtain a specific destination before exporting runtime
rows; do not automatically delete, upgrade, extend or move data. No scheduled
reminder or cleanup job has been created by this preparation.

Once staging is verified, build a configured APK using only its HTTPS origin,
never embedded server/admin/database secrets. Two-device and iOS acceptance remain.

## Official references checked 2026-10-27

- https://render.com/docs/blueprint-spec — plans, ipAllowList, generated secrets,
  internal connectionString, preview and auto-deploy fields
- https://render.com/docs/infrastructure-as-code — custom path/branch, validation
  preview and separate Auto Sync switch
- https://render.com/docs/postgresql-creating-connecting — private networking and
  self-signed internal TLS
- https://render.com/docs/free — no free shell/jobs, expiration and no backups
- https://render.com/docs/bun-version — explicit BUN_VERSION pin
