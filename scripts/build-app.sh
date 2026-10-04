#!/bin/bash
# Builds "OwnSpace.app" into dist/.
#
#   scripts/build-app.sh                        release build, ad-hoc signature
#   OWNSPACE_SIGN_IDENTITY="My Local Signing" scripts/build-app.sh
#   CONFIG=debug scripts/build-app.sh
#
# Ad-hoc signing is the default and needs no certificate. Its one side effect: macOS ties the
# Full Disk Access grant to the signature, and an ad-hoc signature changes per build, so it may
# need granting again after a rebuild.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
IDENTITY="${OWNSPACE_SIGN_IDENTITY:--}"
VERSION="${OWNSPACE_VERSION:-0.1.0}"
DIST="$ROOT/dist"
APP="$DIST/OwnSpace.app"

echo "building ownspace ($CONFIG)"
(cd "$ROOT" && swift build -c "$CONFIG" --product ownspace 2>&1 | tail -1)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/$CONFIG/ownspace" "$APP/Contents/MacOS/ownspace"
[ -f "$ROOT/assets/AppIcon.icns" ] && cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ownspace</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.im-fahad.ownspace</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>OwnSpace</string>
  <key>CFBundleDisplayName</key><string>OwnSpace</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License.</string>
</dict>
</plist>
PLIST

codesign --force --sign "$IDENTITY" "$APP" 2>&1 | grep -v 'replacing existing signature' || true
codesign --verify --strict "$APP"
echo "built $APP"
echo
echo "Install: cp -R \"$APP\" /Applications/"
