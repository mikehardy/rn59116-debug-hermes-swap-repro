# rn59116-debug-hermes-swap-repro

Reproducer for [facebook/react-native#59116](https://github.com/facebook/react-native/issues/59116): iOS **Debug** + CocoaPods + `use_frameworks! :linkage => :static` ends up linking **Release** `hermesvm` (no CDP) while `React-hermes` is compiled with `HERMES_ENABLE_DEBUGGER=1`.

Expected failure: undefined symbols `facebook::hermes::cdp::CDPDebugAPI::*` / `CDPAgent::create` from `HermesRuntimeTargetDelegate`.

## Why this setup

1. **Static frameworks** — RNFB’s failing CocoaPods shape.
2. **`RCT_USE_PREBUILT_RNCORE=0` / `RCT_USE_RN_DEP=0`** — prebuilt `React.xcframework` hides the failure; from-source `React-hermes` is what emits the CDP refs at link.
3. **Podfile `post_install` strips `DEBUG=1` from `hermes-engine` Debug** — stock `hermes-engine.podspec` greps `GCC_PREPROCESSOR_DEFINITIONS` for `DEBUG=1`. Fresh Xcode often reinjects `DEBUG=1` via `$(inherited)` from the Pods project, which masks the bug. The strip leaves only `COCOAPODS=1` on that target (the shape the Debug xcconfig already declares) so the Replace Hermes script keeps `CONFIG=Release` and extracts Release `hermesvm`. **No RNFB `$CONFIGURATION` workaround** is applied.

Template ships **react-native 0.87.1** (same `DEBUG=1` CONFIG grep as 0.88.0-rc.3).

## Reproduce

```bash
git clone https://github.com/mikehardy/rn59116-debug-hermes-swap-repro.git
cd rn59116-debug-hermes-swap-repro
./scripts/repro-ios-debug.sh
```

Or manually from `ReproducerApp/`:

```bash
cd ReproducerApp
yarn install
cd ios && bundle install && bundle exec pod install && cd ..
xcodebuild \
  -workspace ios/ReproducerApp.xcworkspace \
  -scheme ReproducerApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/rn59116-repro-dd \
  ONLY_ACTIVE_ARCH=YES \
  build
```

Success looks like a **failed** Debug link with `CDPDebugAPI` / `CDPAgent` undefined, and `Pods/hermes-engine/.last_build_configuration` == `Release`.

## Environment verified

- react-native `0.87.1` / hermes-engine `250829098.0.17`
- Xcode 27.0 (27A266a)
- iOS Simulator (iPhone 17 / iOS 27)
- macOS 27.0.1
