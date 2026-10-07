class pcie_host_agent extends uvm_agent;
  `uvm_component_utils(pcie_host_agent)
  pcie_host_responder rsp;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase); rsp=pcie_host_responder::type_id::create("rsp",this); endfunction
endclass
