#!/usr/bin/env bash
# Legacy command name: build and run in the foreground, NOT a deployment tool.
# The service supervisor owns restarts. Never kill or supersede another listener.
# Inject the documented staging environment explicitly before invoking this file.
set -euo pipefail
cd "$(dirname "$0")"
bun run build
exec bun --no-env-file serve.ts
