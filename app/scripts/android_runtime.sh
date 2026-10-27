#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/runtime-artifacts
# Fail explicitly if this free runner cannot accelerate the emulator.
test -e /dev/kvm || { echo 'BLOCKED: runner has no /dev/kvm'; exit 1; }
sudo chmod a+rw /dev/kvm
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
test -x "$ANDROID_HOME/platform-tools/adb"
adb version
export ANDROID_USER_HOME="$RUNNER_TEMP/beef-android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
mkdir -p "$ANDROID_AVD_HOME"
sdkmanager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
avdmanager="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
"$sdkmanager" 'system-images;android-35;google_apis;x86_64'
printf 'no\n' | "$avdmanager" create avd --force -n beef_synthetic --device pixel_2 -p "$ANDROID_AVD_HOME/beef_synthetic.avd" -k 'system-images;android-35;google_apis;x86_64'
test -f "$ANDROID_AVD_HOME/beef_synthetic.avd/config.ini"
"$ANDROID_HOME/emulator/emulator" -list-avds | tee build/runtime-artifacts/avds.txt
grep -qx beef_synthetic build/runtime-artifacts/avds.txt
"$ANDROID_HOME/emulator/emulator" -avd beef_synthetic -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -no-snapshot -memory 2048 -cores 2 -camera-back none -camera-front none > build/runtime-artifacts/emulator.log 2>&1 &
emulator_pid=$!
cleanup() {
  result=$?
  if [[ $result -ne 0 ]]; then tail -n 100 build/runtime-artifacts/emulator.log; fi
  adb -s emulator-5554 emu kill >/dev/null 2>&1 || true
  kill "$emulator_pid" 2>/dev/null || true
  exit "$result"
}
trap cleanup EXIT
for attempt in $(seq 1 120); do
  kill -0 "$emulator_pid" 2>/dev/null || { echo "BLOCKED: emulator exited before boot"; exit 1; }
  if [[ "$(adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then break; fi
  sleep 2
done
test "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" = 1
adb -s emulator-5554 shell input keyevent 82
adb -s emulator-5554 shell cmd connectivity airplane-mode enable
adb -s emulator-5554 shell svc wifi disable
adb -s emulator-5554 shell svc data disable
adb -s emulator-5554 shell dumpsys connectivity > build/runtime-artifacts/connectivity.txt
grep -q 'Active default network: none' build/runtime-artifacts/connectivity.txt || { echo 'BLOCKED: emulator still has a default network'; exit 1; }
# Actual configured APK from this job, not a re-downloaded artifact. Offline.
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell pm clear com.beef.beef
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am start -W -n com.beef.beef/.MainActivity
sleep 5
adb -s emulator-5554 shell pidof com.beef.beef
adb -s emulator-5554 exec-out screencap -p > build/runtime-artifacts/00-configured-apk-onboarding.png
adb -s emulator-5554 shell input keyevent 3
adb -s emulator-5554 shell am start -W -n com.beef.beef/.MainActivity
sleep 2
adb -s emulator-5554 shell pidof com.beef.beef
adb -s emulator-5554 logcat -d > build/runtime-artifacts/configured-apk-logcat.txt
if grep -E 'FATAL EXCEPTION|E/flutter.*(Unhandled Exception|Error:)' build/runtime-artifacts/configured-apk-logcat.txt; then exit 1; fi
adb -s emulator-5554 shell am force-stop com.beef.beef
# Same screens/controllers on Android; every transport is an in-memory fixture.
flutter drive --driver=test_driver/runtime_driver.dart --target=integration_test/runtime_test.dart -d emulator-5554 --no-pub
printf '%s\n' 'PASS Android API35 x86_64: offline configured APK launch/resume; fixture runtime and platform keystore tests. No hosted acceptance.' > build/runtime-artifacts/RESULT.txt
