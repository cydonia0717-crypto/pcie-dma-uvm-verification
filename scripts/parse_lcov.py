#!/usr/bin/env python3
from pathlib import Path
import json
import sys

if len(sys.argv) not in (2,3):
    raise SystemExit("usage: parse_lcov.py <line.info> [branch.info]")

line_info = Path(sys.argv[1])
branch_info = Path(sys.argv[2]) if len(sys.argv) == 3 else line_info

def parse(path: Path):
    if not path.exists():
        raise SystemExit(f"coverage file not found: {path}")
    files = {}
    cur = None
    for raw in path.read_text(errors="replace").splitlines():
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
    return files

def dut_only(files):
    return {
        k:v for k,v in files.items()
        if "/third_party/verilog-pcie/rtl/dma_if_pcie" in k and k.endswith(".v")
    }

lf = dut_only(parse(line_info))
bf = dut_only(parse(branch_info))
if not lf:
    print("No dma_if_pcie RTL records found in line LCOV output", file=sys.stderr)
    sys.exit(1)

line_total = sum(len(v["lines"]) for v in lf.values())
line_hit = sum(sum(1 for c in v["lines"].values() if c > 0) for v in lf.values())
branch_total = sum(len(v["branches"]) for v in bf.values())
branch_hit = sum(sum(1 for x in v["branches"] if x) for v in bf.values())

def pct(hit,total):
    return 100.0*hit/total if total else None

out = {
    "scope": sorted(lf),
    "line_hit": line_hit,
    "line_total": line_total,
    "line_pct": pct(line_hit,line_total),
    "branch_hit": branch_hit,
    "branch_total": branch_total,
    "branch_pct": pct(branch_hit,branch_total),
}
p = line_info.parent / "dut_coverage_summary.json"
p.write_text(json.dumps(out, indent=2) + "\n")

print(f"DUT line coverage: {line_hit}/{line_total} = {out['line_pct']:.1f}%")
if branch_total:
    print(f"DUT branch coverage: {branch_hit}/{branch_total} = {out['branch_pct']:.1f}%")
else:
    print("DUT branch coverage: branch records not emitted by LCOV backend")
