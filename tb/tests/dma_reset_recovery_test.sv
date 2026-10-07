class dma_reset_recovery_test extends dma_base_test;
  `uvm_component_utils(dma_reset_recovery_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_outstanding_seq pre_seq;
    dma_smoke_seq post_seq;
    int timeout;

    phase.raise_objection(this);

    // Hold every Completion indefinitely.  The DUT has only 16 PCIe tags, so
    // a threshold of 17 can never arm release and guarantees true mid-flight
    // state when reset is asserted.
    env.host.rsp.cfg.hold_cpl_until_unique_tags=17;
    env.host.rsp.cfg.cpl_min_latency=20;
    env.host.rsp.cfg.cpl_max_latency=60;

    for(int i=0;i<16;i++)
      env.mem.seed_host(64'h0000_0002_0000_0000+i*'h1000,1024);

    pre_seq=dma_outstanding_seq::type_id::create("pre_seq");
    pre_seq.start(env.desc.sqr);

    timeout=0;
    while(env.sb.pcie_reads.num()<16 && timeout<5000) begin
      @(posedge cfg_vif.clk);
      timeout++;
    end

    if(env.sb.pcie_reads.num()!=16)
      `uvm_error("RESET",$sformatf("failed to establish 16 active PCIe reads before reset, active=%0d max=%0d",
        env.sb.pcie_reads.num(),env.sb.max_pcie_outstanding))
    if(env.host.rsp.pending.size()==0)
      `uvm_error("RESET","expected queued pre-reset Completions before reset")

    // Reset while all read tags are live.  Disable the impossible hold before
    // deassertion so fresh post-reset traffic can complete normally.
    cfg_vif.force_reset<=1'b1;
    repeat(6) @(posedge cfg_vif.clk);
    env.host.rsp.cfg.hold_cpl_until_unique_tags=0;
    cfg_vif.force_reset<=1'b0;
    repeat(8) @(posedge cfg_vif.clk);

    if(env.sb.runtime_reset_events!=1)
      `uvm_error("RESET",$sformatf("expected one runtime reset event, observed %0d",
        env.sb.runtime_reset_events))
    if(env.sb.reset_flushed_pcie_reads<16)
      `uvm_error("RESET",$sformatf("expected at least 16 active PCIe contexts flushed, observed %0d",
        env.sb.reset_flushed_pcie_reads))
    if(env.sb.reset_flushed_descriptors<16)
      `uvm_error("RESET",$sformatf("expected at least 16 descriptor contexts flushed, observed %0d",
        env.sb.reset_flushed_descriptors))
    if(env.host.rsp.reset_dropped_completions==0)
      `uvm_error("RESET","host responder did not report dropping stale pre-reset Completions")
    if(env.host.rsp.pending.size()!=0 || env.sb.pcie_reads.num()!=0 || env.sb.pending.num()!=0)
      `uvm_error("RESET",$sformatf("stale state survived reset: host_pending=%0d pcie_ctx=%0d desc_ctx=%0d",
        env.host.rsp.pending.size(),env.sb.pcie_reads.num(),env.sb.pending.num()))
    if(cfg_vif.status_rd_busy || cfg_vif.status_wr_busy)
      `uvm_error("RESET",$sformatf("DUT busy did not clear after reset rd_busy=%0b wr_busy=%0b",
        cfg_vif.status_rd_busy,cfg_vif.status_wr_busy))

    // Prove forward progress after reset in both directions with fresh memory.
    env.mem.seed_host(64'h0000_0001_0000_1000,256);
    env.mem.seed_dev(20'h04000,256);
    post_seq=dma_smoke_seq::type_id::create("post_seq");
    post_seq.start(env.desc.sqr);
    repeat(3000) @(posedge cfg_vif.clk);

    if(env.sb.checks!=2)
      `uvm_error("RESET",$sformatf("expected exactly two post-reset descriptor checks, observed %0d",
        env.sb.checks))
    else
      `uvm_info("RESET",$sformatf("mid-flight reset flushed %0d descriptors/%0d PCIe reads, dropped %0d stale CplD, and post-reset H2C/C2H completed cleanly",
        env.sb.reset_flushed_descriptors,env.sb.reset_flushed_pcie_reads,
        env.host.rsp.reset_dropped_completions),UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
