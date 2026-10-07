#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN_ROOT="$ROOT/out/verilator/runs"
OUT="$ROOT/out/verilator/coverage"
IMAGE=${VERILATOR_IMAGE:-"verilator/verilator@sha256:a5b73e2fce0b2c483396f3800940f33b6faa802331a061c21694dd27b7352120"}

mkdir -p "$OUT"
mapfile -t COVS < <(find "$RUN_ROOT" -mindepth 2 -maxdepth 2 -name coverage.dat -type f | sort)
if [ "${#COVS[@]}" -eq 0 ]; then
  echo "no coverage.dat files found under $RUN_ROOT" >&2
  exit 2
fi

echo "[coverage] merging ${#COVS[@]} normal regression databases"
docker run --rm -v "$ROOT:$ROOT" -w "$ROOT" --user "$(id -u):$(id -g)" "$IMAGE" \
  verilator_coverage --write "$OUT/merged.dat" "${COVS[@]}"
docker run --rm -v "$ROOT:$ROOT" -w "$ROOT" --user "$(id -u):$(id -g)" "$IMAGE" \
  verilator_coverage --write-info "$OUT/coverage.info" "$OUT/merged.dat"

python3 "$ROOT/scripts/parse_lcov.py" "$OUT/coverage.info"
