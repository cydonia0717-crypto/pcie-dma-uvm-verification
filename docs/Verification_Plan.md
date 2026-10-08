# Verification Plan

| ID | Feature / risk | Stimulus | Main check |
|---|---|---|---|
| P01 | H2C aligned smoke | one aligned read descriptor | MemRd fields; CplD data reaches correct RAM bytes |
| P02 | C2H aligned smoke | one aligned write descriptor | RAM data becomes correct MemWr payload |
| P03 | small lengths | 1/2/3/4/8/16/31/32 B | First/Last BE and byte preservation |
| P04 | unaligned address | offsets 1/2/3 and cache-line-like offsets | address/BE/data realignment |
| P05 | MRRS=256 | H2C >256 B | every MemRd obeys MRRS |
| P06 | MRRS=512 | H2C >512 B | every MemRd obeys MRRS |
| P07 | MPS=128 | C2H >128 B | every MemWr obeys MPS |
| P08 | MPS=256 | C2H >256 B | every MemWr obeys MPS |
| P09 | 4 KiB H2C split | read crosses 4 KiB | no MemRd crosses 4 KiB |
| P10 | 4 KiB C2H split | write crosses 4 KiB | no MemWr crosses 4 KiB |
| P11 | multi-packet descriptor | 4 KiB+ transfer | exact byte count/end-to-end data |
| P12 | 16 outstanding reads | hold/reorder completions | 16 active tags; no tag alias |
| P13 | split completion | one MemRd -> multiple CplD | Byte Count/Lower Address progression and reassembly |
| P14 | cross-tag OOO | completions across tags reorder | correct tag-context routing |
| P15 | TX request backpressure | deassert request ready | payload stability / no loss |
| P16 | completion backpressure | DUT deasserts cpl ready | responder holds CplD stable |
| P17 | RAM read backpressure | throttle device RAM source | C2H progress and data integrity |
| P18 | RAM write backpressure | throttle H2C destination | H2C progress and data integrity |
| P19 | descriptor concurrency | overlapping H2C and C2H descriptors | status/tag independence |
| P20 | completion error | inject status/error | descriptor error propagation |
| P21 | zero length | zero-length descriptor | source-defined zero-length behavior |
| P22 | max descriptor length | near 64 KiB | no counter overflow |
| P23 | large logical DMA | chain descriptors to 1 MiB | aggregate end-to-end data integrity |
| P24 | random stress | constrained mixed traffic | scoreboard clean across seeds |
| P25 | mid-flight reset recovery | assert reset with an active MemRd and queued CplD | stale contexts flushed; busy clears; fresh H2C/C2H complete |
| P26 | read/write enable gating | hold H2C/C2H descriptor valid with corresponding enable low, then re-enable | no handshake/TLP while disabled; descriptor completes after re-enable |

## Closure criteria

A resume number is published only after the relevant CI evidence exists. Minimum closure target: all mandatory directed tests pass, multi-seed random regression is stable, 16-tag pressure is observed, split/out-of-order completions are observed, and functional/code coverage holes are reviewed.
