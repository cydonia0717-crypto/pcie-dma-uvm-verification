class dma_base_test extends uvm_test;
  `uvm_component_utils(dma_base_test)
  dma_env env; virtual dma_cfg_if cfg_vif;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase); env=dma_env::type_id::create("env",this); if(!uvm_config_db#(virtual dma_cfg_if)::get(this,"","cfg_vif",cfg_vif)) `uvm_fatal("TEST","no cfg"); uvm_config_db#(virtual dma_cfg_if)::set(this,"env.sb","cfg_vif",cfg_vif); endfunction
  task wait_done(int cycles=20000); repeat(cycles) @(posedge cfg_vif.clk); endtask
endclass
