#!/bin/bash
set -euo pipefail

version="0.1.0"
destination="${HOME}/Applications"
replace=false

usage() {
    printf 'Usage: bash install.sh [--destination DIRECTORY] [--replace]\n'
    printf 'Installs Quota %s for Apple Silicon, macOS 14+. No sudo or Xcode required.\n' "$version"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --destination)
            [ "$#" -ge 2 ] && [ -n "$2" ] || { usage >&2; exit 2; }
            destination="$2"
            shift 2
            ;;
        --replace) replace=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

[ "$(uname -s)" = Darwin ] || { printf 'Quota requires macOS.\n' >&2; exit 1; }
[ "$(uname -m)" = arm64 ] || { printf 'This release supports Apple Silicon only. Intel Macs can build from source.\n' >&2; exit 1; }
major="$(sw_vers -productVersion)"
major="${major%%.*}"
[ "$major" -ge 14 ] || { printf 'Quota requires macOS 14 or newer.\n' >&2; exit 1; }
[ -d "$destination" ] || mkdir -p "$destination"
destination="$(cd "$destination" && pwd -P)"
app="$destination/Quota.app"
[ ! -L "$app" ] || { printf 'Refusing a symlink destination: %s\n' "$app" >&2; exit 1; }
if [ -e "$app" ] && [ "$replace" = false ]; then
    printf '%s already exists. Quit Quota and rerun with --replace to update.\n' "$app" >&2
    exit 1
fi

archive="Quota-${version}-macOS-arm64.zip"
base="https://github.com/gridi-ai/quota/releases/download/v${version}"
work="$(mktemp -d "${TMPDIR:-/tmp}/quota-install.XXXXXX")"
trap 'rm -rf "$work"' EXIT
curl --fail --location --proto '=https' --tlsv1.2 "$base/$archive" -o "$work/$archive"
curl --fail --location --proto '=https' --tlsv1.2 "$base/SHA256SUMS" -o "$work/SHA256SUMS"
(
    cd "$work"
    expected="$(awk -v name="$archive" '$2 == name { print $1 }' SHA256SUMS)"
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { printf 'Release checksum is missing or invalid.\n' >&2; exit 1; }
    actual="$(shasum -a 256 "$archive")"
    [ "${actual%% *}" = "$expected" ] || { printf 'Release checksum mismatch.\n' >&2; exit 1; }
)
ditto -x -k "$work/$archive" "$work/unpacked"
source_app="$work/unpacked/Quota.app"
[ -f "$source_app/Contents/MacOS/Quota" ] && [ -x "$source_app/Contents/MacOS/Quota" ] ||
    { printf 'Release does not contain an executable Quota.app.\n' >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$source_app/Contents/Info.plist")" = "local.codex-usage.Quota" ] ||
    { printf 'Unexpected bundle identifier.\n' >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$source_app/Contents/Info.plist")" = "$version" ] ||
    { printf 'Unexpected bundle version.\n' >&2; exit 1; }
codesign --verify --deep --strict "$source_app"
if [ -e "$app" ]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")"
    [ "$existing_id" = "local.codex-usage.Quota" ] ||
        { printf 'Refusing to replace an unrelated application.\n' >&2; exit 1; }
    if pgrep -x Quota >/dev/null; then
        printf 'Quit all Quota instances before replacing the application.\n' >&2
        exit 1
    fi
    backup="$work/previous.app"
    mv "$app" "$backup"
    if ! mv "$source_app" "$app"; then
        mv "$backup" "$app"
        exit 1
    fi
else
    mv "$source_app" "$app"
fi
printf '\nInstalled %s\n' "$app"
printf 'Launch: open "%s"\n' "$app"
printf 'This community build is ad-hoc signed, not Apple-notarized. If blocked, use System Settings > Privacy & Security > Open Anyway after reviewing the source.\n'
