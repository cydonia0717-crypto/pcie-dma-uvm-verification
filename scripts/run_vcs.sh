#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT=${PCIE_DUT:-"$ROOT/third_party/verilog-pcie"}
TEST=${TEST:-dma_smoke_test}
SEED=${SEED:-1}
BUILD_OUT=${BUILD_OUT:-"$ROOT/out/vcs/build"}
OUT=${OUT:-"$ROOT/out/vcs/runs/$TEST.$SEED"}
FORCE_REBUILD=${FORCE_REBUILD:-0}

command -v vcs >/dev/null || { echo "VCS not found in PATH" >&2; exit 2; }
[ -f "$DUT/rtl/dma_if_pcie.v" ] || { echo "run scripts/setup_dut.sh first" >&2; exit 2; }

mkdir -p "$BUILD_OUT" "$OUT"

incs=(
  "+incdir+$ROOT/tb"
  "+incdir+$ROOT/tb/agents/desc"
  "+incdir+$ROOT/tb/agents/pcie"
  "+incdir+$ROOT/tb/agents/ram"
  "+incdir+$ROOT/tb/scoreboard"
  "+incdir+$ROOT/tb/coverage"
  "+incdir+$ROOT/tb/env"
  "+incdir+$ROOT/tb/seq"
  "+incdir+$ROOT/tb/tests"
)

if [ "$FORCE_REBUILD" = 1 ] || [ ! -x "$BUILD_OUT/simv" ]; then
  cd "$BUILD_OUT"
  vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -debug_access+all -kdb -cm line+cond+tgl+branch \
    "${incs[@]}" \
    "$DUT/rtl/dma_if_pcie_rd.v" "$DUT/rtl/dma_if_pcie_wr.v" "$DUT/rtl/dma_if_pcie.v" \
    "$ROOT/tb/if/dma_desc_if.sv" "$ROOT/tb/if/pcie_tlp_if.sv" \
    "$ROOT/tb/if/dma_ram_if.sv" "$ROOT/tb/if/dma_cfg_if.sv" \
    "$ROOT/tb/assertions/dma_assertions.sv" "$ROOT/tb/dma_uvm_pkg.sv" "$ROOT/tb/tb_top.sv" \
    -o simv 2>&1 | tee compile.log
fi

cd "$OUT"
"$BUILD_OUT/simv" +UVM_TESTNAME="$TEST" +ntb_random_seed="$SEED" \
  -cm line+cond+tgl+branch -cm_dir "$OUT/test.vdb" 2>&1 | tee run.log

if grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' run.log; then
  echo "[FAIL] UVM reported errors/fatals" >&2
  exit 1
fi
