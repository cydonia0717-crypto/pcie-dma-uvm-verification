package dma_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  localparam int TLP_DATA_W=256, TLP_HDR_W=128, RAM_ADDR_W=20, RAM_SEG_COUNT=2, RAM_SEG_DATA_W=256, RAM_SEG_BE_W=32, RAM_SEG_ADDR_W=14;
  `uvm_analysis_imp_decl(_desc)
  `uvm_analysis_imp_decl(_tlp)
  `uvm_analysis_imp_decl(_ram_sb)
  `uvm_analysis_imp_decl(_cov_desc)
  `uvm_analysis_imp_decl(_cov_tlp)
  `uvm_analysis_imp_decl(_cov_ram)
  `include "scoreboard/dma_ref_mem.sv"
  `include "agents/desc/dma_desc_item.sv"
  `include "agents/pcie/pcie_tlp_item.sv"
  `include "agents/ram/dma_ram_item.sv"
  `include "agents/pcie/pcie_host_cfg.sv"
  `include "agents/desc/dma_desc_sequencer.sv"
  `include "agents/desc/dma_desc_driver.sv"
  `include "agents/desc/dma_desc_monitor.sv"
  `include "agents/desc/dma_desc_agent.sv"
  `include "agents/pcie/pcie_host_responder.sv"
  `include "agents/pcie/pcie_host_agent.sv"
  `include "agents/ram/dma_ram_model.sv"
  `include "agents/ram/dma_ram_agent.sv"
  `include "scoreboard/dma_scoreboard.sv"
  `include "coverage/dma_coverage.sv"
  `include "env/dma_env.sv"
  `include "seq/dma_base_seq.sv"
  `include "seq/dma_smoke_seq.sv"
  `include "seq/dma_4k_seq.sv"
  `include "seq/dma_outstanding_seq.sv"
  `include "seq/dma_small_unaligned_seq.sv"
  `include "seq/dma_limits_seq.sv"
  `include "seq/dma_ooo_seq.sv"
  `include "seq/dma_backpressure_seq.sv"
  `include "seq/dma_random_stress_seq.sv"
  `include "seq/dma_max_len_seq.sv"
  `include "seq/dma_completion_error_seq.sv"
  `include "tests/dma_base_test.sv"
  `include "tests/dma_smoke_test.sv"
  `include "tests/dma_4k_split_test.sv"
  `include "tests/dma_16tag_test.sv"
  `include "tests/dma_small_unaligned_test.sv"
  `include "tests/dma_limits_test.sv"
  `include "tests/dma_split_ooo_test.sv"
  `include "tests/dma_backpressure_test.sv"
  `include "tests/dma_random_stress_test.sv"
  `include "tests/dma_max_len_test.sv"
  `include "tests/dma_completion_error_test.sv"
endpackage
