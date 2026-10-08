# Public Regression Evidence

This file records the last fully qualified public baseline used by the resume numbers.

## Baseline

- GitHub Actions workflow: `oss-smoke`
- run: **#133**
- head: `a5f01ad61eeaa37a72466d70068f87271735fefc`
- conclusion: **success**
- artifact: `pcie-dma-regression-133`

The qualification archived each UVM run log, each Verilator coverage database, the merged coverage database, machine-readable regression summary, and the pristine-upstream bug reproducer.

## Normal-regression totals

- clean simulation runs: **17**
- completed descriptor end-to-end checks: **263**
- Memory Read TLPs: **2,726**
- Memory Write TLPs: **1,116**
- Completion-with-Data packets: **41,479**
- read requests completed through multiple CplD packets: **2,693**
- peak simultaneous PCIe Memory Read tags: **16**
- peak simultaneous DMA descriptors: **11**
- distinct PCIe tags exercised: **16**
- legal PCIe tag reuse events after retirement: **2,568**
- largest observed MemRd: **512 B**
- largest observed MemWr: **256 B**
- H2C Device-RAM bytes written: **1,326,879 B**
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

Its scoreboard summary reports `max_pcie_outstanding=16`.  The same directed test also reports:

```text
[TAGREUSE] observed 48 legal PCIe tag reuse events after retirement
```

The scoreboard rejects reuse while a tag is still active, while the lifecycle coverage separately requires both first-use and legal-reuse bins.

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

### Read/write enable gating

The directed enable-gating run holds a real H2C or C2H descriptor valid while the corresponding DUT enable is low.  No descriptor handshake or downstream Memory Request is allowed to escape while disabled; after re-enable the same descriptor must complete end-to-end.  Run #133 reports:

```text
[ENABLE] read/write enable gating held descriptors while disabled and recovered cleanly
```

### Multi-beat Completion TLP

This is distinct from Split Completion.  Split Completion means one MemRd is completed by multiple semantic CplD packets; the multi-beat case means one semantic CplD packet itself spans multiple 256-bit interface beats.  The host responder preserves SOP/EOP packet boundaries, does not interleave beats from different packets, holds the active beat stable under `valid && !ready`, and publishes the semantic CplD to the scoreboard only after the final EOP handshake.

The 4 KiB directed case uses 64-byte CplD packets over two 256-bit beats and deliberately fills downstream buffering until Completion input backpressure is observed.  Run #133 reports:

```text
[MB_CPL] multibeat_cpl=64 max_beats=2 stalled_cycles=13 split_reads=16
```

The descriptor completes with 4,096 destination bytes checked cleanly.  This coverage-directed testcase increased DUT branch coverage from 208/253 to 218/253 while preserving all previous regression results.

### Completion error propagation

An Unsupported Request Completion is injected and is required to propagate to descriptor status as DMA error **0xA**.

### 65,535-byte single descriptor

The maximum 16-bit descriptor boundary is verified in both directions:

```text
[MAXLEN] 65535-byte H2C and C2H descriptors completed cleanly
```

This same test originally exposed the read-size arithmetic overflow documented in `Discovered_Bug_MaxLen_Read.md`.

### Mid-flight reset recovery

The reset-directed run first allows a real H2C descriptor to create live PCIe read state while Completion traffic is held.  Runtime reset then flushes verification-side stale contexts and the DUT is required to clear busy/resource state before accepting fresh traffic.  Run #133 reports:

```text
[RESET] mid-flight reset flushed 1 descriptors/2 PCIe reads, dropped 16 stale CplD, and post-reset H2C/C2H completed cleanly
```

This checks both cancellation of pre-reset work and forward progress after reset; old queued Completion packets are explicitly discarded instead of leaking into the new reset epoch.

### 1 MiB logical DMA

The large-transfer run completes exactly **1 MiB H2C** via **17 descriptors** and reports 16 PCIe tags in flight.  It is intentionally described as a chained logical transfer, not a 1 MiB single descriptor.

### Random stress

Three reproducible seeds (11, 29, 47) complete 64 mixed descriptors each.

### Zero-length source-defined behavior

Both H2C and C2H zero-length descriptors are checked.  The qualification requires descriptor retirement while preserving destination sentinels; the H2C path observes the source-defined zero-length Memory Read / Completion handshake without writing payload bytes.  Peak descriptor concurrency reaches **11** and every seed reaches **16 active PCIe read tags** while exercising cross-tag reordering.

## Coverage evidence

Merged public qualification:

- reachable functional coverage: **53/53 = 100%**
- raw covergroup: **53/55 = 96.4%**
- DUT-scoped line coverage: **820/840 = 97.6%**
- DUT-scoped branch coverage: **218/253 = 86.2%**

The two raw covergroup bins excluded from the reachable denominator are semantic exclusions: an illegal single request crossing a 4 KiB boundary and an ignored Completion-status catch-all.

## Negative control for the discovered RTL defect

The normal flow applies the local width-extension patch and remains green.  The negative-control script then restores pristine upstream commit `25156a9a162c41c60f11f41590c7d006d015ae5a`, recompiles, and requires the original MRRS assertion to fire:

```text
MRRS violation len_field=0 cfg_enc=2
hdr=20000000010000fe0000b00000000000
```

This proves that the fixed qualification and the defect reproducer are checking opposite expected outcomes rather than sharing a permissive checker.
