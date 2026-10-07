#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT=${PCIE_DUT:-"$ROOT/third_party/verilog-pcie"}
SHA=25156a9a162c41c60f11f41590c7d006d015ae5a
PATCH="$ROOT/patches/0001-fix-read-count-width-overflow.patch"
OUT="$ROOT/out/verilator/repro_upstream_maxlen_bug"
BUILD="$ROOT/out/verilator/repro-upstream-build"

[ -d "$DUT/.git" ] || { echo "DUT not bootstrapped" >&2; exit 2; }

echo "[repro] restoring pristine upstream $SHA"
git -C "$DUT" reset --hard "$SHA"

rm -rf "$OUT" "$BUILD"
set +e
FORCE_REBUILD=1 BUILD_OUT="$BUILD" OUT="$OUT" TEST=dma_max_len_test SEED=108 \
  bash "$ROOT/scripts/run_verilator.sh"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "[FAIL] pristine upstream unexpectedly passed the max-length unaligned H2C test"
  git -C "$DUT" apply "$PATCH" || true
  exit 1
fi

if ! grep -q 'MRRS violation len_field=0' "$OUT/run.log"; then
  echo "[FAIL] upstream run failed, but not with the expected read-length overflow signature"
  tail -n 80 "$OUT/run.log" || true
  git -C "$DUT" apply "$PATCH" || true
  exit 1
fi

echo "[PASS] reproduced upstream read-segmentation width overflow:"
grep 'MRRS violation len_field=0' "$OUT/run.log" | tail -n 1

# Restore the qualification DUT state for any following step/local use.
git -C "$DUT" apply "$PATCH"
