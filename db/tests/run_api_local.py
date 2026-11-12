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
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--driver', choices=['neon', 'postgres'], default='neon')
DRIVER = parser.parse_args().driver

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
        '--network', NAME, '--network-alias', 'postgres', '--network-alias', 'dpg-synthetic-a',
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
    if DRIVER == 'postgres':
        run('docker', 'exec', NAME + '-db', 'mkdir', '-p', '/tmp/backend/src')
        run('docker', 'cp', str(ROOT / 'backend/src/native-db.ts'), NAME + '-db:/tmp/backend/src/native-db.ts')
        run('docker', 'cp', str(Path(BUN).resolve()), NAME + '-db:/tmp/beef-bun')
        native_args = ('docker', 'exec', NAME + '-db', 'env', '-i',
            'DATABASE_URL=postgres://postgres:' + PASSWORD + '@127.0.0.1:5432/beef_test?sslmode=disable',
            'BEEF_ACCESS_MODE=closed_test', 'BEEF_STAGING_MIGRATIONS=apply',
            '/tmp/beef-bun', '--no-env-file', '/tmp/beef-db/migrate-native.ts')
        tls_probe = run('docker', 'exec', NAME + '-db', 'env', '-i',
            'DATABASE_URL=postgres://postgres:' + PASSWORD + '@dpg-synthetic-a:5432/beef_test',
            'BEEF_DATABASE_TLS=render_internal', '/tmp/beef-bun', '--no-env-file', '-e',
            "import {nativeOptions} from '/tmp/backend/src/native-db.ts'; const o=nativeOptions(process.env.DATABASE_URL); const p=new Bun.SQL(o.url,o); try { await p`SELECT 1`; process.exitCode=2; } catch { console.log('TLS required'); } finally { await p.close({timeout:0}); }")
        assert 'TLS required' in tls_probe.stdout, 'Internal TLS silently fell back to plaintext'
        print('PASS internal TLS rejects a PostgreSQL endpoint without TLS', flush=True)
        first = run(*native_args)
        assert '11 applied, 11 total' in first.stdout, 'Native fresh migration failed'
        second = run(*native_args)
        assert '0 applied, 11 total' in second.stdout, 'Native replay was not a no-op'
        run('docker', 'exec', NAME + '-db', 'sh', '-c',
            "printf '%s' 'CREATE TABLE synthetic_rollback_probe(id int); SELECT 1/0;' > /tmp/beef-db/migrations/9999_synthetic_failure.sql")
        failed = run(*native_args, check=False)
        assert failed.returncode != 0 and PASSWORD not in failed.stdout, 'Migration failure leaked or succeeded'
        probe = run('docker', 'exec', NAME + '-db', 'psql', '-U', 'postgres', '-d', 'beef_test', '-tA', '-c',
            "SELECT to_regclass('synthetic_rollback_probe') IS NULL AND NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version='9999_synthetic_failure.sql')")
        assert probe.stdout.strip() == 't', 'Failed migration was not rolled back'
        run('docker', 'exec', NAME + '-db', 'rm', '/tmp/beef-db/migrations/9999_synthetic_failure.sql')
        print('PASS native startup migrations apply eleven files, replay without writes and roll back failure with ledger', flush=True)
    migration = run('docker', 'exec', NAME + '-db', 'env',
                    'DATABASE_URL=postgresql:///beef_test?user=postgres',
                    'bash', '/tmp/beef-db/migrate.sh')
    assert migration.stdout.count('skip   ' if DRIVER == 'postgres' else 'apply  ') == MIGRATION_COUNT, 'Migration count mismatch'
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
                 'BEEF_DATABASE_DRIVER=' + DRIVER,
                 'BEEF_TEST_NATIVE_DATABASE_URL=postgres://postgres:' + PASSWORD + '@postgres:5432/beef_test?sslmode=disable',
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
