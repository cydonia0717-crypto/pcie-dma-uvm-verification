class dma_desc_monitor extends uvm_component;
  `uvm_component_utils(dma_desc_monitor)
  virtual dma_desc_if vif;
  uvm_analysis_port #(dma_desc_obs) ap;
  function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual dma_desc_if)::get(this,"","vif",vif)) `uvm_fatal("DESC","no vif")
  endfunction
  task run_phase(uvm_phase phase); dma_desc_obs o;
    forever begin @(vif.mon_cb); if(vif.mon_cb.rst) continue;
      if(vif.mon_cb.rd_valid&&vif.mon_cb.rd_ready) begin o=new("rd"); o.dir=DMA_H2C; o.pcie_addr=vif.mon_cb.rd_pcie_addr; o.ram_addr=vif.mon_cb.rd_ram_addr; o.len=vif.mon_cb.rd_len; o.tag=vif.mon_cb.rd_tag; ap.write(o); end
      if(vif.mon_cb.wr_valid&&vif.mon_cb.wr_ready) begin o=new("wr"); o.dir=DMA_C2H; o.pcie_addr=vif.mon_cb.wr_pcie_addr; o.ram_addr=vif.mon_cb.wr_ram_addr; o.len=vif.mon_cb.wr_len; o.tag=vif.mon_cb.wr_tag; ap.write(o); end
      if(vif.mon_cb.rd_status_valid) begin o=new("rds"); o.dir=DMA_H2C; o.is_status=1; o.tag=vif.mon_cb.rd_status_tag; o.error=vif.mon_cb.rd_status_error; ap.write(o); end
      if(vif.mon_cb.wr_status_valid) begin o=new("wrs"); o.dir=DMA_C2H; o.is_status=1; o.tag=vif.mon_cb.wr_status_tag; o.error=vif.mon_cb.wr_status_error; ap.write(o); end
    end
  endtask
endclass
