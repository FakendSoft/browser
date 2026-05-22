#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"

"$ROOT/scripts/configure.sh"
cmake --build "$BUILD_DIR" --target FakendBrowser
"$ROOT/scripts/codesign-dev.sh"
