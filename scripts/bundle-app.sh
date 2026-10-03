#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
if [[ "$CONFIGURATION" != debug && "$CONFIGURATION" != release ]]; then
  printf 'Usage: %s [debug|release]\n' "$0" >&2
  exit 2
fi
APP_DIR="$REPO_DIR/app"
OUTPUT_DIR="$REPO_DIR/build"
BUNDLE_PATH="$OUTPUT_DIR/Milyonus Nottaker.app"
IDENTITY="${MILYONUS_SIGNING_IDENTITY:--}"
mkdir -p "$OUTPUT_DIR"

python3 "$REPO_DIR/scripts/generate-localizations.py"
swift build --package-path "$APP_DIR" --configuration "$CONFIGURATION" -Xswiftc -warnings-as-errors
BIN_DIR="$(swift build --package-path "$APP_DIR" --configuration "$CONFIGURATION" --show-bin-path)"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/bundle-stage.XXXXXX")"
STAGED_APP="$STAGING_DIR/Milyonus Nottaker.app"
CONTENTS="$STAGED_APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/MilyonusApp" "$CONTENTS/MacOS/MilyonusApp"
cp "$APP_DIR/Support/Info.plist" "$CONTENTS/Info.plist"
cp -R "$APP_DIR/Support/en.lproj" "$APP_DIR/Support/tr.lproj" "$CONTENTS/Resources/"

# The app's resource locators prefer standard Contents/Resources bundles and fall back to
# SwiftPM's generated Bundle.module path for command-line builds and tests.
for resource_bundle in "$BIN_DIR"/*.bundle; do
  [[ -d "$resource_bundle" ]] || continue
  cp -R "$resource_bundle" "$CONTENTS/Resources/"
done

ICONSET="$STAGING_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$REPO_DIR/milyonus-emblem.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$REPO_DIR/milyonus-emblem.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$CONTENTS/Info.plist" >/dev/null

if [[ "$IDENTITY" == - ]]; then
  codesign --force --sign - --entitlements "$APP_DIR/Support/MilyonusApp.entitlements" "$STAGED_APP"
  printf 'Signing: ad hoc local preview. Stable TCC and distribution acceptance remain pending.\n'
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" \
    --entitlements "$APP_DIR/Support/MilyonusApp.entitlements" "$STAGED_APP"
  printf 'Signing: configured identity. Verify TCC persistence before marking P0-05 complete.\n'
fi
codesign --verify --deep --strict "$STAGED_APP"

# Preserve any previous generated bundle rather than deleting it.
if [[ -e "$BUNDLE_PATH" ]]; then
  mv "$BUNDLE_PATH" "$STAGING_DIR/Previous.app"
fi
mv "$STAGED_APP" "$BUNDLE_PATH"
printf 'Bundle ready: %s\n' "$BUNDLE_PATH"
