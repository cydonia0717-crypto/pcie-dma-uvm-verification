class dma_completion_error_test extends dma_base_test;
  `uvm_component_utils(dma_completion_error_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_completion_error_seq seq;
    phase.raise_objection(this);

    env.mem.seed_host(64'h0000_000b_0000_1000,128);
    env.host.rsp.cfg.inject_ur_once=1;
    env.sb.expected_completion_errors=1;
    env.sb.expect_descriptor_error(DMA_H2C,8'he1,4'ha);

    seq=dma_completion_error_seq::type_id::create("seq");
    seq.start(env.desc.sqr);
    repeat(5000) @(posedge cfg_vif.clk);

    if(env.sb.expected_desc_errors_seen!=1 || env.sb.completion_errors_seen!=1)
      `uvm_error("CPLERR",$sformatf("expected UR propagation not observed desc=%0d cpl=%0d",
        env.sb.expected_desc_errors_seen,env.sb.completion_errors_seen))
    else
      `uvm_info("CPLERR","Unsupported Request completion propagated as DMA error 0xA",UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
