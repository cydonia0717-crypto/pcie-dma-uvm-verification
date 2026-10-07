class dma_random_stress_test extends dma_base_test;
  `uvm_component_utils(dma_random_stress_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_random_stress_seq seq;
    phase.raise_objection(this);

    cfg_vif.max_read_request_size=3'd2; // 512 B
    cfg_vif.max_payload_size=3'd1;      // 256 B
    env.host.rsp.cfg.rd_ready_stall_pct=20;
    env.host.rsp.cfg.wr_ready_stall_pct=20;
    env.host.rsp.cfg.cpl_min_latency=2;
    env.host.rsp.cfg.cpl_max_latency=24;
    env.host.rsp.cfg.hold_cpl_until_unique_tags=4;
    env.host.rsp.cfg.enable_cross_tag_ooo=1;
    env.host.rsp.cfg.force_cross_tag_ooo_once=1;
    env.ram.model.rd_stall_pct=20;
    env.ram.model.wr_stall_pct=20;

    seq=dma_random_stress_seq::type_id::create("seq");
    seq.start(env.desc.sqr);
    repeat(50000) @(posedge cfg_vif.clk);

    if(env.sb.checks!=64)
      `uvm_error("RANDOM",$sformatf("expected 64 completed descriptors, got %0d",env.sb.checks))
    if(env.sb.max_desc_outstanding<4)
      `uvm_error("RANDOM",$sformatf("insufficient descriptor concurrency: %0d",env.sb.max_desc_outstanding))
    if(env.sb.max_pcie_outstanding<4)
      `uvm_error("RANDOM",$sformatf("insufficient PCIe read concurrency: %0d",env.sb.max_pcie_outstanding))
    if(env.host.rsp.cross_tag_ooo_count==0)
      `uvm_error("RANDOM","no cross-tag completion reorder observed")

    `uvm_info("RANDOM",$sformatf("completed=%0d max_desc=%0d max_pcie_reads=%0d ooo=%0d",
      env.sb.checks,env.sb.max_desc_outstanding,env.sb.max_pcie_outstanding,
      env.host.rsp.cross_tag_ooo_count),UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
