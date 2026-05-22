#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
CEF_ROOT="${CEF_ROOT:-$ROOT/vendor/cef/current}"

if [[ ! -d "$CEF_ROOT" ]]; then
  printf "CEF_ROOT is missing at %s. Run scripts/fetch-cef.sh first.\n" "$CEF_ROOT" >&2
  exit 1
fi

cmake \
  -S "$ROOT" \
  -B "$BUILD_DIR" \
  -G Ninja \
  -DCEF_ROOT="$CEF_ROOT" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

