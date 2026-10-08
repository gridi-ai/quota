#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Run build-app.sh first. Packaging never copies account or credential directories.
app="dist/Quota.app"
[ -d "$app" ] || { printf 'Run bash scripts/build-app.sh first.\n' >&2; exit 1; }
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
archs="$(lipo -archs "$app/Contents/MacOS/Quota")"
case "$archs" in
    arm64|x86_64) arch="$archs" ;;
    *) printf 'Unsupported release architecture: %s\n' "$archs" >&2; exit 1 ;;
esac
codesign --verify --deep --strict "$app"
archive="Quota-${version}-macOS-${arch}.zip"
ditto -c -k --keepParent --norsrc --noextattr "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS)
printf 'Packaged dist/%s and dist/SHA256SUMS\n' "$archive"
