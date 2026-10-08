class dma_multibeat_cpl_seq extends dma_base_seq;
  `uvm_object_utils(dma_multibeat_cpl_seq)
  function new(string name="dma_multibeat_cpl_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,64'h0000_0005_0000_4000,20'h34000,4096,8'hf0);
  endtask
endclass

class dma_multibeat_cpl_test extends dma_base_test;
  `uvm_component_utils(dma_multibeat_cpl_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_multibeat_cpl_seq seq;
    int unsigned timeout;

    phase.raise_objection(this);

    // One Completion TLP may span two 256-bit beats.  Hold the device-RAM
    // write side stopped first so the responder is forced to keep a CplD beat
    // stable under rx_cpl_ready backpressure, then release and prove recovery.
    env.host.rsp.cfg.cpl_payload_max=64;
    env.host.rsp.cfg.cpl_min_latency=2;
    env.host.rsp.cfg.cpl_max_latency=2;
    env.host.rsp.cfg.enable_cross_tag_ooo=0;
    env.ram.model.wr_stall_pct=100;

    env.mem.seed_host(64'h0000_0005_0000_4000,4096);
    seq=dma_multibeat_cpl_seq::type_id::create("seq");
    seq.start(env.desc.sqr);

    timeout=0;
    while(env.host.rsp.multi_beat_cpl_stall_cycles<4 && timeout<3000) begin
      @(posedge cfg_vif.clk);
      timeout++;
    end
    if(env.host.rsp.multi_beat_cpl_count==0)
      `uvm_error("MB_CPL","no multi-beat Completion TLP was generated")
    if(env.host.rsp.multi_beat_cpl_stall_cycles<4)
      `uvm_error("MB_CPL",$sformatf("failed to hold a multi-beat CplD under backpressure, stall_cycles=%0d",
        env.host.rsp.multi_beat_cpl_stall_cycles))

    env.ram.model.wr_stall_pct=0;

    timeout=0;
    while(env.sb.checks<1 && timeout<10000) begin
      @(posedge cfg_vif.clk);
      timeout++;
    end

    if(env.sb.checks!=1)
      `uvm_error("MB_CPL",$sformatf("H2C descriptor did not complete after releasing backpressure, checks=%0d",
        env.sb.checks))
    if(env.host.rsp.max_cpl_beats<2)
      `uvm_error("MB_CPL",$sformatf("expected at least two beats in one CplD, observed max=%0d",
        env.host.rsp.max_cpl_beats))
    if(env.sb.split_read_requests==0)
      `uvm_error("MB_CPL","expected the 4096-byte H2C transfer to include split Completion requests")

    if(env.sb.checks==1 && env.host.rsp.max_cpl_beats>=2 &&
       env.host.rsp.multi_beat_cpl_stall_cycles>=4)
      `uvm_info("MB_CPL",$sformatf("multibeat_cpl=%0d max_beats=%0d stalled_cycles=%0d split_reads=%0d",
        env.host.rsp.multi_beat_cpl_count,env.host.rsp.max_cpl_beats,
        env.host.rsp.multi_beat_cpl_stall_cycles,env.sb.split_read_requests),UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
