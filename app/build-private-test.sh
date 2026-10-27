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
origin=${BEEF_API_BASE_URL#https://}
origin=${origin%/}
if [[ ! "$origin" =~ ^[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
  echo 'Use an HTTPS hostname origin, without a path.' >&2; exit 2
fi
cd "$(dirname "$0")"
if [[ ! -d android || ! -d ios ]]; then
  scaffold=$(mktemp -d)
  trap 'rm -rf "$scaffold"' EXIT
  flutter create "$scaffold/generated" --org com.beef --project-name beef --platforms android,ios --no-pub
  [[ -d android ]] || cp -a "$scaffold/generated/android" ./android
  [[ -d ios ]] || cp -a "$scaffold/generated/ios" ./ios
  [[ -f .metadata ]] || cp "$scaffold/generated/.metadata" .metadata
fi
flutter pub get
python3 scripts/configure_platforms.py
dart run flutter_launcher_icons
export BYPASS_PERMISSION_LOCATION_ALWAYS=1
flutter analyze
flutter test
flutter build apk --debug --dart-define="BEEF_API_BASE_URL=${BEEF_API_BASE_URL%/}"
echo 'APK: app/build/app/outputs/flutter-apk/app-debug.apk'
echo 'Test only with synthetic adult accounts behind approved HTTP/WebSocket access controls.'
