class dma_ram_agent extends uvm_agent;
  `uvm_component_utils(dma_ram_agent)
  dma_ram_model model;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase); model=dma_ram_model::type_id::create("model",this); endfunction
endclass
