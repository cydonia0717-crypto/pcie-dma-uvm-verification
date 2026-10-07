class dma_zero_len_test extends dma_base_test;
  `uvm_component_utils(dma_zero_len_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_zero_len_seq seq;
    longint unsigned h2c_pa=64'h0000_0004_0000_1001;
    longint unsigned c2h_pa=64'h0000_0004_0000_2003;
    int unsigned h2c_ra=20'h50001;
    int unsigned c2h_ra=20'h60003;
    byte unsigned host_before[8], dev_before[8];

    phase.raise_objection(this);

    // Surround both destinations with sentinels.  A zero-length descriptor
    // must complete without modifying any host/device payload byte.
    for(int i=0;i<8;i++) begin
      env.mem.dev_put(h2c_ra-4+i, byte'(8'hA0+i));
      env.mem.host_put(c2h_pa-4+i, byte'(8'hC0+i));
      host_before[i]=env.mem.host_get(c2h_pa-4+i);
      dev_before[i]=env.mem.dev_get(h2c_ra-4+i);
    end

    seq=dma_zero_len_seq::type_id::create("seq");
    seq.start(env.desc.sqr);
    repeat(2500) @(posedge cfg_vif.clk);

    for(int i=0;i<8;i++) begin
      if(env.mem.dev_get(h2c_ra-4+i)!==dev_before[i])
        `uvm_error("ZERO_LEN",$sformatf("H2C zero-length modified device byte addr=%h",h2c_ra-4+i))
      if(env.mem.host_get(c2h_pa-4+i)!==host_before[i])
        `uvm_error("ZERO_LEN",$sformatf("C2H zero-length modified host byte addr=%h",c2h_pa-4+i))
    end

    `uvm_info("ZERO_LEN","zero-length H2C/C2H completed with destination sentinels preserved",UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
