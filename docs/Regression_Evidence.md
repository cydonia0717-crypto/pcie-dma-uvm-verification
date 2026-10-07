# Public Regression Evidence

This file records the last fully qualified public baseline used by the resume numbers.

## Baseline

- GitHub Actions workflow: `oss-smoke`
- run: **#74**
- head: `7711efd2ff809e96e013a36ced4b88266b3a8827`
- conclusion: **success**
- artifact: `pcie-dma-regression-74`
- artifact digest: `sha256:dd714b7dc665dbc1ad363c93f2bcd91d6bb44651345a2bf402812723f829cf55`

The qualification archived each UVM run log, each Verilator coverage database, the merged coverage database, machine-readable regression summary, and the pristine-upstream bug reproducer.

## Normal-regression totals

- clean simulation runs: **13**
- completed descriptor end-to-end checks: **256**
- Memory Read TLPs: **2,704**
- Memory Write TLPs: **1,109**
- Completion-with-Data packets: **41,390**
- read requests completed through multiple CplD packets: **2,674**
- peak simultaneous PCIe Memory Read tags: **16**
- peak simultaneous DMA descriptors: **11**
- largest observed MemRd: **512 B**
- largest observed MemWr: **256 B**
- H2C Device-RAM bytes written: **1,314,177 B**
- UVM errors/fatals: **0 / 0 in every normal run**

## Directed proof points

### H2C/C2H smoke

Both directions complete end-to-end through the independent host/device memory images.  The smoke run checks one H2C and one C2H operation and observes real RAM commands and PCIe TLPs.

### 4 KiB boundary

The boundary run emits **3 MemRd** and **5 MemWr** requests while keeping every request inside one 4 KiB window.  Both descriptors complete with 0 UVM errors.

### Sixteen simultaneous PCIe read tags

The directed tag-pressure run holds Completion traffic until the requester has consumed all 16 tags.  Evidence line:

```text
[16TAG] scoreboard observed 16 simultaneous PCIe Memory Read tags
```

Its scoreboard summary reports `max_pcie_outstanding=16`.

### MRRS / MPS

The limit-directed run observes a maximum **512 B Memory Read** and **256 B Memory Write**, matching the configured MRRS/MPS cases.

### Split Completion and cross-tag OOO

The dedicated run reports:

```text
[OOO] split_memrd=8 cross_tag_ooo=44
```

The scoreboard remains clean while one request is split into multiple CplD packets and independent tags return out of issue order.

### Backpressure

PCIe request ready and segmented-RAM command/response paths are independently throttled.  The run reaches 16 active PCIe read tags while completing both transfer directions without data loss or protocol-stability errors.

### Completion error propagation

An Unsupported Request Completion is injected and is required to propagate to descriptor status as DMA error **0xA**.

### 65,535-byte single descriptor

The maximum 16-bit descriptor boundary is verified in both directions:

```text
[MAXLEN] 65535-byte H2C and C2H descriptors completed cleanly
```

This same test originally exposed the read-size arithmetic overflow documented in `Discovered_Bug_MaxLen_Read.md`.

### 1 MiB logical DMA

The large-transfer run completes exactly **1 MiB H2C** via **17 descriptors** and reports 16 PCIe tags in flight.  It is intentionally described as a chained logical transfer, not a 1 MiB single descriptor.

### Random stress

Three reproducible seeds (11, 29, 47) complete 64 mixed descriptors each.  Peak descriptor concurrency reaches **11** and every seed reaches **16 active PCIe read tags** while exercising cross-tag reordering.

## Coverage evidence

Merged public qualification:

- reachable functional coverage: **31/31 = 100%**
- raw covergroup: **31/33 = 93.9%**
- DUT-scoped line coverage: **818/840 = 97.4%**
- DUT-scoped branch coverage: **200/253 = 79.1%**

The two raw covergroup bins excluded from the reachable denominator are semantic exclusions: an illegal single request crossing a 4 KiB boundary and an ignored Completion-status catch-all.

## Negative control for the discovered RTL defect

The normal flow applies the local width-extension patch and remains green.  The negative-control script then restores pristine upstream commit `25156a9a162c41c60f11f41590c7d006d015ae5a`, recompiles, and requires the original MRRS assertion to fire:

```text
MRRS violation len_field=0 cfg_enc=2
hdr=20000000010000fe0000b00000000000
```

This proves that the fixed qualification and the defect reproducer are checking opposite expected outcomes rather than sharing a permissive checker.
