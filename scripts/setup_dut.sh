#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT="$ROOT/third_party/verilog-pcie"
SHA=25156a9a162c41c60f11f41590c7d006d015ae5a
mkdir -p "$ROOT/third_party"
if [ ! -d "$DUT/.git" ]; then git clone https://github.com/alexforencich/verilog-pcie.git "$DUT"; fi
git -C "$DUT" fetch --depth 1 origin "$SHA"
git -C "$DUT" checkout --detach "$SHA"
echo "verilog-pcie pinned at $(git -C "$DUT" rev-parse HEAD)"
