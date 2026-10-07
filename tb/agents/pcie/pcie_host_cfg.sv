class pcie_host_cfg extends uvm_object;
  `uvm_object_utils(pcie_host_cfg)
  int unsigned rd_ready_stall_pct=0;
  int unsigned wr_ready_stall_pct=0;
  int unsigned cpl_min_latency=2;
  int unsigned cpl_max_latency=12;
  int unsigned cpl_payload_max=32;
  int unsigned hold_cpl_until_unique_tags=0;
  bit enable_cross_tag_ooo=1;
  bit force_cross_tag_ooo_once=0;
  bit [15:0] completer_id=16'h0200;
  function new(string name="pcie_host_cfg"); super.new(name); endfunction
endclass
