#!/usr/bin/env bash
# Build PassivMac and wrap the SwiftPM executable into a proper macOS .app bundle.
#
# SwiftPM produces a raw Mach-O executable, but SwiftUI requires a .app bundle
# with an Info.plist (for CFBundleIdentifier, window-tab indexing, Dock
# integration, etc.). This script builds, then assembles PassivMac.app.
#
# Usage:
#     ./scripts/build-app.sh                 # Debug build, open the .app
#     ./scripts/build-app.sh release         # Release build
#     ./scripts/build-app.sh debug nolaunch  # build only, don't open

set -euo pipefail

CONFIG="${1:-debug}"
LAUNCH="${2:-launch}"

# Resolve repo root regardless of where the script is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "error: first arg must be 'debug' or 'release' (got '$CONFIG')" >&2
    exit 2
fi

# Prefer Xcode's toolchain (has SwiftData macros); fall back to system swift.
if [[ -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "→ Building PassivMac ($CONFIG) via xcodebuild…"
# Pin DerivedData under the repo so we always know where the built binary is.
DERIVED="$REPO_ROOT/.build/derivedData"
CONF_DIR="Debug"
XCCONFIG=""
if [[ "$CONFIG" == "release" ]]; then
    XCCONFIG="-configuration Release"
    CONF_DIR="Release"
fi

xcodebuild build \
    -scheme PassivMac \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    $XCCONFIG \
    >/tmp/passivmac-build.log 2>&1 || {
    echo "✗ Build failed. Tail of log:" >&2
    tail -30 /tmp/passivmac-build.log >&2
    exit 1
}

BUILT_BIN="$DERIVED/Build/Products/$CONF_DIR"
EXE="$BUILT_BIN/PassivMac"
if [[ ! -f "$EXE" ]]; then
    echo "✗ Executable not found at $EXE" >&2
    exit 1
fi

# Assemble .app next to the repo so it's easy to find.
APP_DIR="$REPO_ROOT/build/PassivMac.app"
echo "→ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$EXE" "$APP_DIR/Contents/MacOS/PassivMac"
cp "$REPO_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy any dynamic frameworks SwiftPM linked in (e.g. KeychainAccess).
if [[ -d "$BUILT_BIN/PackageFrameworks" ]]; then
    mkdir -p "$APP_DIR/Contents/Frameworks"
    # Copy each .framework bundle (not individual .o files).
    find "$BUILT_BIN/PackageFrameworks" -maxdepth 1 -type d -name "*.framework" \
        -exec cp -R {} "$APP_DIR/Contents/Frameworks/" \;
fi

# Ad-hoc sign so macOS will launch it from anywhere on disk (no Gatekeeper prompt).
codesign --force --sign - --deep "$APP_DIR" >/dev/null 2>&1 || true

echo "✓ Built $APP_DIR"

if [[ "$LAUNCH" == "launch" ]]; then
    echo "→ Opening app…"
    open "$APP_DIR"
fi
