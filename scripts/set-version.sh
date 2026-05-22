#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf "usage: %s <version>\n" "$0" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"

for plist in \
  "$ROOT/resources/FakendBrowser/Info.plist" \
  "$ROOT/resources/FakendBrowserHelper/Info.plist"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$plist"
done

printf "Set bundle version to %s\n" "$VERSION"

