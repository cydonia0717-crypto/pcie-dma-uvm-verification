class dma_enable_gate_seq extends dma_base_seq;
  `uvm_object_utils(dma_enable_gate_seq)
  dma_dir_e dir;
  longint unsigned pcie_addr;
  int unsigned ram_addr;
  int unsigned len;
  bit [7:0] tag;

  function new(string name="dma_enable_gate_seq");
    super.new(name);
  endfunction

  task body();
    send(dir,pcie_addr,ram_addr,len,tag);
  endtask
endclass

class dma_enable_gating_test extends dma_base_test;
  `uvm_component_utils(dma_enable_gating_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task wait_for_checks(int unsigned expected,int unsigned limit,string label);
    int unsigned timeout=0;
    while(env.sb.checks<expected && timeout<limit) begin
      @(posedge cfg_vif.clk);
      timeout++;
    end
    if(env.sb.checks<expected)
      `uvm_error("ENABLE",$sformatf("%s timed out waiting for checks=%0d observed=%0d",
        label,expected,env.sb.checks))
  endtask

  task run_phase(uvm_phase phase);
    dma_enable_gate_seq h2c_seq,c2h_seq;
    bit h2c_accepted,c2h_accepted;
    int unsigned memrd_before,memwr_before;

    phase.raise_objection(this);

    // H2C: hold a real descriptor valid while reads are disabled.  The
    // sequence cannot complete its item handshake until read_enable returns.
    env.mem.seed_host(64'h0000_0003_0000_1000,512);
    cfg_vif.read_enable<=1'b0;
    repeat(4) @(posedge cfg_vif.clk);

    h2c_seq=dma_enable_gate_seq::type_id::create("h2c_seq");
    h2c_seq.dir=DMA_H2C;
    h2c_seq.pcie_addr=64'h0000_0003_0000_1000;
    h2c_seq.ram_addr=20'h18000;
    h2c_seq.len=512;
    h2c_seq.tag=8'he0;
    h2c_accepted=0;
    memrd_before=env.sb.memrd_count;

    fork
      begin
        h2c_seq.start(env.desc.sqr);
        h2c_accepted=1;
      end
    join_none

    repeat(32) @(posedge cfg_vif.clk);
    if(h2c_accepted)
      `uvm_error("ENABLE","H2C descriptor handshake completed while read_enable=0")
    if(env.sb.memrd_count!=memrd_before)
      `uvm_error("ENABLE",$sformatf("MemRd issued while read_enable=0 before=%0d after=%0d",
        memrd_before,env.sb.memrd_count))

    cfg_vif.read_enable<=1'b1;
    begin
      int unsigned timeout=0;
      while(!h2c_accepted && timeout<1000) begin
        @(posedge cfg_vif.clk);
        timeout++;
      end
      if(!h2c_accepted)
        `uvm_error("ENABLE","H2C descriptor did not handshake after read_enable was restored")
    end
    wait_for_checks(1,5000,"H2C re-enable");

    // C2H: repeat the same control-plane check independently for writes.
    env.mem.seed_dev(20'h28000,512);
    cfg_vif.write_enable<=1'b0;
    repeat(4) @(posedge cfg_vif.clk);

    c2h_seq=dma_enable_gate_seq::type_id::create("c2h_seq");
    c2h_seq.dir=DMA_C2H;
    c2h_seq.pcie_addr=64'h0000_0004_0000_2000;
    c2h_seq.ram_addr=20'h28000;
    c2h_seq.len=512;
    c2h_seq.tag=8'he1;
    c2h_accepted=0;
    memwr_before=env.sb.memwr_count;

    fork
      begin
        c2h_seq.start(env.desc.sqr);
        c2h_accepted=1;
      end
    join_none

    repeat(32) @(posedge cfg_vif.clk);
    if(c2h_accepted)
      `uvm_error("ENABLE","C2H descriptor handshake completed while write_enable=0")
    if(env.sb.memwr_count!=memwr_before)
      `uvm_error("ENABLE",$sformatf("MemWr issued while write_enable=0 before=%0d after=%0d",
        memwr_before,env.sb.memwr_count))

    cfg_vif.write_enable<=1'b1;
    begin
      int unsigned timeout=0;
      while(!c2h_accepted && timeout<1000) begin
        @(posedge cfg_vif.clk);
        timeout++;
      end
      if(!c2h_accepted)
        `uvm_error("ENABLE","C2H descriptor did not handshake after write_enable was restored")
    end
    wait_for_checks(2,5000,"C2H re-enable");

    if(env.sb.checks==2)
      `uvm_info("ENABLE","read/write enable gating held descriptors while disabled and recovered cleanly",UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
