class dma_desc_agent extends uvm_agent;
  `uvm_component_utils(dma_desc_agent)
  dma_desc_sequencer sqr; dma_desc_driver drv; dma_desc_monitor mon;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    sqr=dma_desc_sequencer::type_id::create("sqr",this); drv=dma_desc_driver::type_id::create("drv",this); mon=dma_desc_monitor::type_id::create("mon",this);
  endfunction
  function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(sqr.seq_item_export); endfunction
endclass
