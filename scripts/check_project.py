#!/usr/bin/env python3
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[1]
required=['README.md','tb/dma_uvm_pkg.sv','tb/tb_top.sv','tb/if/dma_desc_if.sv','tb/if/pcie_tlp_if.sv','tb/if/dma_ram_if.sv','tb/scoreboard/dma_scoreboard.sv','scripts/setup_dut.sh','scripts/run_verilator.sh','docs/Verification_Plan.md']
miss=[p for p in required if not (root/p).exists()]
if miss: print('Missing:',*miss,sep='\n  '); sys.exit(1)
pkg=(root/'tb/dma_uvm_pkg.sv').read_text()
for inc in re.findall(r'`include\s+"([^"]+)"',pkg):
    if inc!='uvm_macros.svh' and not (root/'tb'/inc).exists(): print('Broken include',inc); sys.exit(1)
for p in root.rglob('*.sv'):
    t=re.sub(r'//.*?$|/\*.*?\*/','',p.read_text(),flags=re.M|re.S)
    for a,b in [('class','endclass'),('module','endmodule'),('interface','endinterface'),('package','endpackage')]:
        if len(re.findall(rf'\b{a}\b',t))!=len(re.findall(rf'\b{b}\b',t)): print('Unbalanced',a,p); sys.exit(1)
print('PCIe DMA project static checks: PASS')
