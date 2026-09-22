#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/dist/tests"
SWIFT_TEST_BINARY="$BUILD_DIR/SetupConfigurationTests"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR"

printf '==> Running Swift tests\n'
swiftc \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$ROOT_DIR/sources/GAMMASetupCore/"*.swift \
  "$ROOT_DIR/sources/GAMMASetupTool/AppSettingsStore.swift" \
  "$ROOT_DIR/sources/GAMMASetupTool/MacDisplaySettings.swift" \
  "$ROOT_DIR/sources/GAMMASetupTool/SetupConfiguration.swift" \
  "$ROOT_DIR/sources/GAMMASetupTool/SetupStatusTone.swift" \
  "$ROOT_DIR/tests/swift/AppSettingsStoreTests.swift" \
  "$ROOT_DIR/tests/swift/SetupConfigurationTests.swift" \
  "$ROOT_DIR/tests/swift/RedistInstallerTests.swift" \
  "$ROOT_DIR/tests/swift/SetupStatusToneTests.swift" \
  "$ROOT_DIR/tests/swift/USVFSUpdaterTests.swift" \
  "$ROOT_DIR/tests/swift/main.swift" \
  -o "$SWIFT_TEST_BINARY"
"$SWIFT_TEST_BINARY"

printf '\n==> Building Swift setup engine for CLI tests\n'
swiftc \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$ROOT_DIR/sources/GAMMASetupCore/"*.swift \
  "$ROOT_DIR/sources/GAMMASetupEngine/main.swift" \
  -o "$BUILD_DIR/gamma-setup-engine"

printf '\n==> Running Swift setup engine CLI tests\n'
"$BUILD_DIR/gamma-setup-engine" --help >/dev/null
bash "$ROOT_DIR/tests/shell/gamma_setup_engine_tests.sh" "$ROOT_DIR" "$BUILD_DIR/gamma-setup-engine"

printf '\n==> Running build smoke test\n'
"$ROOT_DIR/build.sh" >/dev/null

printf '\nAll tests passed.\n'
