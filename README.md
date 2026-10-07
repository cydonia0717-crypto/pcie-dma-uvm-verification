# PCIe DMA Engine UVM Verification

Portfolio-grade SystemVerilog/UVM verification project around the open-source
`alexforencich/verilog-pcie` DMA engine.

## DUT

Pinned upstream revision:

- repository: `alexforencich/verilog-pcie`
- commit: `25156a9a162c41c60f11f41590c7d006d015ae5a`
- module: `dma_if_pcie`
- license: MIT

The project intentionally verifies the **transaction-layer DMA engine**, not the
PCIe PHY/data-link layer and not a complete commercial Endpoint controller.

## Fixed verification configuration

- 256-bit generic TLP datapath
- 64-bit PCIe address
- 16 PCIe tags / max read-request concurrency target
- 16-entry read operation table
- 16-entry write operation table
- 1 MiB device-side segmented RAM address space
- 8-bit descriptor tag
- Write-request MPS cases: 128 B / 256 B
- Read-request MRRS cases: 256 B / 512 B
- 64-bit requester address space, 4-DW requests forced for simpler deterministic checking

Direction naming in this project:

- **H2C**: host memory -> device RAM. DUT emits Memory Read requests and consumes Completion with Data.
- **C2H**: device RAM -> host memory. DUT reads device RAM and emits Memory Write requests.

## UVM architecture

- Descriptor Agent: drives H2C/C2H DMA descriptors and observes descriptor status.
- PCIe Host Agent: observes Memory Read/Write TLPs, owns host-memory model, and returns Completion with Data for H2C.
- Device RAM Agent: models the segmented local RAM interface and supports backpressure.
- Scoreboard: owns independent host/device architectural images and checks end-to-end data movement plus TLP rules.
- SVA: valid/ready stability, 4 KiB request-boundary rule, MPS/MRRS limits, and active-tag uniqueness hooks.
- Functional Coverage: direction, length/alignment, MPS/MRRS, 4 KiB split, outstanding depth, split completion, cross-tag reorder, and backpressure.

## Status

The repository is now in **bring-up**. The environment, first directed tests,
pinned DUT bootstrap, and GitHub Actions flow are present. Measured regression,
coverage, and bug counts will only be published after the public CI is green and
the corresponding evidence is archived.

## Current bring-up order

1. H2C/C2H aligned smoke
2. 4 KiB read/write splitting
3. 16-tag read pressure
4. MRRS/MPS directed segmentation
5. split-completion + cross-tag reorder
6. RAM/TLP backpressure
7. constrained-random regression and coverage closure

See `docs/Verification_Plan.md`, `docs/DUT_Architecture.md`,
`docs/Source_Provenance.md`, and `docs/Resume_Target_CN.md`.

VCS/Verdi scripts will be added as the commercial-simulator path after the OSS
Verilator/UVM flow is stable.
