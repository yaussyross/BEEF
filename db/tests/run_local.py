#!/usr/bin/env python3
"""Test real migrations in a disposable, network-isolated PostgreSQL container.
Requires Docker and the pinned PostGIS image already downloaded. Never pulls.
No production DATABASE_URL is read; data is memory-backed and removed on exit.
"""
from pathlib import Path
import secrets
import subprocess
import time

IMAGE = 'postgis/postgis@sha256:01a6a70e41e6c4467c8f55f6063555ed72db2d6662cd0d571040d42eadaeb6f6'
ROOT = Path(__file__).resolve().parents[2]
MIGRATION_COUNT = len(list((ROOT / 'db/migrations').glob('[0-9][0-9][0-9][0-9]_*.sql')))
NAME = 'beef-local-test-' + secrets.token_hex(5)

def run(*args, check=True):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, check=check, timeout=120)

def execute(*args):
    return run('docker', 'exec', NAME, *args).stdout

run('docker', 'image', 'inspect', IMAGE)
try:
    run('docker', 'run', '--detach', '--rm', '--pull=never', '--name', NAME,
        '--network=none', '--tmpfs', '/var/lib/postgresql/data:rw',
        '-e', 'POSTGRES_DB=beef_test',
        '-e', 'POSTGRES_PASSWORD=' + secrets.token_urlsafe(32), IMAGE)
    # pg_isready can briefly succeed against the initialization server. Wait
    # for the final PID 1 postgres process, then check readiness.
    for _ in range(60):
        ready = run('docker', 'exec', NAME, 'sh', '-c',
                    'test "$(cat /proc/1/comm)" = postgres && pg_isready -U postgres -d beef_test', check=False)
        if ready.returncode == 0:
            break
        time.sleep(1)
    else:
        raise RuntimeError('PostgreSQL did not become ready')
    run('docker', 'cp', str(ROOT / 'db'), NAME + ':/tmp/beef-db')
    print(execute('psql', '-U', 'postgres', '-d', 'beef_test', '-At', '-c',
                  'SELECT version(); SELECT postgis_full_version();'), flush=True)
    migration = ['env', 'DATABASE_URL=postgresql:///beef_test?user=postgres',
                 'bash', '/tmp/beef-db/migrate.sh']
    first = execute(*migration)
    assert first.count('apply  ') == MIGRATION_COUNT, first
    print('PASS: all migrations applied to fresh local database', flush=True)
    second = execute(*migration)
    assert second.count('skip   ') == MIGRATION_COUNT and 'apply  ' not in second, second
    print('PASS: second migration run skips all migration files', flush=True)
    result = execute('psql', '-U', 'postgres', '-d', 'beef_test', '-v',
                     'ON_ERROR_STOP=1', '-v', f'migration_count={MIGRATION_COUNT}', '-f', '/tmp/beef-db/tests/contracts.sql')
    print(result, flush=True)
    assert 'FAIL:' not in result
    print(execute('psql', '-U', 'postgres', '-d', 'beef_test', '-v',
                  'ON_ERROR_STOP=1', '-f', '/tmp/beef-db/tests/ratings.sql'), flush=True)
    assert execute('psql', '-U', 'postgres', '-d', 'beef_test', '-At', '-c',
                   'SELECT count(*) FROM users;').strip() == '0'
except subprocess.CalledProcessError as error:
    print(error.stdout, flush=True)
    raise SystemExit(error.returncode)
finally:
    # Only the uniquely named container created by this run can be removed.
    result = run('docker', 'rm', '--force', '--volumes', NAME, check=False)
    if result.returncode == 0:
        print('Removed disposable test container and memory-backed data.', flush=True)
