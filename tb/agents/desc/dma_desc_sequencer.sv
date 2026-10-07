class dma_desc_sequencer extends uvm_sequencer #(dma_desc_item);
  `uvm_component_utils(dma_desc_sequencer)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
endclass
