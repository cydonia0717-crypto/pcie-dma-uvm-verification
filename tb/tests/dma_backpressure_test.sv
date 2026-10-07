class dma_backpressure_test extends dma_base_test;
  `uvm_component_utils(dma_backpressure_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    dma_backpressure_seq seq;
    phase.raise_objection(this);
    env.host.rsp.cfg.rd_ready_stall_pct=50;
    env.host.rsp.cfg.wr_ready_stall_pct=50;
    env.ram.model.rd_stall_pct=50;
    env.ram.model.wr_stall_pct=50;
    env.mem.seed_host(64'h0000_0007_0000_0000,4096);
    env.mem.seed_dev(20'h80000,4096);
    seq=dma_backpressure_seq::type_id::create("seq"); seq.start(env.desc.sqr);
    repeat(20000) @(posedge cfg_vif.clk);
    if(env.host.rsp.tx_rd_stall_cycles==0) `uvm_error("BP","no PCIe Memory Read request backpressure observed")
    if(env.host.rsp.tx_wr_stall_cycles==0) `uvm_error("BP","no PCIe Memory Write request backpressure observed")
    if(env.ram.model.rd_stall_cycles==0) `uvm_error("BP","no device-RAM read-command backpressure observed")
    if(env.ram.model.wr_stall_cycles==0) `uvm_error("BP","no device-RAM write-command backpressure observed")
    phase.drop_objection(this);
  endtask
endclass
