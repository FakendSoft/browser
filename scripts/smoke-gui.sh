#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE="$ROOT/build/Fakend Browser.app/Contents/MacOS/Fakend Browser"
PROFILE_DIR="${PROFILE_DIR:-$(mktemp -d /private/tmp/fakend-browser-smoke.XXXXXX)}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  printf "App executable missing at %s. Run scripts/build.sh first.\n" "$APP_EXECUTABLE" >&2
  exit 1
fi

FAKEND_BROWSER_USER_DATA_DIR="$PROFILE_DIR" "$APP_EXECUTABLE" &
app_pid=$!

tab_found=0
for ((second = 1; second <= WAIT_SECONDS; second += 1)); do
  sleep 1
  tab_dirs="$(find "$PROFILE_DIR/CEF" -maxdepth 1 -type d -name 'Tab-*' 2>/dev/null || true)"
  if [[ -n "$tab_dirs" ]]; then
    printf "tabs_ready_at=%ss\n" "$second"
    printf "%s\n" "$tab_dirs"
    tab_found=1
    break
  fi
done

osascript -e 'tell application id "com.fakend.browser" to quit' >/dev/null 2>&1 || true
sleep 2
kill -TERM "$app_pid" 2>/dev/null || true
wait "$app_pid" 2>/dev/null || true

printf "profile_dir=%s\n" "$PROFILE_DIR"

if [[ "$tab_found" != "1" ]]; then
  printf "No tab profile was created within %s seconds.\n" "$WAIT_SECONDS" >&2
  exit 1
fi

