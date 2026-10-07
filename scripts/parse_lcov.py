#!/usr/bin/env python3
from pathlib import Path
import json
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: parse_lcov.py <coverage.info>")

info = Path(sys.argv[1])
if not info.exists():
    raise SystemExit(f"coverage file not found: {info}")

files = {}
cur = None
for raw in info.read_text(errors="replace").splitlines():
    if raw.startswith("SF:"):
        cur = raw[3:]
        files[cur] = {"lines": {}, "branches": []}
    elif cur is not None and raw.startswith("DA:"):
        a = raw[3:].split(",")
        if len(a) >= 2:
            files[cur]["lines"][int(a[0])] = int(a[1])
    elif cur is not None and raw.startswith("BRDA:"):
        a = raw[5:].split(",")
        if len(a) >= 4:
            files[cur]["branches"].append(a[3] not in ("-", "0"))
    elif raw == "end_of_record":
        cur = None

dut = {k:v for k,v in files.items() if "/third_party/verilog-pcie/rtl/dma_if_pcie" in k and k.endswith(".v")}
if not dut:
    print("No dma_if_pcie RTL records found in LCOV output", file=sys.stderr)
    sys.exit(1)

line_total = sum(len(v["lines"]) for v in dut.values())
line_hit = sum(sum(1 for c in v["lines"].values() if c > 0) for v in dut.values())
branch_total = sum(len(v["branches"]) for v in dut.values())
branch_hit = sum(sum(1 for x in v["branches"] if x) for v in dut.values())

def pct(hit,total):
    return 100.0*hit/total if total else None

out = {
    "scope": sorted(dut),
    "line_hit": line_hit,
    "line_total": line_total,
    "line_pct": pct(line_hit,line_total),
    "branch_hit": branch_hit,
    "branch_total": branch_total,
    "branch_pct": pct(branch_hit,branch_total),
}
p = info.parent / "dut_coverage_summary.json"
p.write_text(json.dumps(out, indent=2) + "\n")

print(f"DUT line coverage: {line_hit}/{line_total} = {out['line_pct']:.1f}%")
if branch_total:
    print(f"DUT branch coverage: {branch_hit}/{branch_total} = {out['branch_pct']:.1f}%")
else:
    print("DUT branch coverage: not emitted by this Verilator LCOV backend")
