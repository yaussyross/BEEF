#!/usr/bin/env python3
"""Disposable real API/WS integration via the Neon-documented local proxy.
No inherited DATABASE_URL, .env files, cloud credentials, production writes or pulls.
Requires both README-pinned images cached and the backend already built.
"""
from pathlib import Path
import secrets
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
POSTGRES = 'postgis/postgis@sha256:01a6a70e41e6c4467c8f55f6063555ed72db2d6662cd0d571040d42eadaeb6f6'
PROXY = 'ghcr.io/timowilhelm/local-neon-http-proxy@sha256:cd2ae14edf2feafbc3330492de5c80506f77274c3bd013154cdef697bdeb768a'
MIGRATION_COUNT = len(list((ROOT / 'db/migrations').glob('[0-9][0-9][0-9][0-9]_*.sql')))
NAME = 'beef-api-test-' + secrets.token_hex(5)
PASSWORD = secrets.token_hex(24)
BUN = shutil.which('bun')
if not BUN:
    raise SystemExit('Put the installed Bun executable on PATH first.')


def run(*args, check=True, **kwargs):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, check=check, timeout=180, **kwargs)


for image in [POSTGRES, PROXY]:
    run('docker', 'image', 'inspect', image)
created_network = False
try:
    run('docker', 'network', 'create', '--internal', NAME)
    created_network = True
    run('docker', 'run', '-d', '--rm', '--pull=never', '--name', NAME + '-db',
        '--network', NAME, '--network-alias', 'postgres',
        '--tmpfs', '/var/lib/postgresql/data:rw', '-e', 'POSTGRES_DB=beef_test',
        '-e', 'POSTGRES_PASSWORD=' + PASSWORD, POSTGRES)
    for _ in range(60):
        ready = run('docker', 'exec', NAME + '-db', 'sh', '-c',
                    'test "$(cat /proc/1/comm)" = postgres && pg_isready -U postgres -d beef_test', check=False)
        if ready.returncode == 0:
            break
        time.sleep(1)
    else:
        raise RuntimeError('Disposable PostgreSQL did not start')
    run('docker', 'cp', str(ROOT / 'db'), NAME + '-db:/tmp/beef-db')
    migration = run('docker', 'exec', NAME + '-db', 'env',
                    'DATABASE_URL=postgresql:///beef_test?user=postgres',
                    'bash', '/tmp/beef-db/migrate.sh')
    assert migration.stdout.count('apply  ') == MIGRATION_COUNT, 'Fresh migration count mismatch'
    # Regenerate the local CA/certificate together in this disposable container:
    # upstream image's baked certificate may be expired. Caddy still verifies it.
    startup = ('openssl req -new -x509 -days 1 -nodes -out server.pem -keyout server.key '
               '-subj /CN=*.localtest.me -addext "subjectAltName=DNS:*.localtest.me" '
               '>/dev/null 2>&1 && exec ./start.sh')
    run('docker', 'run', '-d', '--rm', '--pull=never', '--name', NAME + '-proxy',
        '--network', NAME,
        '-e', 'PG_CONNECTION_STRING=postgres://postgres:' + PASSWORD + '@postgres:5432/beef_test',
        '--entrypoint', 'bash', PROXY, '-c', startup)
    # Run Bun in the same isolated container: no ports, host mounts or egress.
    # Copy only code/dependencies, never .env files, .run data or workspace secrets.
    run('docker', 'exec', NAME + '-proxy', 'mkdir', '-p', '/tmp/beef-backend')
    for entry in ['node_modules', 'dist', 'src', 'tests', 'tsconfig.json', 'package.json']:
        run('docker', 'cp', str(ROOT / 'backend' / entry), NAME + '-proxy:/tmp/beef-backend/')
    run('docker', 'cp', str(Path(BUN).resolve()), NAME + '-proxy:/tmp/beef-bun')
    result = run('docker', 'exec', '--workdir', '/tmp/beef-backend', NAME + '-proxy',
                 'env', '-i', 'PATH=/usr/bin:/bin',
                 'BEEF_TEST_PROXY_URL=http://127.0.0.1:4444/sql',
                 'BEEF_TEST_DATABASE_URL=postgres://postgres:' + PASSWORD + '@db.localtest.me:5432/beef_test',
                 '/tmp/beef-bun', '--no-env-file', 'tests/api.integration.mjs', check=False)
    print(result.stdout.replace(PASSWORD, '[test-password]'), end='', flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)
finally:
    for suffix in ['-proxy', '-db']:
        run('docker', 'rm', '--force', '--volumes', NAME + suffix, check=False)
    if created_network:
        run('docker', 'network', 'rm', NAME, check=False)
    print('Removed disposable proxy, PostgreSQL data and private network.', flush=True)
