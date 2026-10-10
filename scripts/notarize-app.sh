#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Credentials stay in Keychain. No certificate, key or Apple password belongs here.
: "${QUOTA_SIGNING_IDENTITY:?Set your Developer ID Application signing identity}"
: "${QUOTA_NOTARY_PROFILE:?Set an existing notarytool Keychain profile name}"
app="dist/Quota.app"
[ -d "$app" ] || { printf 'Run bash scripts/build-app.sh first.\n' >&2; exit 1; }
codesign --force --options runtime --timestamp --sign "$QUOTA_SIGNING_IDENTITY" "$app"
codesign --verify --deep --strict "$app"
archive="dist/Quota-notarization.zip"
ditto -c -k --keepParent --norsrc --noextattr "$app" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$QUOTA_NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
bash scripts/package-release.sh
