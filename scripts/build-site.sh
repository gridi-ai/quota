#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Explicit publication allowlist: never copy docs, accounts, agent state or caches.
out=".build/site"
mkdir -p "$out/assets" "$out/ko"
cp site/index.html "$out/index.html"
cp site/ko/index.html "$out/ko/index.html"
cp site/assets/style.css "$out/assets/style.css"
cp site/assets/analytics.js "$out/assets/analytics.js"
cp Resources/AppIcon.png "$out/assets/icon.png"
cp site/sitemap.xml site/.nojekyll "$out/"
printf 'Built %s\n' "$PWD/$out"
