#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export BUILD_OUT=${BUILD_OUT:-"$ROOT/out/verilator/build"}

tests=(
  "dma_smoke_test 1"
  "dma_4k_split_test 2"
  "dma_16tag_test 3"
  "dma_small_unaligned_test 4"
  "dma_limits_test 5"
  "dma_split_ooo_test 6"
  "dma_backpressure_test 7"
  "dma_max_len_test 8"
  "dma_completion_error_test 9"
  "dma_completion_matrix_test 16"
  "dma_zero_len_test 12"
  "dma_reset_recovery_test 13"
  "dma_enable_gating_test 14"
  "dma_multibeat_cpl_test 15"
  "dma_1m_chain_test 10"
  "dma_random_stress_test 11"
  "dma_random_stress_test 29"
  "dma_random_stress_test 47"
)

first=1
for item in "${tests[@]}"; do
  read -r test seed <<<"$item"
  if [ "$first" = 1 ]; then
    FORCE_REBUILD=1 TEST="$test" SEED="$seed" bash "$ROOT/scripts/run_verilator.sh"
    first=0
  else
    TEST="$test" SEED="$seed" bash "$ROOT/scripts/run_verilator.sh"
  fi
done

python3 "$ROOT/scripts/summarize_regression.py"
bash "$ROOT/scripts/merge_coverage.sh"
