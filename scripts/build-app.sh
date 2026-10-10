#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release \
    -Xswiftc -gnone \
    -Xswiftc -file-prefix-map -Xswiftc "$PWD=/QuotaSource"
binary_dir="$(swift build -c release --show-bin-path)"
app="dist/Quota.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Quota" "$app/Contents/MacOS/Quota"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
for bundle in Quota_QuotaCore.bundle Quota_QuotaApp.bundle; do
    # ditto replaces changed files without depending on a developer build path.
    ditto "$binary_dir/$bundle" "$app/Contents/Resources/$bundle"
done
codesign --force --sign - "$app"
printf 'Built %s\n' "$PWD/$app"
