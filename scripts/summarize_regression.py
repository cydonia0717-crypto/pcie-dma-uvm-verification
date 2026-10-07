#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RUN_ROOT = ROOT / "out" / "verilator" / "runs"
OUT_DIR = ROOT / "out" / "verilator" / "qualification"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SB_RE = re.compile(
    r"checks=(?P<checks>\d+) errors=(?P<errors>\d+) "
    r"memrd=(?P<memrd>\d+) memwr=(?P<memwr>\d+) cpld=(?P<cpld>\d+) "
    r"max_pcie_outstanding=(?P<max_pcie>\d+) split_reads=(?P<split_reads>\d+) "
    r"max_desc_outstanding=(?P<max_desc>\d+) max_h2c_desc=(?P<max_h2c>\d+) "
    r"max_c2h_desc=(?P<max_c2h>\d+) max_memrd_tlp=(?P<max_memrd>\d+) "
    r"max_memwr_tlp=(?P<max_memwr>\d+) ram_rd_cmds=(?P<ram_rd>\d+) "
    r"ram_wr_cmds=(?P<ram_wr>\d+) ram_wr_bytes=(?P<ram_wr_bytes>\d+)"
)

def last_int(text: str, key: str) -> int:
    vals = re.findall(rf"{key}\s*:\s*(\d+)", text)
    return int(vals[-1]) if vals else -1

runs = []
for log in sorted(RUN_ROOT.glob("*/run.log")):
    text = log.read_text(errors="replace")
    m = list(SB_RE.finditer(text))
    if not m:
        print(f"missing scoreboard summary: {log}", file=sys.stderr)
        sys.exit(1)
    d = {k: int(v) for k, v in m[-1].groupdict().items()}
    d["run"] = log.parent.name
    d["uvm_error"] = last_int(text, "UVM_ERROR")
    d["uvm_fatal"] = last_int(text, "UVM_FATAL")
    d["saw_16tag"] = "scoreboard observed 16 simultaneous PCIe Memory Read tags" in text
    d["saw_ooo"] = bool(re.search(r"cross_tag_ooo=[1-9]\d*", text))
    d["saw_maxlen"] = "65535-byte H2C and C2H descriptors completed cleanly" in text
    d["saw_cpl_error"] = "Unsupported Request completion propagated as DMA error 0xA" in text
    d["saw_1m_chain"] = "1MiB H2C logical DMA completed through 17 descriptors with 16 PCIe tags in flight" in text
    d["saw_zero_len"] = "zero-length H2C/C2H completed with destination sentinels preserved" in text
    runs.append(d)

if not runs:
    print("no regression run logs found", file=sys.stderr)
    sys.exit(1)

bad = [r["run"] for r in runs if r["uvm_error"] != 0 or r["uvm_fatal"] != 0 or r["errors"] != 0]
if bad:
    print("qualification failed; error-bearing runs: " + ", ".join(bad), file=sys.stderr)
    sys.exit(1)

totals = {
    "run_count": len(runs),
    "checks": sum(r["checks"] for r in runs),
    "memrd": sum(r["memrd"] for r in runs),
    "memwr": sum(r["memwr"] for r in runs),
    "cpld": sum(r["cpld"] for r in runs),
    "split_reads": sum(r["split_reads"] for r in runs),
    "ram_wr_bytes": sum(r["ram_wr_bytes"] for r in runs),
    "max_pcie_outstanding": max(r["max_pcie"] for r in runs),
    "max_desc_outstanding": max(r["max_desc"] for r in runs),
    "max_memrd_tlp": max(r["max_memrd"] for r in runs),
    "max_memwr_tlp": max(r["max_memwr"] for r in runs),
    "saw_16tag": any(r["saw_16tag"] for r in runs),
    "saw_ooo": any(r["saw_ooo"] for r in runs),
    "saw_maxlen": any(r["saw_maxlen"] for r in runs),
    "saw_cpl_error": any(r["saw_cpl_error"] for r in runs),
    "saw_1m_chain": any(r["saw_1m_chain"] for r in runs),
    "saw_zero_len": any(r["saw_zero_len"] for r in runs),
}

requirements = {
    "all_runs_clean": not bad,
    "sixteen_simultaneous_tags": totals["max_pcie_outstanding"] >= 16 and totals["saw_16tag"],
    "cross_tag_ooo_observed": totals["saw_ooo"],
    "max_length_boundary_passed": totals["saw_maxlen"],
    "completion_error_propagation": totals["saw_cpl_error"],
    "one_mib_chained_h2c": totals["saw_1m_chain"],
    "zero_length_semantics": totals["saw_zero_len"],
    "mrrs_512_observed": totals["max_memrd_tlp"] == 512,
    "mps_256_observed": totals["max_memwr_tlp"] == 256,
}
if not all(requirements.values()):
    print("qualification requirement missing: " + ", ".join(k for k,v in requirements.items() if not v), file=sys.stderr)
    sys.exit(1)

payload = {"totals": totals, "requirements": requirements, "runs": runs}
(OUT_DIR / "regression_summary.json").write_text(json.dumps(payload, indent=2) + "\n")

md = [
    "# PCIe DMA Regression Summary",
    "",
    "Generated automatically from the UVM run logs in this qualification.",
    "",
    f"- Clean simulation runs: **{totals['run_count']}**",
    f"- Completed descriptor checks: **{totals['checks']}**",
    f"- Memory Read TLPs observed: **{totals['memrd']}**",
    f"- Memory Write TLPs observed: **{totals['memwr']}**",
    f"- Completion-with-Data packets driven: **{totals['cpld']}**",
    f"- Read requests split into multiple completions: **{totals['split_reads']}**",
    f"- Peak simultaneous PCIe Memory Read tags: **{totals['max_pcie_outstanding']}**",
    f"- Peak simultaneous DMA descriptors: **{totals['max_desc_outstanding']}**",
    f"- Largest Memory Read request: **{totals['max_memrd_tlp']} B**",
    f"- Largest Memory Write request: **{totals['max_memwr_tlp']} B**",
    f"- Device-RAM bytes written by H2C traffic: **{totals['ram_wr_bytes']}**",
    "- UVM errors/fatals: **0 / 0 in every normal regression run**",
    "",
    "## Qualification gates",
    "",
]
for k,v in requirements.items():
    md.append(f"- {'PASS' if v else 'FAIL'} — {k}")
md += ["", "## Per-run evidence", "",
       "| run | checks | MemRd | MemWr | CplD | max PCIe tags | max desc | split reads |",
       "|---|---:|---:|---:|---:|---:|---:|---:|"]
for r in runs:
    md.append(f"| {r['run']} | {r['checks']} | {r['memrd']} | {r['memwr']} | {r['cpld']} | {r['max_pcie']} | {r['max_desc']} | {r['split_reads']} |")
(OUT_DIR / "regression_summary.md").write_text("\n".join(md) + "\n")
print("\n".join(md[:20]))
