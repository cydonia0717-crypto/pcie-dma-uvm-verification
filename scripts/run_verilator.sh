#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT=${PCIE_DUT:-"$ROOT/third_party/verilog-pcie"}
UVM_HOME=${UVM_HOME:-"$ROOT/third_party/uvm/src"}
TEST=${TEST:-dma_smoke_test}
SEED=${SEED:-1}
BUILD_OUT=${BUILD_OUT:-"$ROOT/out/verilator/build"}
OUT=${OUT:-"$ROOT/out/verilator/runs/$TEST.$SEED"}
FORCE_REBUILD=${FORCE_REBUILD:-0}
VERILATOR_IMAGE=${VERILATOR_IMAGE:-"verilator/verilator@sha256:a5b73e2fce0b2c483396f3800940f33b6faa802331a061c21694dd27b7352120"}

command -v docker >/dev/null || { echo "docker required for reproducible OSS run" >&2; exit 2; }
[ -f "$DUT/rtl/dma_if_pcie.v" ] || { echo "run scripts/bootstrap_oss.sh first" >&2; exit 2; }
[ -f "$UVM_HOME/uvm_pkg.sv" ] || { echo "UVM_HOME invalid: $UVM_HOME" >&2; exit 2; }

mkdir -p "$BUILD_OUT" "$OUT"

if [ "$FORCE_REBUILD" = "1" ] || [ ! -x "$BUILD_OUT/obj_dir/simv" ]; then
  echo "[compile] building shared Verilator/UVM image in $BUILD_OUT"
  cd "$BUILD_OUT"
  rm -rf obj_dir
  docker run --rm -e CCACHE_DISABLE=1 -v "$ROOT:$ROOT" -w "$BUILD_OUT" --user "$(id -u):$(id -g)" "$VERILATOR_IMAGE" \
    --binary --timing --assert --coverage -j 2 --top-module tb_top --Mdir obj_dir -o simv \
    -Wno-fatal -Wno-lint -Wno-style +define+UVM_NO_DPI \
    "+incdir+$UVM_HOME" "+incdir+$ROOT/tb" "+incdir+$ROOT/tb/agents/desc" "+incdir+$ROOT/tb/agents/pcie" "+incdir+$ROOT/tb/agents/ram" "+incdir+$ROOT/tb/scoreboard" "+incdir+$ROOT/tb/coverage" "+incdir+$ROOT/tb/env" "+incdir+$ROOT/tb/seq" "+incdir+$ROOT/tb/tests" \
    "$UVM_HOME/uvm_pkg.sv" "$DUT/rtl/dma_if_pcie_rd.v" "$DUT/rtl/dma_if_pcie_wr.v" "$DUT/rtl/dma_if_pcie.v" \
    "$ROOT/tb/if/dma_desc_if.sv" "$ROOT/tb/if/pcie_tlp_if.sv" "$ROOT/tb/if/dma_ram_if.sv" "$ROOT/tb/if/dma_cfg_if.sv" \
    "$ROOT/tb/assertions/dma_assertions.sv" "$ROOT/tb/dma_uvm_pkg.sv" "$ROOT/tb/tb_top.sv" 2>&1 | tee compile.log
else
  echo "[compile] reusing $BUILD_OUT/obj_dir/simv"
fi

cd "$OUT"
echo "[run] TEST=$TEST SEED=$SEED"
"$BUILD_OUT/obj_dir/simv" +UVM_TESTNAME="$TEST" +verilator+seed+"$SEED" 2>&1 | tee run.log

if grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' run.log; then
  echo "[FAIL] UVM reported one or more errors/fatals"
  grep -E 'UVM_(ERROR|FATAL)[[:space:]]*:' run.log | tail -n 4 || true
  exit 1
fi
