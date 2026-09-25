#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_VERSION="0.90"
BUILD_DIR="$ROOT_DIR/dist"
INTERMEDIATES_DIR="$BUILD_DIR/intermediates"
APP_DIR="$BUILD_DIR/GAMMA Setup Tool.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_RESOURCES_DIR="$ROOT_DIR/sources/GAMMASetupTool/Resources"
BINARY="$MACOS_DIR/GAMMA Setup Tool"
INTERMEDIATE_BINARY="$INTERMEDIATES_DIR/GAMMA Setup Tool"
ENGINE_BINARY="$RESOURCES_DIR/gamma-setup-engine"
INTERMEDIATE_ENGINE_BINARY="$INTERMEDIATES_DIR/gamma-setup-engine"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
MODE="${1:-build}"

# build:  build dist/, sign it, and install it into ~/Applications
# bundle: build and sign dist/ only (what test.sh uses; installs nothing)
# run:    build dist/ and run the app binary directly
case "$MODE" in
  build|bundle|run|clean)
    ;;
  *)
    printf 'Usage: %s [build|bundle|run|clean]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

if [[ "$MODE" == "clean" ]]; then
  rm -rf "$BUILD_DIR"
  printf 'Removed %s\n' "$BUILD_DIR"
  exit 0
fi

is_stale() {
  local output="$1"
  shift

  if [[ ! -e "$output" ]]; then
    return 0
  fi

  local input
  for input in "$@"; do
    if [[ "$input" -nt "$output" ]]; then
      return 0
    fi
  done

  return 1
}

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR" "$INTERMEDIATES_DIR"

swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macosx15.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework SwiftUI \
  -framework AppKit \
  "$ROOT_DIR"/sources/GAMMASetupCore/*.swift \
  "$ROOT_DIR"/sources/GAMMASetupTool/*.swift \
  -o "$INTERMEDIATE_BINARY"

cp "$INTERMEDIATE_BINARY" "$BINARY"

if [[ "$MODE" != "run" ]] || is_stale "$INTERMEDIATE_ENGINE_BINARY" "$ROOT_DIR"/sources/GAMMASetupCore/*.swift "$ROOT_DIR"/sources/GAMMASetupEngine/main.swift; then
  swiftc \
    -O \
    -target arm64-apple-macosx15.0 \
    -module-cache-path "$MODULE_CACHE_DIR" \
    "$ROOT_DIR"/sources/GAMMASetupCore/*.swift \
    "$ROOT_DIR"/sources/GAMMASetupEngine/main.swift \
    -o "$INTERMEDIATE_ENGINE_BINARY"
fi

cp "$INTERMEDIATE_ENGINE_BINARY" "$ENGINE_BINARY"
chmod +x "$ENGINE_BINARY"

cp "$SOURCE_RESOURCES_DIR/Anomaly.icns" "$RESOURCES_DIR/GAMMASetupTool.icns"
cp "$SOURCE_RESOURCES_DIR/Anomaly.icns" "$RESOURCES_DIR/Anomaly.icns"
cp "$SOURCE_RESOURCES_DIR/MO2.icns" "$RESOURCES_DIR/MO2.icns"
if [[ -d "$SOURCE_RESOURCES_DIR/usvfs" ]]; then
  rm -rf "$RESOURCES_DIR/usvfs"
  cp -R "$SOURCE_RESOURCES_DIR/usvfs" "$RESOURCES_DIR/usvfs"
fi
# interactive_setup.py lives here now (sources/GAMMASetupTool/Resources/
# wine-engine/), not in gamma-wine-engine — no cross-repo sync needed.
rm -rf "$RESOURCES_DIR/wine-engine"
cp -R "$SOURCE_RESOURCES_DIR/wine-engine" "$RESOURCES_DIR/wine-engine"
chmod +x "$RESOURCES_DIR/wine-engine/interactive_setup.py"
cp "$SOURCE_RESOURCES_DIR/github.svg" "$RESOURCES_DIR/github.svg"
cp "$SOURCE_RESOURCES_DIR/discord.svg" "$RESOURCES_DIR/discord.svg"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GAMMA Setup Tool</string>
  <key>CFBundleIconFile</key>
  <string>GAMMASetupTool</string>
  <key>CFBundleIdentifier</key>
  <string>com.elseform.gamma-setup-tool</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>GAMMA Setup Tool</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>APP_VERSION_PLACEHOLDER</string>
  <key>CFBundleVersion</key>
  <string>APP_VERSION_PLACEHOLDER</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

perl -0pi -e "s/APP_VERSION_PLACEHOLDER/$APP_VERSION/g" "$CONTENTS_DIR/Info.plist"

INSTALL_DIR="$HOME/Applications"

if [[ "$MODE" == "build" || "$MODE" == "bundle" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
fi

if [[ "$MODE" == "build" ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/GAMMA Setup Tool.app"
  cp -R "$APP_DIR" "$INSTALL_DIR/GAMMA Setup Tool.app"
  printf '%s\n' "$INSTALL_DIR/GAMMA Setup Tool.app"
fi

if [[ "$MODE" == "run" ]]; then
  "$BINARY"
fi
