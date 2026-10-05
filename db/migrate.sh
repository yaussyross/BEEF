#!/usr/bin/env bash
# =============================================================================
# BEEF — migration runner
#
# Applies db/migrations/*.sql in filename order, tracking applied files in a
# `schema_migrations` table so re-runs are no-ops (versioned runner). Every
# individual file is ALSO internally idempotent (IF NOT EXISTS / DO blocks), so
# it is safe to apply the same file twice.
#
# Requirements: `psql` on PATH and DATABASE_URL set (same env the backend uses).
#
#   DATABASE_URL=postgres://... bash db/migrate.sh
#
# If psql is unavailable (as in this sandbox), run the files in order through
# the Neon SQL console instead — see db/migrations/README.md.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/migrations"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set. Connect a database before running migrations." >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Apply db/migrations/*.sql in order via the Neon SQL console." >&2
  exit 2
fi

PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" -c 'CREATE TABLE IF NOT EXISTS schema_migrations (
  version    text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);'

for file in $(ls -1 *.sql | sort); do
  version="$(basename "$file")"
  applied="$("${PSQL[@]}" -tA -c "SELECT 1 FROM schema_migrations WHERE version = '${version}'")"
  if [[ "$applied" == "1" ]]; then
    echo "skip   ${version} (already applied)"
    continue
  fi
  echo "apply  ${version}"
  "${PSQL[@]}" -f "$file"
  "${PSQL[@]}" -c "INSERT INTO schema_migrations (version) VALUES ('${version}')"
done

echo "migrations up to date"
