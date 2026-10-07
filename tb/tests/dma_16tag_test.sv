class dma_16tag_test extends dma_base_test;
  `uvm_component_utils(dma_16tag_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase); dma_outstanding_seq seq; phase.raise_objection(this); for(int i=0;i<16;i++) env.mem.seed_host(64'h0000_0002_0000_0000+i*'h1000,1024); seq=dma_outstanding_seq::type_id::create("seq"); seq.start(env.desc.sqr); repeat(15000) @(posedge cfg_vif.clk); phase.drop_objection(this); endtask
endclass
