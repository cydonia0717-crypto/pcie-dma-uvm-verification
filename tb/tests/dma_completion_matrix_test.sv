// P28: complete the terminate-and-retire error paths of the DMA read engine.
// Timeout and FLR are generic-interface sideband indications, not wire TLPs.
class dma_completion_matrix_seq extends dma_base_seq;
  `uvm_object_utils(dma_completion_matrix_seq)
  longint unsigned pa;
  int unsigned ra;
  bit [7:0] dt;
  function new(string name="dma_completion_matrix_seq"); super.new(name); endfunction
  task body();
    send(DMA_H2C,pa,ra,128,dt);
  endtask
endclass

class dma_completion_matrix_test extends dma_base_test;
  `uvm_component_utils(dma_completion_matrix_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_completion_matrix_seq seq;
    longint unsigned pa;
    bit [7:0] dt;
    bit [3:0] expected_err;
    int unsigned deadline;
    phase.raise_objection(this);

    // Four independent H2C descriptors, one fault per descriptor.  Wait for
    // the previous tag to retire before changing the one-shot host injection.
    env.host.rsp.cfg.cpl_min_latency=2;
    env.host.rsp.cfg.cpl_max_latency=2;
    env.host.rsp.cfg.enable_cross_tag_ooo=0;
    for(int kind=2;kind<=5;kind++) begin
      case(kind)
        2: expected_err=4'hb;  // Completer Abort
        3: expected_err=4'h9;  // Poisoned
        4: expected_err=4'h1;  // Timeout
        5: expected_err=4'h8;  // FLR
      endcase
      dt=8'he0+kind;
      pa=64'h0000_000b_0000_2000+(kind*64'h1000);
      env.mem.seed_host(pa,128);
      env.host.rsp.cfg.inject_error_kind=kind;
      env.host.rsp.injected_ur=0;
      env.sb.expected_completion_errors++;
      env.sb.expect_descriptor_error(DMA_H2C,dt,expected_err);

      seq=dma_completion_matrix_seq::type_id::create($sformatf("fault_%0d",kind));
      seq.pa=pa; seq.ra=20'h40000+kind*20'h1000; seq.dt=dt;
      seq.start(env.desc.sqr);

      deadline=0;
      while(env.sb.checks<(kind-1) && deadline<10000) begin
        @(posedge cfg_vif.clk);
        deadline++;
      end
      if(env.sb.checks!=(kind-1) ||
         env.sb.expected_desc_errors_seen!=(kind-1) ||
         env.sb.completion_errors_seen!=(kind-1))
        `uvm_error("CPLMAT",$sformatf(
          "case=%0d descriptor/Completion mismatch: checks=%0d desc_err=%0d cpl_err=%0d",
          kind,env.sb.checks,env.sb.expected_desc_errors_seen,env.sb.completion_errors_seen))
    end

    // Prove the read engine can complete ordinary traffic after all faults.
    env.host.rsp.cfg.inject_error_kind=0;
    env.host.rsp.injected_ur=0;
    pa=64'h0000_000b_0000_9000;
    env.mem.seed_host(pa,128);
    seq=dma_completion_matrix_seq::type_id::create("post_error_h2c");
    seq.pa=pa; seq.ra=20'h49000; seq.dt=8'hef;
    seq.start(env.desc.sqr);
    deadline=0;
    while(env.sb.checks<5 && deadline<10000) begin
      @(posedge cfg_vif.clk);
      deadline++;
    end
    if(env.sb.checks!=5 || env.sb.expected_desc_errors_seen!=4 ||
       env.sb.completion_errors_seen!=4 || env.sb.errors!=0)
      `uvm_error("CPLMAT",$sformatf(
        "post-error H2C failed: checks=%0d desc_err=%0d cpl_err=%0d sb_errors=%0d",
        env.sb.checks,env.sb.expected_desc_errors_seen,
        env.sb.completion_errors_seen,env.sb.errors))
    else
      `uvm_info("CPLMAT","CA=0xB Poisoned=0x9 Timeout=0x1 FLR=0x8 and post-error H2C recovered cleanly",UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
