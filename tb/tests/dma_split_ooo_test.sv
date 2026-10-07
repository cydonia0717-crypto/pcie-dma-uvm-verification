class dma_split_ooo_test extends dma_base_test;
  `uvm_component_utils(dma_split_ooo_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    dma_ooo_seq seq;
    phase.raise_objection(this);
    env.host.rsp.cfg.cpl_payload_max=32;
    env.host.rsp.cfg.cpl_min_latency=2;
    env.host.rsp.cfg.cpl_max_latency=2;
    env.host.rsp.cfg.hold_cpl_until_unique_tags=4;
    env.host.rsp.cfg.enable_cross_tag_ooo=1;
    env.host.rsp.cfg.force_cross_tag_ooo_once=1;
    for(int i=0;i<4;i++) env.mem.seed_host(64'h0000_0006_0000_0000+i*'h1000,512);
    seq=dma_ooo_seq::type_id::create("seq"); seq.start(env.desc.sqr);
    repeat(10000) @(posedge cfg_vif.clk);
    if(env.host.rsp.split_memrd_count==0) `uvm_error("OOO","no split-completion request observed")
    if(env.host.rsp.cross_tag_ooo_count==0) `uvm_error("OOO","no cross-tag completion reorder observed")
    else `uvm_info("OOO",$sformatf("split_memrd=%0d cross_tag_ooo=%0d",
      env.host.rsp.split_memrd_count,env.host.rsp.cross_tag_ooo_count),UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
