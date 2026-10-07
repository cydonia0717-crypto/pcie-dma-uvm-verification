class dma_smoke_test extends dma_base_test;
  `uvm_component_utils(dma_smoke_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase); dma_smoke_seq seq; phase.raise_objection(this); env.mem.seed_host(64'h0000_0001_0000_1000,256); env.mem.seed_dev(20'h04000,256); seq=dma_smoke_seq::type_id::create("seq"); seq.start(env.desc.sqr); repeat(3000) @(posedge cfg_vif.clk); phase.drop_objection(this); endtask
endclass
