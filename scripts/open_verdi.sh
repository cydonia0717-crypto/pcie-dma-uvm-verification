#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_OUT=${BUILD_OUT:-"$ROOT/out/vcs/build"}

command -v verdi >/dev/null || { echo "Verdi not found in PATH" >&2; exit 2; }
[ -d "$BUILD_OUT/simv.daidir" ] || {
  echo "VCS debug database not found at $BUILD_OUT/simv.daidir" >&2
  echo "Run: make vcs-smoke" >&2
  exit 2
}

exec verdi -dbdir "$BUILD_OUT/simv.daidir"
