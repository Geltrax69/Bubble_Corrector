#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/WordPop.app"
DMG_STAGING="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/WordPop.dmg"
TMP_DMG="$DIST_DIR/WordPop-tmp.dmg"

"$ROOT_DIR/Scripts/build_wordpop_app.sh" >/dev/null

rm -rf "$DMG_STAGING" "$DMG_PATH" "$TMP_DMG"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/WordPop.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "WordPop" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDRW \
  "$TMP_DMG" >/dev/null

MOUNT_DIR="$(mktemp -d /tmp/wordpop-dmg.XXXXXX)"
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

osascript <<APPLESCRIPT
tell application "Finder"
    tell folder POSIX file "$MOUNT_DIR"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 640, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "WordPop.app" of container window to {170, 160}
        set position of item "Applications" of container window to {390, 160}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"

hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

rm -rf "$TMP_DMG" "$DMG_STAGING"
echo "$DMG_PATH"
