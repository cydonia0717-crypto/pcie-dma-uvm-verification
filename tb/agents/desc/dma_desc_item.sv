typedef enum bit {DMA_H2C=1'b0, DMA_C2H=1'b1} dma_dir_e;

class dma_desc_item extends uvm_sequence_item;
  rand dma_dir_e dir;
  rand longint unsigned pcie_addr;
  rand int unsigned ram_addr;
  rand int unsigned len;
  rand bit [7:0] tag;

  constraint c_len { len inside {[1:16'hffff]}; }

  `uvm_object_utils_begin(dma_desc_item)
    `uvm_field_enum(dma_dir_e,dir,UVM_DEFAULT)
    `uvm_field_int(pcie_addr,UVM_HEX)
    `uvm_field_int(ram_addr,UVM_HEX)
    `uvm_field_int(len,UVM_DEC)
    `uvm_field_int(tag,UVM_HEX)
  `uvm_object_utils_end
  function new(string name="dma_desc_item"); super.new(name); endfunction
endclass

class dma_desc_obs extends uvm_sequence_item;
  dma_dir_e dir;
  bit is_status;
  longint unsigned pcie_addr;
  int unsigned ram_addr;
  int unsigned len;
  bit [7:0] tag;
  bit [3:0] error;
  `uvm_object_utils(dma_desc_obs)
  function new(string name="dma_desc_obs"); super.new(name); endfunction
endclass
