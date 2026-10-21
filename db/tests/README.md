# Disposable local database checks

These are real PostgreSQL migration/constraint tests, **not** production or
backend HTTP integration tests. No production connection string is read.

Prerequisites: Python 3, Docker, and the PostGIS project's image from its
[official installation guide](https://postgis.net/documentation/getting_started/install_docker/).
The tested image contains PostgreSQL 17.5 and PostGIS 3.5.2 and is pinned by
immutable digest for reproducibility:

```sh
docker pull postgis/postgis@sha256:01a6a70e41e6c4467c8f55f6063555ed72db2d6662cd0d571040d42eadaeb6f6
python db/tests/run_local.py
```

The runner never pulls an image automatically. It creates a uniquely named
container with `--network=none`, no published ports, and a tmpfs data directory.
The initialization password is random and never recorded. It applies the existing
`db/migrate.sh` twice, verifies the second run skips all eight migrations, and
runs `contracts.sql` inside a transaction. Fixtures use `synthetic_demo` and
`example.test`; accepted users are fictional adults. Rejected age fixtures test
the server-side constraint only. Fixtures roll back, and the runner removes its
container in `finally`.

Coverage: age boundary and insert/update/null rejection; case-insensitive email
uniqueness; intent-array casting; privacy/verification defaults; geography column
synchronization; two-member chat threads; message idempotency; pair ordering and
deduplication; thread activity timestamps. A separate check confirms zero users
remain after rollback.

The application uses Neon's HTTP driver, while this suite uses `psql` inside the
container. It does not validate REST/WS authentication, moderation flows, API
privacy payloads, or the Neon transport. Those require a separately configured
local Neon-compatible proxy/test stack; do not substitute production secrets.
