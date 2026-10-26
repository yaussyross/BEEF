# Isolated API and WebSocket integration

Run the actual built TanStack REST handler, production Bun WebSocket handlers,
Neon HTTP driver and PostgreSQL/PostGIS together, using only synthetic fixtures.
This does not need a staging host, cloud account, production data or credentials.

The supported setup is described in [Neon's local development guide](https://neon.com/guides/local-development-with-neon).
It uses the community [local-neon-http-proxy](https://github.com/TimoWilhelm/local-neon-http-proxy)
image referenced by Neon. This is distinct from Neon Local's cloud-branch proxy.
The driver supports this through its documented
[`neonConfig.fetchEndpoint`](https://github.com/neondatabase/serverless/blob/main/CONFIG.md)
setting. Only the test process sets that option; application configuration is unchanged.

## Reproduce

Prerequisites: Linux-compatible Bun on PATH, Python 3, Docker, installed backend
dependencies and a current backend build. Fetch the two pinned images explicitly
if absent (the runner never pulls images itself):

```sh
docker pull postgis/postgis@sha256:01a6a70e41e6c4467c8f55f6063555ed72db2d6662cd0d571040d42eadaeb6f6
docker pull ghcr.io/timowilhelm/local-neon-http-proxy@sha256:cd2ae14edf2feafbc3330492de5c80506f77274c3bd013154cdef697bdeb768a
cd backend
bun run build
bun run test:api:local
```

Alternatively, from the repository root: `python3 db/tests/run_api_local.py`.
Source inspected for the proxy: commit `7c86dc3dd5bede570270120bbc2d45f2cef36217`;
runtime is pinned by the image digest above. PostgreSQL is 17.5, PostGIS 3.5.2.

## Isolation and cleanup

The runner creates a uniquely named Docker `--internal` network and two
disposable containers. Neither publishes ports or mounts host directories.
PostgreSQL data is tmpfs-backed. Random credentials apply only to that temporary
database; they are not read from the shell or recorded. All ten migrations are
applied to the empty database. Bun runs inside the proxy container with an empty
inherited environment and `--no-env-file`; the runner copies only selected code,
built files and dependencies, never `.env`, `.run`, `.git` or workspace secrets.

The proxy's local certificate/key are regenerated together for each run; its
Caddy-to-Neon TLS verification remains enabled. All HTTP/WS clients connect to
loopback inside the disposable container. The database connection hostname is
interpreted by the local proxy; the client does not contact a cloud database.
The tests use fictional `example.test` adults, then mark the accounts
`synthetic_demo`; the whole isolated database is destroyed afterward.

The runner removes both containers, tmpfs data and the private network in
`finally`, including on failures. The downloaded images remain cached.
The first implementation attempted host publishing on an internal network;
Docker exposed no port. The final runner uses no host publishing at all.

## Current local coverage: eighteen passing groups

- Production runtime liveness and database/schema readiness; missing latest
  migration fails readiness without leaking diagnostics.
- Database waitlist validation, concurrent case-insensitive deduplication, new
  server-instance persistence and preservation of existing invitation state.
- Readiness and waitlist fail closed during transport outage, then retry succeeds
  without duplicate entries or implicit account creation.
- Empty migrated database reached through actual Neon HTTP queries.
- Registration/login/refresh, JWT audience isolation, missing authentication
  and server-side 18+ rejection.
- Intent-array decoding, location writes, public profile/grid privacy, bucketed
  distance, persisted region/hide-distance settings and hidden distance output.
- Real WebSocket send/ack/delivery/read, REST history and keyset pagination,
  participant checks, same-thread retry, and cross-thread message-ID conflict
  over both REST and WebSocket without delivery to the wrong recipient.
- Block/unblock, bidirectional read/send rejection, inbox removal and immediate
  socket closure from a bundled REST route.
- Thread reporting accepts participants and rejects outsiders. Suspended accounts
  cannot update privacy settings, submit reports or block users. Explicit exact
  location mode returns a rounded distance without coordinates.
- Ratings: mutual message-span boundaries at 299/300/301 seconds; one-sided and
  client-timing/identity abuse rejected; integer star range; concurrent re-rating
  keeps one vote and the final write wins; block/suspension prevents later votes.
- Synthetic CSAM-category report metadata (no explicit content), nontransmitting
  stub, suspension, immediate socket closure and denial of existing HTTP token,
  refresh token, new upgrade and peer history/inbox access.
- Report retry keys: concurrent identical submissions yield one report and queue
  row; changed payload/key misuse returns 409; reporter identity comes from auth.
- Discarded post-commit receipt recovers the original report on retry.
- Injected failure at the final suspension write rolls back report, queue,
  evidence and user status; retry succeeds once. Replay after simulated human
  reinstatement does not suspend again or duplicate evidence/review entries.
- Human moderation ban through the real admin route and immediate revocation.
- Direct database deletion status enforced on an existing socket's next action
  and an existing HTTP token.
- Deliberate local transport outage denies HTTP/upgrade with 503, closes an
  active socket, and allows access again when transport is restored.
- Every persisted account verified to be a synthetic fixture.

Latest output: [`artifacts/audit-2026-10-26/staging-api.txt`](../../artifacts/audit-2026-10-26/staging-api.txt).

## Limits

This validates actual SQL and local HTTP/WebSocket transport, not Neon cloud
operations, TLS termination by a deployment host, mobile devices, push, store
signing or a live reporting service. It does not prove multi-process revocation
broadcasts, atomic cancellation of in-flight transactions, full moderation policy
coverage, or concurrency/load behavior. Those are separate engineering/QA gates.
No rating behavior is invented here. This suite is local-only; existing CI still
runs its previously configured checks and the 32-test regression suite.
