#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT=${PCIE_DUT:-"$ROOT/third_party/verilog-pcie"}
UVM_HOME=${UVM_HOME:-"$ROOT/third_party/uvm/src"}
TEST=${TEST:-dma_smoke_test}; SEED=${SEED:-1}; OUT=${OUT:-"$ROOT/out/verilator/$TEST.$SEED"}
command -v docker >/dev/null || { echo "docker required for reproducible OSS run" >&2; exit 2; }
[ -f "$DUT/rtl/dma_if_pcie.v" ] || { echo "run scripts/bootstrap_oss.sh first" >&2; exit 2; }
mkdir -p "$OUT"; cd "$OUT"
docker run --rm -e CCACHE_DISABLE=1 -v "$ROOT:$ROOT" -w "$OUT" --user "$(id -u):$(id -g)" verilator/verilator:latest \
  --binary --timing --assert --coverage -j 2 --top-module tb_top --Mdir obj_dir -o simv \
  -Wno-fatal -Wno-lint -Wno-style +define+UVM_NO_DPI \
  "+incdir+$UVM_HOME" "+incdir+$ROOT/tb" "+incdir+$ROOT/tb/agents/desc" "+incdir+$ROOT/tb/agents/pcie" "+incdir+$ROOT/tb/agents/ram" "+incdir+$ROOT/tb/scoreboard" "+incdir+$ROOT/tb/coverage" "+incdir+$ROOT/tb/env" "+incdir+$ROOT/tb/seq" "+incdir+$ROOT/tb/tests" \
  "$UVM_HOME/uvm_pkg.sv" "$DUT/rtl/dma_if_pcie_rd.v" "$DUT/rtl/dma_if_pcie_wr.v" "$DUT/rtl/dma_if_pcie.v" \
  "$ROOT/tb/if/dma_desc_if.sv" "$ROOT/tb/if/pcie_tlp_if.sv" "$ROOT/tb/if/dma_ram_if.sv" "$ROOT/tb/if/dma_cfg_if.sv" \
  "$ROOT/tb/assertions/dma_assertions.sv" "$ROOT/tb/dma_uvm_pkg.sv" "$ROOT/tb/tb_top.sv" 2>&1 | tee compile.log
./obj_dir/simv +UVM_TESTNAME="$TEST" +verilator+seed+"$SEED" 2>&1 | tee run.log
if grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9][0-9]*' run.log; then exit 1; fi
