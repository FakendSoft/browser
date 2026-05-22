#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE="$ROOT/build/Fakend Browser.app/Contents/MacOS/Fakend Browser"
PROFILE_DIR="${PROFILE_DIR:-$(mktemp -d /private/tmp/fakend-browser-smoke.XXXXXX)}"
WAIT_SECONDS="${WAIT_SECONDS:-30}"
EXPECTED_TAB_COUNT="${EXPECTED_TAB_COUNT:-2}"
INITIAL_TAB_COUNT="${INITIAL_TAB_COUNT:-$EXPECTED_TAB_COUNT}"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  printf "App executable missing at %s. Run scripts/build.sh first.\n" "$APP_EXECUTABLE" >&2
  exit 1
fi

FAKEND_BROWSER_INITIAL_TAB_COUNT="$INITIAL_TAB_COUNT" FAKEND_BROWSER_USER_DATA_DIR="$PROFILE_DIR" "$APP_EXECUTABLE" &
app_pid=$!

tabs_found=0
helper_found=0
renderer_found=0
page_loaded=0
for ((second = 1; second <= WAIT_SECONDS; second += 1)); do
  sleep 1
  tab_dirs="$(find "$PROFILE_DIR/CEF" -maxdepth 1 -type d -name 'Tab-*' 2>/dev/null | sort || true)"
  tab_count=0
  if [[ -n "$tab_dirs" ]]; then
    tab_count="$(printf "%s\n" "$tab_dirs" | wc -l | tr -d ' ')"
  fi
  if (( tab_count >= EXPECTED_TAB_COUNT )); then
    printf "tabs_ready_at=%ss\n" "$second"
    printf "expected_tab_count=%s\n" "$EXPECTED_TAB_COUNT"
    printf "actual_tab_count=%s\n" "$tab_count"
    printf "%s\n" "$tab_dirs"
    tabs_found=1
    break
  fi
done

helper_processes="$(ps -axo comm= | grep 'Fakend Browser Helper' || true)"
if [[ -n "$helper_processes" ]]; then
  helper_found=1
  printf "helper_processes=present\n"
else
  printf "helper_processes=missing\n" >&2
fi

renderer_processes="$(ps -axo args= | grep 'Fakend Browser Helper (Renderer)' | grep -- '--type=renderer' | grep -v grep || true)"
if [[ -n "$renderer_processes" ]]; then
  renderer_found=1
  printf "renderer_processes=present\n"
else
  printf "renderer_processes=missing\n" >&2
fi

for ((second = 1; second <= WAIT_SECONDS; second += 1)); do
  if curl --max-time 2 -fsS http://127.0.0.1:9222/json 2>/dev/null | grep -q '"title": "Example Domain"'; then
    page_loaded=1
    printf "page_loaded_at=%ss\n" "$second"
    break
  fi
  sleep 1
done

osascript -e 'tell application id "com.fakend.browser" to quit' >/dev/null 2>&1 || true
sleep 2
kill -TERM "$app_pid" 2>/dev/null || true
wait "$app_pid" 2>/dev/null || true

printf "profile_dir=%s\n" "$PROFILE_DIR"

if [[ "$tabs_found" != "1" ]]; then
  printf "Expected %s tab profiles within %s seconds.\n" "$EXPECTED_TAB_COUNT" "$WAIT_SECONDS" >&2
  exit 1
fi

if [[ "$helper_found" != "1" ]]; then
  printf "No CEF helper process was observed.\n" >&2
  exit 1
fi

if [[ "$renderer_found" != "1" ]]; then
  printf "No CEF renderer process was observed.\n" >&2
  exit 1
fi

if [[ "$page_loaded" != "1" ]]; then
  printf "Expected the initial page to load in DevTools within %s seconds.\n" "$WAIT_SECONDS" >&2
  exit 1
fi
