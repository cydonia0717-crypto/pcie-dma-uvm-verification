# PCIe DMA Engine UVM Verification

A portfolio-grade SystemVerilog/UVM verification project around the open-source
Alex Forencich verilog-pcie transaction-layer DMA engine.

## DUT scope

Pinned upstream revision:

- repository: alexforencich/verilog-pcie
- commit: 25156a9a162c41c60f11f41590c7d006d015ae5a
- module: dma_if_pcie
- license: MIT

The verified block is the PCIe transaction-layer DMA engine.  The project does
not claim LTSSM, data-link replay, PHY, BAR/config-space, descriptor-ring, or
MSI/MSI-X verification.

## Fixed qualification configuration

- 256-bit generic TLP datapath
- 64-bit PCIe addresses
- 16 PCIe tags
- 16-entry read operation table
- 16-entry write operation table
- 1 MiB device-side segmented RAM address space
- 8-bit descriptor tag
- MRRS cases: 256 B / 512 B
- MPS cases: 128 B / 256 B
- 4-DW Memory Request format

Direction naming:

- H2C: host memory -> Memory Read TLP -> Completion with Data -> device RAM
- C2H: device RAM -> Memory Write TLP -> host memory

## UVM architecture

- Descriptor Agent drives H2C/C2H descriptors and observes operation status.
- PCIe Host Agent observes Memory Read/Write TLPs, owns a host-memory model,
  injects backpressure, and generates split/out-of-order Completion traffic.
- Device RAM Agent models the segmented local RAM interface with independent
  read/write backpressure.
- Reference/Scoreboard keeps independent host/device memory images, a live
  descriptor table, and a PCIe-tag Outstanding Request Table.
- SVA checks ready/valid stability, MRRS/MPS limits, and 4 KiB request rules.
- Functional coverage tracks direction, length, alignment, TLP class/size and
  Completion status.

## Qualification status

Public GitHub Actions qualification is green.  The current evidence baseline is
Run #74 (head 7711efd2ff809e96e013a36ced4b88266b3a8827).

Measured normal-regression results:

- 13 clean simulation runs
- 256 completed descriptor end-to-end checks
- 2,704 Memory Read TLPs
- 1,109 Memory Write TLPs
- 41,390 Completion-with-Data packets
- 2,674 read requests completed through multiple CplD packets
- 16 simultaneous active PCIe Memory Read tags
- 11 simultaneous DMA descriptors observed
- 512 B largest Memory Read request / 256 B largest Memory Write request
- 65,535 B single-descriptor boundary verified in both directions
- 1 MiB logical H2C transfer verified through 17 chained descriptors
- 0 UVM_ERROR / 0 UVM_FATAL in every normal regression run

Coverage from the merged public qualification database:

- reachable functional coverage: 31/31 = 100%
- raw Verilator covergroup report: 31/33 = 93.9%
- the two raw uncovered bins are intentionally excluded semantic bins:
  an illegal 4 KiB-crossing request and an ignored Completion-status catch-all
- DUT-scoped line coverage: 818/840 = 97.4%
- DUT-scoped branch coverage: 200/253 = 79.1%

## Real RTL issue found by this verification flow

The 65,535-byte unaligned H2C boundary test exposed a width-overflow defect in
the pinned upstream dma_if_pcie_rd request-size comparison.  For length
16'hffff at an address offset of one byte, the original 16-bit addition wraps
and can generate a 4096-byte Memory Read even when MRRS is 512 B.

The project carries a one-line local width-extension fix, an SVA reproducer, and
a negative-control script that restores pristine pinned upstream RTL and
requires the original MRRS violation to reappear.  No claim is made that this
local patch has been accepted upstream.

See:

- docs/Verification_Plan.md
- docs/Testcase_List.md
- docs/Regression_Evidence.md
- docs/Discovered_Bug_MaxLen_Read.md
- docs/Resume_Target_CN.md
- docs/Interview_QA_CN.md
- docs/Commercial_Simulator_Flow.md

## Run

Open-source qualification:

    make regression

Commercial simulator path, on a licensed machine:

    make vcs-regression
    make verdi

The public measured numbers above are from the reproducible Verilator/UVM flow.
The VCS/Verdi/URG scripts are maintained but no commercial-simulator result is
claimed until that flow is actually executed.
