#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export BUILD_OUT=${BUILD_OUT:-"$ROOT/out/vcs/build"}

tests=(
  "dma_smoke_test 1"
  "dma_4k_split_test 2"
  "dma_16tag_test 3"
  "dma_small_unaligned_test 4"
  "dma_limits_test 5"
  "dma_split_ooo_test 6"
  "dma_backpressure_test 7"
  "dma_max_len_test 8"
  "dma_random_stress_test 11"
  "dma_random_stress_test 29"
  "dma_random_stress_test 47"
)

first=1
for item in "${tests[@]}"; do
  read -r test seed <<<"$item"
  if [ "$first" = 1 ]; then
    FORCE_REBUILD=1 TEST="$test" SEED="$seed" bash "$ROOT/scripts/run_vcs.sh"
    first=0
  else
    TEST="$test" SEED="$seed" bash "$ROOT/scripts/run_vcs.sh"
  fi
done

if command -v urg >/dev/null; then
  mapfile -t dbs < <(find "$ROOT/out/vcs/runs" -mindepth 2 -maxdepth 2 -name test.vdb -type d | sort)
  if [ "${#dbs[@]}" -gt 0 ]; then
    mkdir -p "$ROOT/out/vcs"
    urg -full64 -dir "${dbs[@]}" -dbname "$ROOT/out/vcs/merged.vdb" -report "$ROOT/out/vcs/urg"
    echo "URG report: $ROOT/out/vcs/urg/dashboard.html"
  fi
fi
