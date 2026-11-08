#!/usr/bin/env bash
# Builds "Todo Island.app" (and a zip) into ./build from the Swift package.
#
#   scripts/bundle.sh            # version 0.1.0, native arch
#   scripts/bundle.sh 0.2.0      # custom version
#   UNIVERSAL=1 scripts/bundle.sh  # arm64 + x86_64 (needs Xcode)
#   SCRATCH_PATH=/tmp/ti-build OUT_DIR=/tmp/ti-out scripts/bundle.sh  # build outside the repo (e.g. iCloud folders)
#
# The app is ad-hoc signed, not notarized. See README for how to open it the first time.
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="Todo Island"
BUNDLE_ID="io.github.midjug3nine.todoisland"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT_DIR:-$ROOT/build}"
APP="$OUT/$APP_NAME.app"

cd "$ROOT"

ARGS=(-c release --scratch-path "${SCRATCH_PATH:-$ROOT/.build}")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)/TodoIsland"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TodoIsland"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>TodoIsland</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 MID JUG 3 Nine. MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

rm -f "$OUT/TodoIsland-$VERSION.zip"
(cd "$OUT" && ditto -c -k --keepParent "$APP_NAME.app" "TodoIsland-$VERSION.zip")

echo "Built: $APP"
echo "Zip:   $OUT/TodoIsland-$VERSION.zip"
