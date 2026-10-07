class dma_max_len_test extends dma_base_test;
  `uvm_component_utils(dma_max_len_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction

  task run_phase(uvm_phase phase);
    dma_max_len_seq seq;
    phase.raise_objection(this);
    cfg_vif.max_read_request_size=3'd2; // 512 B
    cfg_vif.max_payload_size=3'd1;      // 256 B

    seq=dma_max_len_seq::type_id::create("seq");
    seq.start(env.desc.sqr);
    repeat(120000) @(posedge cfg_vif.clk);

    if(env.sb.checks!=2)
      `uvm_error("MAXLEN",$sformatf("expected 2 completed max-length descriptors, got %0d",env.sb.checks))
    if(env.sb.max_memrd_tlp_bytes!=512)
      `uvm_error("MAXLEN",$sformatf("MRRS segmentation max=%0d, expected 512",env.sb.max_memrd_tlp_bytes))
    if(env.sb.max_memwr_tlp_bytes!=256)
      `uvm_error("MAXLEN",$sformatf("MPS segmentation max=%0d, expected 256",env.sb.max_memwr_tlp_bytes))
    else
      `uvm_info("MAXLEN","65535-byte H2C and C2H descriptors completed cleanly",UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass
