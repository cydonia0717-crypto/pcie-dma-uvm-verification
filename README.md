# PCIe DMA Engine UVM Verification

SystemVerilog/UVM verification project for the open-source `alexforencich/verilog-pcie` PCIe DMA engine.

The project pins the DUT to commit `25156a9a162c41c60f11f41590c7d006d015ae5a` and builds an independent UVM environment around `dma_if_pcie`.

Current status: initial verification scaffold; measured regression/coverage numbers will only be published after CI execution.
