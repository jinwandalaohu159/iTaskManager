#!/bin/zsh
# Builds the first-install disk image from a release zip, so the DMG holds exactly the app
# that was published: the app next to a shortcut to Applications, to drag across.
#   scripts/make-dmg.sh build/iTaskManager-1.0.0.zip build/iTaskManager-1.0.0.dmg
set -euo pipefail

ZIP="$1"
DMG="$2"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

ditto -x -k "$ZIP" "$STAGE"
codesign --verify --deep --strict "$STAGE/iTaskManager.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "iTaskManager" -srcfolder "$STAGE" -fs APFS -format ULFO -ov "$DMG"
echo "Packaged $DMG ($(du -h "$DMG" | cut -f1))"
