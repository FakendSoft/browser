#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT/build/Fakend Browser.app}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
VERSION="${VERSION:-}"

if [[ ! -d "$APP_PATH" ]]; then
  printf "App bundle missing at %s. Run scripts/build.sh first.\n" "$APP_PATH" >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
fi

mkdir -p "$DIST_DIR"

staging="$(mktemp -d /private/tmp/fakend-browser-dmg.XXXXXX)"
trap 'rm -rf "$staging"' EXIT

cp -R "$APP_PATH" "$staging/Fakend Browser.app"
ln -s /Applications "$staging/Applications"

dmg_path="$DIST_DIR/Fakend-Browser-${VERSION}-macos-arm64.dmg"
rm -f "$dmg_path" "$dmg_path.sha256"

hdiutil create \
  -volname "Fakend Browser ${VERSION}" \
  -srcfolder "$staging" \
  -ov \
  -format UDZO \
  "$dmg_path"

shasum -a 256 "$dmg_path" > "$dmg_path.sha256"

printf "dmg_path=%s\n" "$dmg_path"
printf "sha256_path=%s\n" "$dmg_path.sha256"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf "dmg_path=%s\n" "$dmg_path"
    printf "sha256_path=%s\n" "$dmg_path.sha256"
  } >> "$GITHUB_OUTPUT"
fi

