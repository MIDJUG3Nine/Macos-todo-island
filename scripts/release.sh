#!/usr/bin/env bash
# Builds a signed and notarized release: Todo Island.app, TodoIsland-<version>.dmg and .zip.
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/release.sh 0.1.0
#
# One-time setup (needs an Apple Developer account):
#   1. Create a "Developer ID Application" certificate (Xcode > Settings > Accounts >
#      Manage Certificates > +).
#   2. Store notarization credentials in the keychain (asks for an app-specific password):
#        xcrun notarytool store-credentials "todo-island-notary" --apple-id you@example.com --team-id TEAMID
#
# Options: NOTARY_PROFILE (default todo-island-notary), OUT_DIR (default ./build),
# SCRATCH_PATH (SwiftPM build folder), UNIVERSAL (default 1 = arm64 + x86_64).
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
: "${SIGN_IDENTITY:?set SIGN_IDENTITY to your \"Developer ID Application: ...\" certificate name}"
NOTARY_PROFILE="${NOTARY_PROFILE:-todo-island-notary}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT_DIR:-$ROOT/build}"
APP="$OUT/Todo Island.app"
DMG="$OUT/TodoIsland-$VERSION.dmg"
ZIP="$OUT/TodoIsland-$VERSION.zip"

echo "==> Building and signing $VERSION"
UNIVERSAL="${UNIVERSAL:-1}" SIGN_IDENTITY="$SIGN_IDENTITY" OUT_DIR="$OUT" "$ROOT/scripts/bundle.sh" "$VERSION"
codesign --verify --strict --verbose=2 "$APP"

notarize() {
  echo "==> Notarizing $(basename "$1") (this usually takes a few minutes)"
  local result status id
  result="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  echo "$result"
  status="$(printf '%s' "$result" | plutil -extract status raw -o - - 2>/dev/null || true)"
  if [[ "$status" != "Accepted" ]]; then
    id="$(printf '%s' "$result" | plutil -extract id raw -o - - 2>/dev/null || true)"
    echo "Notarization failed (status: ${status:-unknown})." >&2
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2
    exit 1
  fi
}

# Notarize and staple the app first, so the copy inside the disk image carries its own
# ticket and still opens offline after it is dragged into Applications.
notarize "$ZIP"   # bundle.sh zipped the signed app
xcrun stapler staple "$APP"
rm -f "$ZIP"
(cd "$OUT" && ditto -c -k --keepParent "Todo Island.app" "$(basename "$ZIP")")

echo "==> Making the disk image"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Todo Island" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> Checking with Gatekeeper"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
MNT="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null
xcrun stapler validate "$MNT/Todo Island.app"
hdiutil detach "$MNT" >/dev/null
rmdir "$MNT"

echo
shasum -a 256 "$DMG" "$ZIP"
echo "Done: $DMG"
