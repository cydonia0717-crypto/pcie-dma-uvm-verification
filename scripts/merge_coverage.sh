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

cov() {
  docker run --rm --entrypoint verilator_coverage \
    -v "$ROOT:$ROOT" -w "$ROOT" --user "$(id -u):$(id -g)" "$IMAGE" "$@"
}

echo "[coverage] merging ${#COVS[@]} normal regression databases"
cov --write "$OUT/merged.dat" "${COVS[@]}"

# Keep code-coverage types separate.  A generic --write-info is lossy because
# it collapses line/branch/expression/toggle points onto source lines.
cov --filter-type line --write-info "$OUT/line.info" "$OUT/merged.dat"
cov --filter-type branch --write-info "$OUT/branch.info" "$OUT/merged.dat"
cov --filter-type covergroup --report summary "$OUT/merged.dat" | tee "$OUT/functional_coverage.txt"

python3 "$ROOT/scripts/parse_lcov.py" "$OUT/line.info" "$OUT/branch.info"
python3 "$ROOT/scripts/parse_covergroup.py" "$OUT/merged.dat"
