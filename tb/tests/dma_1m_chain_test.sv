class dma_1m_chain_test extends dma_base_test;
  `uvm_component_utils(dma_1m_chain_test)
  localparam int unsigned TOTAL_BYTES=1024*1024;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_1m_chain_seq seq;
    int unsigned cycles;
    phase.raise_objection(this);

    cfg_vif.max_read_request_size=3'd2; // 512 B MRRS
    env.host.rsp.cfg.hold_cpl_until_unique_tags=16;
    env.host.rsp.cfg.cpl_min_latency=2;
    env.host.rsp.cfg.cpl_max_latency=16;
    env.mem.seed_host(64'h0000_000c_0000_0000,TOTAL_BYTES);

    seq=dma_1m_chain_seq::type_id::create("seq");
    seq.start(env.desc.sqr);

    cycles=0;
    while(env.sb.checks<17 && cycles<250000) begin
      @(posedge cfg_vif.clk);
      cycles++;
    end

    if(env.sb.checks!=17)
      `uvm_error("CHAIN1M",$sformatf("expected 17 completed descriptors, got %0d",env.sb.checks))
    if(env.sb.ram_wr_byte_count!=TOTAL_BYTES)
      `uvm_error("CHAIN1M",$sformatf("expected %0d H2C bytes, observed %0d",TOTAL_BYTES,env.sb.ram_wr_byte_count))
    if(env.sb.max_pcie_outstanding!=16)
      `uvm_error("CHAIN1M",$sformatf("expected 16-tag pressure, observed %0d",env.sb.max_pcie_outstanding))
    if(env.sb.checks==17 && env.sb.ram_wr_byte_count==TOTAL_BYTES && env.sb.max_pcie_outstanding==16)
      `uvm_info("CHAIN1M","1MiB H2C logical DMA completed through 17 descriptors with 16 PCIe tags in flight",UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
