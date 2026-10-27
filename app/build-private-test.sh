#!/usr/bin/env bash
set -euo pipefail
# No credentials belong in this argument: the mobile app contains the URL.
: "${BEEF_API_BASE_URL:?Set the approved private HTTPS origin first}"
case "$BEEF_API_BASE_URL" in
  https://*) ;;
  *) echo 'Private test requires an HTTPS origin.' >&2; exit 2 ;;
esac
case "$BEEF_API_BASE_URL" in
  *'@'*|*'?'*|*'#'*) echo 'Do not put credentials or tokens in the build URL.' >&2; exit 2 ;;
esac
cd "$(dirname "$0")"
flutter analyze
flutter test
flutter build apk --debug --dart-define="BEEF_API_BASE_URL=${BEEF_API_BASE_URL%/}"
echo 'APK: app/build/app/outputs/flutter-apk/app-debug.apk'
echo 'Test only with synthetic adult accounts behind approved HTTP/WebSocket access controls.'
