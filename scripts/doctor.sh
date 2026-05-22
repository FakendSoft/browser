#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check() {
  local name="$1"
  shift

  if "$@" >/tmp/fakend-browser-doctor.out 2>/tmp/fakend-browser-doctor.err; then
    printf "ok   %s\n" "$name"
  else
    printf "fail %s\n" "$name"
    sed 's/^/     /' /tmp/fakend-browser-doctor.err
    return 1
  fi
}

warn() {
  local name="$1"
  shift

  if "$@" >/tmp/fakend-browser-doctor.out 2>/tmp/fakend-browser-doctor.err; then
    printf "ok   %s\n" "$name"
  else
    printf "warn %s\n" "$name"
    sed 's/^/     /' /tmp/fakend-browser-doctor.err
  fi
}

check "cmake" cmake --version
check "ninja" ninja --version
check "jq" jq --version
check "python3" python3 --version
warn "xcodebuild" xcodebuild -version

if [[ -d "$ROOT/vendor/cef/current" ]]; then
  printf "ok   CEF distribution: %s\n" "$(cd "$ROOT/vendor/cef/current" && pwd)"
else
  printf "warn CEF distribution missing; run scripts/fetch-cef.sh\n"
fi

