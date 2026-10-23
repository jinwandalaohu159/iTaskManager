#!/bin/zsh
# Builds build/iTaskManager.app without Xcode.
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/iTaskManager.app"
# The version lives in VERSION at the repository root; VERSION=x.y.z in the environment overrides it.
VERSION="${VERSION:-$(cat "$ROOT/VERSION")}"

cd "$ROOT"
swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"
cp .build/arm64-apple-macosx/release/iTaskManager "$APP/Contents/MacOS/iTaskManager"

# The root helper for reading system processes; launchd runs it once the user approves it
# (see PrivilegedHelper.swift). It's started on demand and exits when idle.
HELPER_LABEL="com.rhysmao.iTaskManager.helper"
cp .build/arm64-apple-macosx/release/iTaskManagerHelper "$APP/Contents/MacOS/iTaskManagerHelper"
cat > "$APP/Contents/Library/LaunchDaemons/$HELPER_LABEL.plist" <<HELPER
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$HELPER_LABEL</string>
    <key>BundleProgram</key><string>Contents/MacOS/iTaskManagerHelper</string>
    <key>MachServices</key><dict><key>$HELPER_LABEL</key><true/></dict>
    <key>AssociatedBundleIdentifiers</key><array><string>com.rhysmao.iTaskManager</string></array>
</dict>
</plist>
HELPER

# App icon from icon.png (already laid out on the macOS icon grid), rebuilt when it changes.
ICON="$ROOT/icon.png"
ICONSET="$ROOT/build/AppIcon.iconset"
if [[ ! -f "$ROOT/build/AppIcon.icns" || "$ICON" -nt "$ROOT/build/AppIcon.icns" ]]; then
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size "$ICON" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ROOT/build/AppIcon.icns"
    rm -rf "$ICONSET"
fi
cp "$ROOT/build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>iTaskManager</string>
    <key>CFBundleDisplayName</key><string>iTaskManager</string>
    <key>CFBundleIdentifier</key><string>com.rhysmao.iTaskManager</string>
    <key>CFBundleExecutable</key><string>iTaskManager</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Nested code first, then the bundle that seals it.
codesign --force --sign - --identifier "$HELPER_LABEL" "$APP/Contents/MacOS/iTaskManagerHelper"
codesign --force --sign - "$APP"
echo "Built $APP"
