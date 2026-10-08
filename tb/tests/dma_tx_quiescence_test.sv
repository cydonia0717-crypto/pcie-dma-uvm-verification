// P29: quiescence requires both descriptor status retirement and TX packet
// acceptance acknowledgments.  A stuck busy signal must fail this test.
class dma_tx_quiescence_test extends dma_base_test;
  `uvm_component_utils(dma_tx_quiescence_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_smoke_seq seq;
    int unsigned deadline;
    phase.raise_objection(this);
    env.mem.seed_host(64'h0000_0001_0000_1000,256);
    env.mem.seed_dev(20'h04000,256);
    seq=dma_smoke_seq::type_id::create("seq");
    seq.start(env.desc.sqr);

    deadline=0;
    while(env.sb.checks<2 && deadline<10000) begin
      @(posedge cfg_vif.clk);
      deadline++;
    end
    // Let the one-cycle-delayed link TX acceptance indication retire counters.
    repeat(20) @(posedge cfg_vif.clk);
    if(env.sb.checks!=2 || env.sb.errors!=0)
      `uvm_error("TXACK",$sformatf("H2C/C2H incomplete: checks=%0d errors=%0d",
        env.sb.checks,env.sb.errors))
    if(cfg_vif.status_rd_busy || cfg_vif.status_wr_busy)
      `uvm_error("TXACK",$sformatf(
        "DUT failed to become idle after accepted H2C/C2H: read_busy=%0b write_busy=%0b",
        cfg_vif.status_rd_busy,cfg_vif.status_wr_busy))
    if(env.sb.checks==2 && env.sb.errors==0 &&
       !cfg_vif.status_rd_busy && !cfg_vif.status_wr_busy)
      `uvm_info("TXACK","H2C/C2H TX acknowledgments drained and both DUT busy flags cleared",UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
