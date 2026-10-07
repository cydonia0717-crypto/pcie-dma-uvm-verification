#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: parse_covergroup.py <merged.dat>")

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(f"coverage database not found: {path}")

records = []
for raw in path.read_bytes().splitlines():
    line = raw.decode("latin1", errors="replace")
    if "t\x02covergroup" not in line:
        continue
    m_count = re.search(r"'\s+(\d+)\s*$", line)
    m_hash = re.search(r"\x01h\x02([^\x01']+)", line)
    m_bin = re.search(r"\x01bin\x02([^\x01']+)", line)
    if not m_count:
        continue
    count = int(m_count.group(1))
    name = m_hash.group(1) if m_hash else (m_bin.group(1) if m_bin else "unknown")
    bin_type = "normal"
    if "\x01bin_type\x02illegal" in line:
        bin_type = "illegal"
    elif "\x01bin_type\x02ignore" in line:
        bin_type = "ignore"
    records.append({"name": name, "type": bin_type, "count": count})

reachable = [r for r in records if r["type"] == "normal"]
excluded = [r for r in records if r["type"] != "normal"]
covered = [r for r in reachable if r["count"] > 0]
uncovered = [r for r in reachable if r["count"] == 0]

summary = {
    "raw_bins": len(records),
    "reachable_bins": len(reachable),
    "covered_reachable_bins": len(covered),
    "reachable_pct": (100.0 * len(covered) / len(reachable)) if reachable else None,
    "excluded_bins": excluded,
    "uncovered_reachable_bins": uncovered,
}
out_dir = path.parent
(out_dir / "functional_coverage_summary.json").write_text(json.dumps(summary, indent=2) + "\n")

md = [
    "# Functional Coverage Closure",
    "",
    f"- Raw Verilator covergroup bins: **{len(records)}**",
    f"- Reachable/required bins: **{len(reachable)}**",
    f"- Covered reachable bins: **{len(covered)}**",
    f"- Reachable functional coverage: **{summary['reachable_pct']:.1f}% ({len(covered)}/{len(reachable)})**",
    "",
    "## Excluded semantic bins",
    "",
]
for r in excluded:
    md.append(f"- {r['name']} — {r['type']} bin, count={r['count']}")
if not excluded:
    md.append("- none")

md += ["", "## Uncovered reachable bins", ""]
if uncovered:
    for r in uncovered:
        md.append(f"- {r['name']}")
else:
    md.append("- none")

(out_dir / "functional_coverage_summary.md").write_text("\n".join(md) + "\n")

print(f"Reachable functional coverage: {len(covered)}/{len(reachable)} = {summary['reachable_pct']:.1f}%")
for r in excluded:
    print(f"Excluded {r['type']} bin: {r['name']} count={r['count']}")
if uncovered:
    print("Uncovered reachable bins:")
    for r in uncovered:
        print("  " + r["name"])
    sys.exit(1)
