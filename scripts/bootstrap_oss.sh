#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
UVM="$ROOT/third_party/uvm"
UVM_COMMIT=656f20d087370a7c742e00188d20bbf30fa95339
bash "$ROOT/scripts/setup_dut.sh"
if [ ! -d "$UVM/.git" ]; then git clone https://github.com/verilator/uvm.git "$UVM"; fi
git -C "$UVM" fetch --depth 1 origin "$UVM_COMMIT"
git -C "$UVM" checkout --detach "$UVM_COMMIT"
cat > "$ROOT/.env.oss" <<ENV
export UVM_HOME="$UVM/src"
export PCIE_DUT="$ROOT/third_party/verilog-pcie"
ENV
echo "OSS dependencies ready; source .env.oss"
