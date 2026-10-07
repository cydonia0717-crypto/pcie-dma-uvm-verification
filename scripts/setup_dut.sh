#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DUT="$ROOT/third_party/verilog-pcie"
SHA=25156a9a162c41c60f11f41590c7d006d015ae5a
PATCH="$ROOT/patches/0001-fix-read-count-width-overflow.patch"

mkdir -p "$ROOT/third_party"
if [ ! -d "$DUT/.git" ]; then
  git clone https://github.com/alexforencich/verilog-pcie.git "$DUT"
fi

git -C "$DUT" fetch --depth 1 origin "$SHA"
git -C "$DUT" checkout --detach "$SHA"
# Always restore the pinned upstream tree before applying local verification
# fixes so repeated CI/local bootstrap is deterministic.
git -C "$DUT" reset --hard "$SHA"

if [ "${APPLY_LOCAL_PATCHES:-1}" = "1" ]; then
  git -C "$DUT" apply --check "$PATCH"
  git -C "$DUT" apply "$PATCH"
  echo "applied local fix: $(basename "$PATCH")"
else
  echo "local DUT patches disabled; using pristine upstream RTL"
fi

echo "verilog-pcie pinned at $(git -C "$DUT" rev-parse HEAD)"
