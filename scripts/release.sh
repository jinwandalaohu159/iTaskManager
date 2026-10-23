#!/bin/zsh
# Packages build/iTaskManager.app for release, at the version in VERSION:
#   build/iTaskManager-<version>.zip and .zip.sha256 (what the in-app updater downloads).
#
#   scripts/release.sh                       build and package only
#   scripts/release.sh --publish NOTES.md    also create the GitHub release v<version>
set -euo pipefail

ROOT="${0:A:h:h}"
REPO="jinwandalaohu159/iTaskManager"
cd "$ROOT"
VERSION="$(cat VERSION)"

./scripts/build-app.sh

ZIP="build/iTaskManager-$VERSION.zip"
rm -f "$ZIP" "$ZIP.sha256"
# ditto keeps the bundle's signature and symlinks intact, unlike zip.
ditto -c -k --keepParent build/iTaskManager.app "$ZIP"
shasum -a 256 "$ZIP" | awk '{print $1}' > "$ZIP.sha256"
echo "Packaged $ZIP ($(du -h "$ZIP" | cut -f1)), sha256 $(cat "$ZIP.sha256")"

if [[ "${1:-}" == "--publish" ]]; then
    NOTES="${2:?release notes file required}"
    gh release create "v$VERSION" "$ZIP" "$ZIP.sha256" \
        --repo "$REPO" --title "iTaskManager $VERSION" --notes-file "$NOTES"
fi
