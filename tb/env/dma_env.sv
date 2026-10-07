class dma_env extends uvm_env;
  `uvm_component_utils(dma_env)
  dma_ref_mem mem; dma_desc_agent desc; pcie_host_agent host; dma_ram_agent ram; dma_scoreboard sb; dma_coverage cov;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    mem=dma_ref_mem::type_id::create("mem");
    uvm_config_db#(dma_ref_mem)::set(this,"*","mem",mem);
    desc=dma_desc_agent::type_id::create("desc",this); host=pcie_host_agent::type_id::create("host",this); ram=dma_ram_agent::type_id::create("ram",this); sb=dma_scoreboard::type_id::create("sb",this); cov=dma_coverage::type_id::create("cov",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    desc.mon.ap.connect(sb.desc_imp); desc.mon.ap.connect(cov.desc_imp); host.rsp.ap.connect(sb.tlp_imp); host.rsp.ap.connect(cov.tlp_imp); ram.model.ap.connect(cov.ram_imp); ram.model.ap.connect(sb.ram_imp);
  endfunction
endclass
