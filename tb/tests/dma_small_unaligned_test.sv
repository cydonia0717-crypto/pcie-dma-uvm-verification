class dma_small_unaligned_test extends dma_base_test;
  `uvm_component_utils(dma_small_unaligned_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    dma_small_unaligned_seq seq;
    int lens[8]='{1,2,3,4,8,16,31,32};
    phase.raise_objection(this);
    for(int i=0;i<8;i++) begin
      env.mem.seed_host(64'h0000_0003_0000_0000+i*'h100+(i%4),lens[i]);
      env.mem.seed_dev(20'h30000+i*'h80+((i+1)%4),lens[i]);
    end
    seq=dma_small_unaligned_seq::type_id::create("seq"); seq.start(env.desc.sqr);
    repeat(6000) @(posedge cfg_vif.clk);
    if(env.sb.checks!=16) `uvm_error("SMALL",$sformatf("expected 16 completed descriptors, got %0d",env.sb.checks))
    phase.drop_objection(this);
  endtask
endclass
