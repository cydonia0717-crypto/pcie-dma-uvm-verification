class dma_desc_driver extends uvm_driver #(dma_desc_item);
  `uvm_component_utils(dma_desc_driver)
  virtual dma_desc_if vif;
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual dma_desc_if)::get(this,"","vif",vif)) `uvm_fatal("DESC","no vif")
  endfunction
  task run_phase(uvm_phase phase);
    dma_desc_item tr;
    vif.drv_cb.rd_valid<=0; vif.drv_cb.wr_valid<=0;
    forever begin
      seq_item_port.get_next_item(tr);
      while(vif.drv_cb.rst) @(vif.drv_cb);
      if(tr.dir==DMA_H2C) begin
        vif.drv_cb.rd_pcie_addr<=tr.pcie_addr; vif.drv_cb.rd_ram_sel<='0;
        vif.drv_cb.rd_ram_addr<=tr.ram_addr; vif.drv_cb.rd_len<=tr.len; vif.drv_cb.rd_tag<=tr.tag;
        vif.drv_cb.rd_valid<=1; do @(vif.drv_cb); while(!vif.drv_cb.rd_ready); vif.drv_cb.rd_valid<=0;
      end else begin
        vif.drv_cb.wr_pcie_addr<=tr.pcie_addr; vif.drv_cb.wr_ram_sel<='0;
        vif.drv_cb.wr_ram_addr<=tr.ram_addr; vif.drv_cb.wr_len<=tr.len; vif.drv_cb.wr_tag<=tr.tag;
        vif.drv_cb.wr_valid<=1; do @(vif.drv_cb); while(!vif.drv_cb.wr_ready); vif.drv_cb.wr_valid<=0;
      end
      seq_item_port.item_done();
    end
  endtask
endclass
