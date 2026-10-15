#!/usr/bin/env bash
# Reproduce facebook/react-native#59116: Debug + static CocoaPods selects Release
# hermesvm (no CDP) while React-hermes is built with HERMES_ENABLE_DEBUGGER=1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/ReproducerApp"
IOS="$APP/ios"

cd "$APP"
yarn install
cd "$IOS"
bundle install
bundle exec pod install

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
DERIVED="${DERIVED_DATA_PATH:-/tmp/rn59116-repro-dd}"
LOG="${BUILD_LOG:-/tmp/rn59116-repro-xcodebuild.log}"
rm -rf "$DERIVED"

echo "Building Debug (expect linker undefined facebook::hermes::cdp::CDPDebugAPI::* )..."
set +e
xcodebuild \
  -workspace ReproducerApp.xcworkspace \
  -scheme ReproducerApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  ONLY_ACTIVE_ARCH=YES \
  build 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e

MARKER="$IOS/Pods/hermes-engine/.last_build_configuration"
HERMES_BIN="$IOS/Pods/hermes-engine/destroot/Library/Frameworks/universal/hermesvm.xcframework/ios-arm64_x86_64-simulator/hermesvm.framework/hermesvm"

echo
if [[ -f "$MARKER" ]]; then
  echo "hermes-engine/.last_build_configuration=$(cat "$MARKER")"
fi
if [[ -f "$HERMES_BIN" ]]; then
  CDP_COUNT="$(nm -gU "$HERMES_BIN" 2>/dev/null | grep -c 'CDPDebugAPI' || true)"
  echo "CDPDebugAPI symbol count in simulator hermesvm: ${CDP_COUNT:-0} (0 => Release flavor)"
fi

if [[ "$STATUS" -eq 0 ]]; then
  echo "ERROR: build unexpectedly succeeded — bug not reproduced." >&2
  exit 1
fi

if ! grep -q 'CDPDebugAPI' "$LOG"; then
  echo "ERROR: build failed but CDPDebugAPI was not in the log — unexpected failure mode." >&2
  exit 1
fi

echo
echo "Reproduced: Debug link failed with undefined CDPDebugAPI / CDPAgent (expected)."
exit "$STATUS"
