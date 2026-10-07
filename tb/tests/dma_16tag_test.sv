class dma_16tag_test extends dma_base_test;
  `uvm_component_utils(dma_16tag_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_outstanding_seq seq;
    phase.raise_objection(this);

    // Prevent the host model from returning any CplD until all 16 PCIe tags
    // are simultaneously occupied.  This turns the test into a deterministic
    // resource-pressure check instead of relying on random completion latency.
    env.host.rsp.cfg.hold_cpl_until_unique_tags=16;
    env.host.rsp.cfg.cpl_min_latency=20;
    env.host.rsp.cfg.cpl_max_latency=60;

    for(int i=0;i<16;i++)
      env.mem.seed_host(64'h0000_0002_0000_0000+i*'h1000,1024);

    seq=dma_outstanding_seq::type_id::create("seq");
    seq.start(env.desc.sqr);
    repeat(15000) @(posedge cfg_vif.clk);

    if(env.host.rsp.max_unique_pending_tags!=16)
      `uvm_error("16TAG",$sformatf("host responder expected 16 simultaneous PCIe request tags, observed %0d",
        env.host.rsp.max_unique_pending_tags))
    if(env.sb.max_pcie_outstanding!=16)
      `uvm_error("16TAG",$sformatf("scoreboard outstanding table expected depth 16, observed %0d",
        env.sb.max_pcie_outstanding))
    else
      `uvm_info("16TAG","scoreboard observed 16 simultaneous PCIe Memory Read tags",UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
