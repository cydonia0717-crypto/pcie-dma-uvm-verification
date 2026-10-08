# Qualification Testcase List

The canonical open-source qualification is defined in `scripts/oss_regression.sh`.  The VCS suite mirrors the same testcase/seed manifest.

| Test | Seed | Verification intent |
|---|---:|---|
| `dma_smoke_test` | 1 | aligned H2C + C2H end-to-end data movement |
| `dma_4k_split_test` | 2 | H2C/C2H splitting at the 4 KiB request boundary |
| `dma_16tag_test` | 3 | deterministic proof of 16 simultaneous active PCIe Memory Read tags |
| `dma_small_unaligned_test` | 4 | small lengths, address offsets, First/Last BE and neighbor-byte preservation |
| `dma_limits_test` | 5 | MRRS=512 B Memory Read and MPS=256 B Memory Write segmentation |
| `dma_split_ooo_test` | 6 | multiple CplD per MemRd plus cross-tag out-of-order Completion return |
| `dma_backpressure_test` | 7 | PCIe TX and segmented-RAM backpressure with protocol stability |
| `dma_max_len_test` | 8 | 65,535-byte H2C/C2H single-descriptor boundary |
| `dma_completion_error_test` | 9 | Unsupported Request Completion -> DMA descriptor error propagation |
| `dma_1m_chain_test` | 10 | 1 MiB logical H2C transfer through 17 chained descriptors |
| `dma_random_stress_test` | 11 | mixed H2C/C2H concurrency, splitting, reorder and backpressure |
| `dma_zero_len_test` | 12 | source-defined zero-length H2C/C2H semantics and no destination byte modification |
| `dma_reset_recovery_test` | 13 | reset with an active Memory Read; flush stale descriptor/TLP/CplD state and prove post-reset H2C/C2H progress |
| `dma_enable_gating_test` | 14 | hold H2C/C2H descriptors while read/write enable is low; prove no request escapes and both directions recover after re-enable |
| `dma_multibeat_cpl_test` | 15 | return 64-byte CplD over two PCIe interface beats, force Completion backpressure, then prove clean H2C reassembly and recovery |
| `dma_random_stress_test` | 29 | reproducible mixed-traffic random seed |
| `dma_random_stress_test` | 47 | reproducible mixed-traffic random seed |

## Separate negative control

`scripts/repro_upstream_maxlen_bug.sh` is deliberately not counted as a normal green testcase.  It restores pristine pinned upstream RTL and expects the maximum-length unaligned H2C test to fail the MRRS assertion.  The negative control passes only when the known defect reappears.
