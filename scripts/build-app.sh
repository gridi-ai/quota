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
codesign --force --sign - "$app"
printf 'Built %s\n' "$PWD/$app"
