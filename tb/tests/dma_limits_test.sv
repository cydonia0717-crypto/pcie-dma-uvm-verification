class dma_limits_test extends dma_base_test;
  `uvm_component_utils(dma_limits_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    dma_limits_seq seq;
    phase.raise_objection(this);
    cfg_vif.max_read_request_size=3'd2; // 512 B MRRS
    cfg_vif.max_payload_size=3'd1;      // 256 B MPS
    env.mem.seed_host(64'h0000_0004_0000_0000,1536);
    env.mem.seed_dev(20'h50000,1536);
    seq=dma_limits_seq::type_id::create("seq"); seq.start(env.desc.sqr);
    repeat(10000) @(posedge cfg_vif.clk);
    if(env.sb.max_memrd_tlp_bytes!=512)
      `uvm_error("LIMIT",$sformatf("expected a 512B MemRd at MRRS=512, max observed %0d",env.sb.max_memrd_tlp_bytes))
    if(env.sb.max_memwr_tlp_bytes!=256)
      `uvm_error("LIMIT",$sformatf("expected a 256B MemWr at MPS=256, max observed %0d",env.sb.max_memwr_tlp_bytes))
    phase.drop_objection(this);
  endtask
endclass
