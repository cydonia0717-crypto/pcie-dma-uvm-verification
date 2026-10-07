class dma_4k_split_test extends dma_base_test;
  `uvm_component_utils(dma_4k_split_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase); dma_4k_seq seq; phase.raise_objection(this); env.mem.seed_host(64'h0000_0001_0000_1ff0,512); env.mem.seed_dev(20'h0a000,512); seq=dma_4k_seq::type_id::create("seq"); seq.start(env.desc.sqr); repeat(6000) @(posedge cfg_vif.clk); phase.drop_objection(this); endtask
endclass
